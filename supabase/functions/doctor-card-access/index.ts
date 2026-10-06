// دخول بطاقة الطبيب: كلمة المرور تُتحقق هنا، والعميل لا يرى البصمة ولا أسرار الإدارة.
//
// مطلوب قبل العمل:
//   1) تنفيذ supabase/doctor_card_access_schema.sql
//   2) supabase functions deploy doctor-card-access
//   3) supabase secrets set DOCTOR_CARD_TOKEN_SECRET=<قيمة عشوائية طويلة>
// SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY و SUPABASE_ANON_KEY تُحقن على الاستضافة.
// CLINIC_ADMIN_EMAIL اختياري إن تغيّر بريد الإدارة عن is_clinic_admin().

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  type AttemptKind,
  type AttemptState,
  type CardDeps,
  type EntityType,
  type OwnerAccess,
  clientIp,
  handleDoctorCardAccess,
  pharmacyBundlesPermissionDenied,
} from "./policy.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const defaultAdminEmail = "almusawyalmusawy90@gmail.com";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function adminEmail(): string {
  return Deno.env.get("CLINIC_ADMIN_EMAIL")?.trim() || defaultAdminEmail;
}

async function sourceHash(secret: string, ip: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${secret}|${ip}`),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function restFailure(res: Response): Promise<string> {
  const status = res.status;
  try {
    const body = await res.json();
    const code = typeof body?.code === "string" ? body.code : "";
    const message = typeof body?.message === "string" ? body.message.slice(0, 180) : "";
    return `${status} ${code} ${message}`.trim();
  } catch {
    return String(status);
  }
}

function restHeaders(serviceKey: string, extra?: HeadersInit): Headers {
  return new Headers({
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    ...extra,
  });
}

function buildDeps(): CardDeps | null {
  const url = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const tokenSecret = Deno.env.get("DOCTOR_CARD_TOKEN_SECRET") ?? "";
  if (!url || !serviceKey || !tokenSecret) return null;

  async function rest(path: string, init: RequestInit): Promise<Response> {
    return fetch(`${url}${path}`, init);
  }

  return {
    now: () => Date.now(),
    tokenSecret,
    loadAccess: async (type, id) => {
      const res = await rest(
        `/rest/v1/entity_owner_access?entity_type=eq.${type}&entity_id=eq.${encodeURIComponent(id)}&select=owner_editing_enabled,password_hash,session_version,permissions,activation_code_hash,activation_expires_at`,
        { headers: restHeaders(serviceKey) },
      );
      if (!res.ok) return null;
      const rows = await res.json();
      const row = rows?.[0];
      if (!row) return null;
      const permissions = Array.isArray(row.permissions)
        ? row.permissions.filter((item: unknown) => typeof item === "string")
        : [];
      return {
        enabled: row.owner_editing_enabled === true,
        passwordHash: typeof row.password_hash === "string" ? row.password_hash : null,
        sessionVersion: Number(row.session_version ?? 1) || 1,
        permissions,
        activationCodeHash: typeof row.activation_code_hash === "string"
          ? row.activation_code_hash
          : null,
        activationExpiresAt: row.activation_expires_at
          ? Date.parse(row.activation_expires_at)
          : null,
      } satisfies OwnerAccess;
    },
    saveAccess: async (type, id, access) => {
      const res = await rest("/rest/v1/entity_owner_access", {
        method: "POST",
        headers: restHeaders(serviceKey, {
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates",
        }),
        body: JSON.stringify({
          entity_type: type,
          entity_id: id,
          owner_editing_enabled: access.enabled,
          password_hash: access.passwordHash,
          session_version: access.sessionVersion,
          permissions: access.permissions,
          activation_code_hash: access.activationCodeHash,
          activation_expires_at: access.activationExpiresAt
            ? new Date(access.activationExpiresAt).toISOString()
            : null,
          updated_at: new Date().toISOString(),
        }),
      });
      if (!res.ok) {
        const failure = await restFailure(res);
        throw new Error(`access write failed ${failure}`);
      }
    },
    consumeActivation: async (type, id, codeHash, passwordHash, sessionVersion) => {
      const res = await rest(
        `/rest/v1/entity_owner_access?entity_type=eq.${type}&entity_id=eq.${encodeURIComponent(id)}&activation_code_hash=eq.${encodeURIComponent(codeHash)}&password_hash=is.null&owner_editing_enabled=eq.true&session_version=eq.${sessionVersion}`,
        {
          method: "PATCH",
          headers: restHeaders(serviceKey, {
            "Content-Type": "application/json",
            Prefer: "return=representation",
          }),
          body: JSON.stringify({
            password_hash: passwordHash,
            activation_code_hash: null,
            activation_expires_at: null,
            session_version: sessionVersion + 1,
            updated_at: new Date().toISOString(),
          }),
        },
      );
      if (!res.ok) return null;
      const rows = await res.json();
      return Array.isArray(rows) && rows.length === 1 ? sessionVersion + 1 : null;
    },
    loadDoctorMeta: async (doctorId) => {
      const res = await rest(
        `/rest/v1/doctors?id=eq.${doctorId}&select=is_active,display_order`,
        { headers: restHeaders(serviceKey) },
      );
      if (!res.ok) return null;
      const rows = await res.json();
      const row = rows?.[0];
      if (!row) return null;
      return {
        is_active: row.is_active !== false,
        display_order: Number(row.display_order ?? 0) || 0,
      };
    },
    loadAttempt: async (source, type: EntityType, id, kind: AttemptKind) => {
      const res = await rest(
        `/rest/v1/entity_owner_attempts?source_hash=eq.${source}&entity_type=eq.${type}&entity_id=eq.${encodeURIComponent(id)}&kind=eq.${kind}&select=failures,window_started,locked_until`,
        { headers: restHeaders(serviceKey) },
      );
      if (!res.ok) return null;
      const rows = await res.json();
      const row = rows?.[0];
      if (!row) return null;
      const state: AttemptState = {
        failures: Number(row.failures ?? 0),
        windowStarted: Date.parse(row.window_started),
        lockedUntil: row.locked_until ? Date.parse(row.locked_until) : null,
      };
      return state;
    },
    saveAttempt: async (source, type, id, kind, state) => {
      const res = await rest("/rest/v1/entity_owner_attempts", {
        method: "POST",
        headers: restHeaders(serviceKey, {
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates",
        }),
        body: JSON.stringify({
          source_hash: source,
          entity_type: type,
          entity_id: id,
          kind,
          failures: state.failures,
          window_started: new Date(state.windowStarted).toISOString(),
          locked_until: state.lockedUntil
            ? new Date(state.lockedUntil).toISOString()
            : null,
        }),
      });
      if (!res.ok) throw new Error("attempt write failed");
    },
    clearAttempt: async (source, type, id, kind) => {
      await rest(
        `/rest/v1/entity_owner_attempts?source_hash=eq.${source}&entity_type=eq.${type}&entity_id=eq.${encodeURIComponent(id)}&kind=eq.${kind}`,
        { method: "DELETE", headers: restHeaders(serviceKey) },
      );
    },
    updateDoctor: async (doctorId, patch, expectedRevision) => {
      const res = await rest(
        `/rest/v1/doctors?id=eq.${doctorId}&content_revision=eq.${expectedRevision}`,
        {
          method: "PATCH",
          headers: restHeaders(serviceKey, {
            "Content-Type": "application/json",
            Prefer: "return=representation",
          }),
          body: JSON.stringify({
            ...patch,
            content_revision: expectedRevision + 1,
          }),
        },
      );
      if (!res.ok) throw new Error("doctor update failed");
      const rows = await res.json();
      return Array.isArray(rows) && rows.length === 1 ? expectedRevision + 1 : null;
    },
    deleteDoctor: async (doctorId) => {
      const res = await rest(`/rest/v1/doctors?id=eq.${doctorId}`, {
        method: "DELETE",
        headers: restHeaders(serviceKey),
      });
      if (!res.ok) throw new Error("doctor delete failed");
    },
    updateLab: async (labId, patch, expectedRevision) => {
      const res = await rest(
        `/rest/v1/labs?id=eq.${labId}&content_revision=eq.${expectedRevision}`,
        {
          method: "PATCH",
          headers: restHeaders(serviceKey, {
            "Content-Type": "application/json",
            Prefer: "return=representation",
          }),
          body: JSON.stringify({
            ...patch,
            content_revision: expectedRevision + 1,
          }),
        },
      );
      if (!res.ok) throw new Error("lab update failed");
      const rows = await res.json();
      return Array.isArray(rows) && rows.length === 1 ? expectedRevision + 1 : null;
    },
    upsertLabPackage: async (labId, packageId, patch, expectedRevision) => {
      const nextRevision = expectedRevision == null ? 1 : expectedRevision + 1;
      const payload = {
        ...patch,
        lab_id: labId,
        content_revision: nextRevision,
      };
      const path = packageId
        ? `/rest/v1/lab_packages?id=eq.${packageId}&lab_id=eq.${labId}&content_revision=eq.${expectedRevision}`
        : "/rest/v1/lab_packages";
      const res = await rest(path, {
        method: packageId ? "PATCH" : "POST",
        headers: restHeaders(serviceKey, {
          "Content-Type": "application/json",
          Prefer: "return=representation",
        }),
        body: JSON.stringify(payload),
      });
      if (!res.ok) throw new Error("package write failed");
      const rows = await res.json();
      return Array.isArray(rows) && rows.length === 1 ? nextRevision : null;
    },
    deleteLabPackage: async (labId, packageId) => {
      const res = await rest(
        `/rest/v1/lab_packages?id=eq.${packageId}&lab_id=eq.${labId}`,
        { method: "DELETE", headers: restHeaders(serviceKey, { Prefer: "return=representation" }) },
      );
      if (!res.ok) throw new Error("package delete failed");
    },
    savePharmacySnapshot: async (pharmacyId, patch, expectedRevision, permissions) => {
      const current = await rest(
        `/rest/v1/pharmacies?id=eq.${encodeURIComponent(pharmacyId)}&select=profile,content_revision`,
        { headers: restHeaders(serviceKey) },
      );
      if (!current.ok) throw new Error("pharmacy read failed");
      const rows = await current.json();
      if (!Array.isArray(rows) || rows.length !== 1) return "missing";
      const currentRevision = Number(rows[0]?.content_revision ?? 1) || 1;
      if (currentRevision !== expectedRevision) return "conflict";
      const prev = rows[0]?.profile && typeof rows[0].profile === "object"
        ? rows[0].profile
        : {};
      if (
        permissions &&
        Object.prototype.hasOwnProperty.call(patch, "bundles") &&
        pharmacyBundlesPermissionDenied(
          permissions,
          (prev as Record<string, unknown>).bundles,
          patch.bundles,
        )
      ) {
        return "forbidden";
      }
      const profile = { ...prev, ...patch, id: pharmacyId };
      const res = await rest(
        `/rest/v1/pharmacies?id=eq.${encodeURIComponent(pharmacyId)}&content_revision=eq.${expectedRevision}`,
        {
          method: "PATCH",
          headers: restHeaders(serviceKey, {
            "Content-Type": "application/json",
            Prefer: "return=representation",
          }),
          body: JSON.stringify({
            profile,
            content_revision: expectedRevision + 1,
            updated_at: new Date().toISOString(),
          }),
        },
      );
      if (!res.ok) throw new Error("pharmacy publish failed");
      const updated = await res.json();
      return Array.isArray(updated) && updated.length === 1 ? "ok" : "conflict";
    },
    uploadImage: async (path, bytes, contentType) => {
      const payload = new Uint8Array(bytes.byteLength);
      payload.set(bytes);
      const res = await rest(
        `/storage/v1/object/clinic-media/${path}`,
        {
          method: "POST",
          headers: restHeaders(serviceKey, {
            "Content-Type": contentType,
            "x-upsert": "false",
          }),
          body: payload,
        },
      );
      if (!res.ok) throw new Error("image upload failed");
      return `${url}/storage/v1/object/public/clinic-media/${path}`;
    },
    verifyAdminPassword: async (password) => {
      if (!anonKey || !password) return false;
      const res = await fetch(`${url}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
          apikey: anonKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email: adminEmail(), password }),
      });
      if (!res.ok) return false;
      const data = await res.json();
      const access = data?.access_token;
      if (typeof access === "string" && access) {
        await fetch(`${url}/auth/v1/logout`, {
          method: "POST",
          headers: {
            apikey: anonKey,
            Authorization: `Bearer ${access}`,
          },
        }).catch(() => undefined);
      }
      return true;
    },
    verifyAdminJwt: async (authorization) => {
      const token = authorization?.replace(/^Bearer\s+/i, "").trim();
      if (!token || !anonKey) return false;
      const res = await fetch(`${url}/auth/v1/user`, {
        headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return false;
      const user = await res.json();
      const email = String(user?.email ?? "").toLowerCase();
      return email.length > 0 && email === adminEmail().toLowerCase();
    },
    sourceHash: (ip) => sourceHash(tokenSecret, ip),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, code: "bad_request", error: "طلب غير معروف." });
  }
  const deps = buildDeps();
  if (!deps) {
    return json(503, {
      ok: false,
      code: "unconfigured",
      error: "خدمة التحقق غير جاهزة. راجع إعداد المشروع.",
    });
  }
  let body: Record<string, unknown> = {};
  try {
    const raw = await req.text();
    if (raw.length > 2_200_000) {
      return json(413, {
        ok: false,
        code: "bad_image",
        error: "الصورة غير مقبولة. استخدم JPG أو PNG أو WEBP وبحجم أصغر.",
      });
    }
    body = raw ? JSON.parse(raw) : {};
  } catch {
    return json(400, { ok: false, code: "bad_request", error: "طلب غير معروف." });
  }
  try {
    const result = await handleDoctorCardAccess(
      body,
      deps,
      clientIp(req.headers),
      req.headers.get("Authorization"),
    );
    return json(result.status, result.body);
  } catch (error) {
    const detail = error instanceof Error ? error.message : "unknown";
    console.error("doctor-card-access failed", detail);
    return json(500, {
      ok: false,
      code: "bad_request",
      error: "تعذر إكمال الطلب. حاول لاحقًا.",
    });
  }
});
