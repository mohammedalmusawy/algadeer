// ربط patient-account بـ Storage REST وAuth Admin. بدون أسرار في الملف.
import {
  defaultAdminEmail,
  storageDeleteBody,
  type PatientAccountDeps,
} from "./policy.ts";

function adminEmail(): string {
  return Deno.env.get("CLINIC_ADMIN_EMAIL")?.trim() || defaultAdminEmail;
}

function restHeaders(serviceKey: string, extra?: HeadersInit): Headers {
  return new Headers({
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    ...extra,
  });
}

export function buildDeps(): PatientAccountDeps | null {
  const url = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !serviceKey || !anonKey) return null;

  return {
    now: () => Date.now(),
    adminEmail: adminEmail(),
    readUser: async (authorization) => {
      const token = authorization?.replace(/^Bearer\s+/i, "").trim();
      if (!token) return null;
      const res = await fetch(`${url}/auth/v1/user`, {
        headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return null;
      const user = await res.json();
      const id = typeof user?.id === "string" ? user.id : "";
      const email = typeof user?.email === "string" ? user.email : "";
      if (!id) return null;
      return { id, email };
    },
    listStoragePaths: async (userId) => {
      const paths: string[] = [];
      const queue = [`${userId}/`];
      while (queue.length > 0) {
        const prefix = queue.shift() ?? "";
        let offset = 0;
        while (true) {
          const res = await fetch(
            `${url}/storage/v1/object/list/patient-health`,
            {
              method: "POST",
              headers: restHeaders(serviceKey, {
                "Content-Type": "application/json",
              }),
              body: JSON.stringify({
                prefix,
                limit: 1000,
                offset,
                sortBy: { column: "name", order: "asc" },
              }),
            },
          );
          if (!res.ok) throw new Error("storage list failed");
          const rows = await res.json();
          if (!Array.isArray(rows)) throw new Error("invalid storage response");
          for (const row of rows) {
            const name = typeof row?.name === "string" ? row.name : "";
            if (!name) continue;
            const path = `${prefix}${name}`;
            if (row?.id == null) {
              queue.push(`${path}/`);
            } else {
              paths.push(path);
            }
          }
          if (rows.length < 1000) break;
          offset += rows.length;
        }
      }
      return paths;
    },
    deleteStorage: async (userId, paths) => {
      const body = storageDeleteBody(userId, paths);
      for (let start = 0; start < body.names.length; start += 1000) {
        const res = await fetch(`${url}/storage/v1/object/patient-health`, {
          method: "DELETE",
          headers: restHeaders(serviceKey, {
            "Content-Type": "application/json",
          }),
          body: JSON.stringify({
            prefixes: body.names.slice(start, start + 1000),
          }),
        });
        if (!res.ok) throw new Error("storage delete failed");
      }
    },
    deleteRows: async (userId) => {
      const tables = [
        "patient_conditions",
        "patient_health_profiles",
      ];
      for (const table of tables) {
        const res = await fetch(
          `${url}/rest/v1/${table}?user_id=eq.${encodeURIComponent(userId)}`,
          {
            method: "DELETE",
            headers: restHeaders(serviceKey, { Prefer: "return=minimal" }),
          },
        );
        if (!res.ok) throw new Error("row delete failed");
      }
    },
    deleteAuthUser: async (userId) => {
      const res = await fetch(`${url}/auth/v1/admin/users/${userId}`, {
        method: "DELETE",
        headers: restHeaders(serviceKey),
      });
      if (!res.ok) throw new Error("auth delete failed");
    },
  };
}
