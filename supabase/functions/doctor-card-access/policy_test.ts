import {
  CONTENT_CONFLICT_MESSAGE,
  pharmacyBundlesPermissionDenied,
  type AttemptKind,
  type AttemptState,
  type CardDeps,
  type DoctorMeta,
  type EntityType,
  type OwnerAccess,
  handleDoctorCardAccess,
  hashPassword,
  inspectImage,
  MAX_IMAGE_BYTES,
  PBKDF2_ITERATIONS,
  verifyPassword,
} from "./policy.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(
      `expected ${JSON.stringify(expected)} but got ${JSON.stringify(actual)}`,
    );
  }
}

const doctorA = "11111111-1111-4111-8111-111111111111";
const doctorB = "22222222-2222-4222-8222-222222222222";

function jpeg(size = 40): Uint8Array {
  const bytes = new Uint8Array(size);
  bytes[0] = 0xff;
  bytes[1] = 0xd8;
  bytes[2] = 0xff;
  return bytes;
}

function memoryDeps(options?: {
  hashes?: Record<string, string>;
  adminPassword?: string;
  adminJwt?: boolean;
  now?: number;
  missingPharmacy?: boolean;
}) {
  const hashes = new Map<string, string>();
  const access = new Map<string, OwnerAccess>();
  const doctorPerms = ["image", "bio", "services", "schedule", "contacts", "booking_status"];
  for (const [id, hash] of Object.entries(options?.hashes ?? {})) {
    hashes.set(id, hash);
    access.set(`doctor:${id}`, {
      enabled: true,
      passwordHash: hash,
      sessionVersion: 1,
      permissions: doctorPerms,
      activationCodeHash: null,
      activationExpiresAt: null,
    });
  }
  const attempts = new Map<string, AttemptState>();
  const doctors = new Map<string, Record<string, unknown>>();
  const revisions = new Map<string, number>();
  const bump = (key: string, expected: number | null): number | null => {
    const current = revisions.get(key) ?? 1;
    if (expected != null && current !== expected) return null;
    const next = expected == null ? 1 : current + 1;
    revisions.set(key, next);
    return next;
  };
  const labs = new Map<string, Record<string, unknown>>();
  const packages = new Map<string, Record<string, unknown>>();
  const pharmacies = new Map<string, Record<string, unknown>>();
  const centers = new Map<string, Record<string, unknown>>();
  const directory = new Map<string, Record<string, unknown>>();
  const uploads: string[] = [];
  let adminChecks = 0;
  const now = options?.now ?? 1_700_000_000_000;
  const attemptKey = (source: string, type: EntityType, id: string, kind: AttemptKind) =>
    `${source}|${type}|${id}|${kind}`;
  const deps: CardDeps = {
    now: () => now,
    tokenSecret: "test-secret-not-a-password",
    hashIterations: 2,
    loadAccess: (type, id) => Promise.resolve(access.get(`${type}:${id}`) ?? null),
    saveAccess: (type, id, row) => {
      access.set(`${type}:${id}`, row);
      if (type === "doctor") {
        if (row.passwordHash) hashes.set(id, row.passwordHash);
        else hashes.delete(id);
      }
      return Promise.resolve();
    },
    consumeActivation: (type, id, codeHash, passwordHash, sessionVersion) => {
      const row = access.get(`${type}:${id}`);
      if (!row?.enabled || row.passwordHash || row.activationCodeHash !== codeHash) {
        return Promise.resolve(null);
      }
      if (row.sessionVersion !== sessionVersion) return Promise.resolve(null);
      if (!row.activationExpiresAt || row.activationExpiresAt <= now) {
        return Promise.resolve(null);
      }
      const version = row.sessionVersion + 1;
      const next = {
        ...row,
        passwordHash,
        sessionVersion: version,
        activationCodeHash: null,
        activationExpiresAt: null,
      };
      access.set(`${type}:${id}`, next);
      if (type === "doctor") hashes.set(id, passwordHash);
      return Promise.resolve(version);
    },
    loadDoctorMeta: (id): Promise<DoctorMeta | null> =>
      Promise.resolve(
        id === doctorA ? { is_active: true, display_order: 4 } : null,
      ),
    loadAttempt: (source, type, id, kind) =>
      Promise.resolve(attempts.get(attemptKey(source, type, id, kind)) ?? null),
    saveAttempt: (source, type, id, kind, state) => {
      attempts.set(attemptKey(source, type, id, kind), state);
      return Promise.resolve();
    },
    clearAttempt: (source, type, id, kind) => {
      attempts.delete(attemptKey(source, type, id, kind));
      return Promise.resolve();
    },
    updateDoctor: (id, patch, expected) => {
      const next = bump(`doctor:${id}`, expected);
      if (next == null) return Promise.resolve(null);
      doctors.set(id, { ...(doctors.get(id) ?? {}), ...patch, content_revision: next });
      return Promise.resolve(next);
    },
    deleteDoctor: (id) => {
      doctors.set(id, { deleted: true });
      return Promise.resolve();
    },
    updateLab: (id, patch, expected) => {
      const next = bump(`lab:${id}`, expected);
      if (next == null) return Promise.resolve(null);
      labs.set(id, { ...(labs.get(id) ?? {}), ...patch, content_revision: next });
      return Promise.resolve(next);
    },
    upsertLabPackage: (labId, packageId, patch, expected) => {
      const key = `package:${packageId ?? "new"}`;
      const next = bump(key, expected);
      if (next == null) return Promise.resolve(null);
      packages.set(packageId ?? "new", { labId, ...patch, content_revision: next });
      return Promise.resolve(next);
    },
    deleteLabPackage: (labId, packageId) => {
      packages.set(packageId, { labId, deleted: true });
      return Promise.resolve();
    },
    savePharmacySnapshot: (id, patch, expected, permissions) => {
      if (options?.missingPharmacy === true) return Promise.resolve("missing");
      const prev = pharmacies.get(id) ?? {};
      if (
        permissions &&
        Object.prototype.hasOwnProperty.call(patch, "bundles") &&
        pharmacyBundlesPermissionDenied(
          permissions,
          (prev as Record<string, unknown>).bundles,
          patch.bundles,
        )
      ) {
        return Promise.resolve("forbidden");
      }
      const next = bump(`pharmacy:${id}`, expected);
      if (next == null) return Promise.resolve("conflict");
      pharmacies.set(id, { ...prev, ...patch, content_revision: next });
      return Promise.resolve("ok");
    },
    saveServiceCenter: (id, patch, expected) => {
      const prev = centers.get(id);
      if (!prev) return Promise.resolve("missing");
      const next = bump(`center:${id}`, expected);
      if (next == null) return Promise.resolve("conflict");
      centers.set(id, { ...prev, ...patch, content_revision: next });
      return Promise.resolve("ok");
    },
    saveDirectoryEntity: (type, id, patch, expected) => {
      const key = `${type}:${id}`;
      const prev = directory.get(key);
      if (!prev) return Promise.resolve("missing");
      const next = bump(`dir:${key}`, expected);
      if (next == null) return Promise.resolve("conflict");
      directory.set(key, { ...prev, ...patch, content_revision: next });
      return Promise.resolve("ok");
    },
    uploadImage: (path) => {
      uploads.push(path);
      return Promise.resolve(`https://cdn.example/clinic-media/${path}`);
    },
    verifyAdminPassword: (password) => {
      adminChecks += 1;
      return Promise.resolve(password === (options?.adminPassword ?? "admin-pass-99"));
    },
    verifyAdminJwt: () => Promise.resolve(options?.adminJwt === true),
    sourceHash: (ip) => Promise.resolve(`src:${ip}`),
  };
  return {
    deps,
    doctors,
    labs,
    packages,
    pharmacies,
    centers,
    directory,
    uploads,
    hashes,
    access,
    adminChecks: () => adminChecks,
  };
}

Deno.test("production password hashing is slow enough and not plaintext", async () => {
  assertEquals(PBKDF2_ITERATIONS >= 200_000, true);
  const stored = await hashPassword("doctor-secret-1", 2);
  assertEquals(stored.includes("doctor-secret-1"), false);
  assertEquals(await verifyPassword(stored, "doctor-secret-1"), true);
  assertEquals(await verifyPassword(stored, "other-secret"), false);
  assertEquals(await verifyPassword(null, "doctor-secret-1"), false);
});

Deno.test("doctor password opens only that card", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const hashB = await hashPassword("secret-b-222", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA, [doctorB]: hashB } });
  const ok = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.0.0.1",
    null,
  );
  assertEquals(ok.status, 200);
  assertEquals(ok.body.role, "owner");
  assertEquals(box.adminChecks(), 0);

  const other = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorB, password: "secret-a-111" },
    box.deps,
    "10.0.0.2",
    null,
  );
  assertEquals(other.status, 401);
  assertEquals(other.body.token, undefined);
});

Deno.test("admin password opens a card and can reset without revealing secrets", async () => {
  const box = memoryDeps({ adminPassword: "admin-pass-99" });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "admin-pass-99" },
    box.deps,
    "10.1.0.1",
    null,
  );
  assertEquals(login.status, 200);
  assertEquals(login.body.role, "admin");
  const token = String(login.body.token);
  assertEquals(token.includes("admin-pass-99"), false);

  const set = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      doctor_id: doctorA,
      token,
      enabled: true,
      reset: true,
      permissions: ["bio"],
    },
    box.deps,
    "10.1.0.1",
    null,
  );
  assertEquals(set.status, 200);
  assertEquals(set.body.mode, "activate");
  const code = String(set.body.activation_code);
  assertEquals(code.length >= 8, true);
  assertEquals(JSON.stringify(set.body).includes("admin-pass-99"), false);
  assertEquals(box.hashes.has(doctorA), false);

  const verify = await handleDoctorCardAccess(
    { action: "verify_code", doctor_id: doctorA, code },
    box.deps,
    "10.1.0.8",
    null,
  );
  assertEquals(verify.status, 200);
  const done = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      doctor_id: doctorA,
      token: String(verify.body.activation_token),
      new_password: "new-doctor-pass",
    },
    box.deps,
    "10.1.0.8",
    null,
  );
  assertEquals(done.status, 200);
  assertEquals(JSON.stringify(done.body).includes("new-doctor-pass"), false);
  assertEquals((box.hashes.get(doctorA) ?? "").includes("new-doctor-pass"), false);

  const doctorLogin = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "new-doctor-pass" },
    box.deps,
    "10.1.0.9",
    null,
  );
  assertEquals(doctorLogin.body.role, "owner");
});

Deno.test("doctor token cannot edit forbidden fields or another card", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.2.0.1",
    null,
  );
  const token = String(login.body.token);

  const blocked = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: { bio: "نبذة جديدة", doctor_name: "اسم مخترق" },
    },
    box.deps,
    "10.2.0.1",
    null,
  );
  assertEquals(blocked.status, 403);
  assertEquals(box.doctors.has(doctorA), false);

  const statusBlocked = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: { booking_status: "unavailable" },
    },
    box.deps,
    "10.2.0.1",
    null,
  );
  assertEquals(statusBlocked.status, 403);

  const cross = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorB,
      token,
      fields: { bio: "تعديل بطاقة أخرى" },
    },
    box.deps,
    "10.2.0.1",
    null,
  );
  assertEquals(cross.status, 403);
  assertEquals(box.doctors.has(doctorB), false);

  const allowed = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: {
        bio: "نبذة",
        services: "تخطيط قلب",
        short_description: "نبذة",
        working_days: "السبت",
        working_hours: "السبت مساءً",
        phone: "07800000000",
        whatsapp: "07800000000",
        booking_status: "walk_in_only",
      },
    },
    box.deps,
    "10.2.0.1",
    null,
  );
  assertEquals(allowed.status, 200);
  assertEquals(box.doctors.get(doctorA)?.booking_status, "walk_in_only");
  assertEquals(box.doctors.get(doctorA)?.doctor_name, undefined);
});

Deno.test("admin token can edit identity fields and a doctor cannot reset passwords", async () => {
  const box = memoryDeps();
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "admin-pass-99" },
    box.deps,
    "10.3.0.1",
    null,
  );
  const token = String(login.body.token);
  const update = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: {
        doctor_name: "د. مثال",
        specialty: "باطنية",
        clinic_location: "الشطرة",
        is_active: false,
        display_order: 3,
      },
    },
    box.deps,
    "10.3.0.1",
    null,
  );
  assertEquals(update.status, 200);
  assertEquals(box.doctors.get(doctorA)?.is_active, false);

  const doctorHash = await hashPassword("secret-a-111", 2);
  box.access.set(`doctor:${doctorA}`, {
    enabled: true,
    passwordHash: doctorHash,
    sessionVersion: 1,
    permissions: ["bio"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });
  const doctorLogin = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.3.0.2",
    null,
  );
  const denied = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      doctor_id: doctorA,
      token: String(doctorLogin.body.token),
      enabled: true,
      reset: true,
    },
    box.deps,
    "10.3.0.2",
    null,
  );
  assertEquals(denied.status, 403);
});

Deno.test("doctor changes password only after the old one matches", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.4.0.1",
    null,
  );
  const token = String(login.body.token);
  const wrong = await handleDoctorCardAccess(
    {
      action: "change_password",
      doctor_id: doctorA,
      token,
      old_password: "not-the-old",
      new_password: "replacement-22",
    },
    box.deps,
    "10.4.0.1",
    null,
  );
  assertEquals(wrong.status, 401);
  assertEquals(await verifyPassword(box.hashes.get(doctorA) ?? null, "secret-a-111"), true);

  const ok = await handleDoctorCardAccess(
    {
      action: "change_password",
      doctor_id: doctorA,
      token,
      old_password: "secret-a-111",
      new_password: "replacement-22",
    },
    box.deps,
    "10.4.0.1",
    null,
  );
  assertEquals(ok.status, 200);
  assertEquals(JSON.stringify(ok.body).includes("replacement-22"), false);
  assertEquals(await verifyPassword(box.hashes.get(doctorA) ?? null, "replacement-22"), true);
});

Deno.test("five failures lock only that source and card", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  for (let i = 0; i < 5; i++) {
    const res = await handleDoctorCardAccess(
      { action: "login", doctor_id: doctorA, password: `bad-${i}` },
      box.deps,
      "10.5.0.1",
      null,
    );
    assertEquals(res.status === 401 || res.status === 429, true);
  }
  const checksAfterLock = box.adminChecks();
  const locked = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.5.0.1",
    null,
  );
  assertEquals(locked.status, 429);
  assertEquals(String(locked.body.error).includes("5 دقائق"), true);
  assertEquals(box.adminChecks(), checksAfterLock);

  const otherSource = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.5.0.9",
    null,
  );
  assertEquals(otherSource.status, 200);
  assertEquals(otherSource.body.role, "owner");

  const otherCard = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorB, password: "bad" },
    box.deps,
    "10.5.0.1",
    null,
  );
  assertEquals(otherCard.status, 401);
});

Deno.test("photo upload is limited to the signed card and real image bytes", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.6.0.1",
    null,
  );
  const token = String(login.body.token);
  const html = new Uint8Array(64);
  new TextEncoder().encode("<!DOCTYPE html><script>").forEach((b, i) => {
    html[i] = b;
  });
  const rejected = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      image_base64: btoa(String.fromCharCode(...html)),
    },
    box.deps,
    "10.6.0.1",
    null,
  );
  assertEquals(rejected.status, 400);
  assertEquals(box.uploads.length, 0);

  const tooBig = jpeg(MAX_IMAGE_BYTES + 1);
  assertEquals(inspectImage(tooBig).ok, false);

  const accepted = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.6.0.1",
    null,
  );
  assertEquals(accepted.status, 200);
  assertEquals(box.uploads[0].startsWith(`doctors/${doctorA}/`), true);
  assertEquals(String(box.doctors.get(doctorA)?.image_url).includes(doctorA), true);

  const foreign = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      doctor_id: doctorB,
      token,
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.6.0.1",
    null,
  );
  assertEquals(foreign.status, 403);
  assertEquals(box.uploads.length, 1);
});

Deno.test("صورة الطبيب تُقبل مع إذن image وتُرفض بعد سحبه", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  box.access.set(`doctor:${doctorA}`, {
    enabled: true,
    passwordHash: hashA,
    sessionVersion: 1,
    permissions: ["image"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.6.0.2",
    null,
  );
  const token = String(login.body.token);
  const allowed = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.6.0.2",
    null,
  );
  assertEquals(allowed.status, 200);
  assertEquals(box.uploads[0].startsWith(`doctors/${doctorA}/`), true);

  box.access.set(`doctor:${doctorA}`, {
    enabled: true,
    passwordHash: hashA,
    sessionVersion: 1,
    permissions: ["bio"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });
  const revoked = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 2,
      doctor_id: doctorA,
      token,
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.6.0.2",
    null,
  );
  assertEquals(revoked.status, 403);
  assertEquals(box.uploads.length, 1);
});

Deno.test("admin hub jwt can set a password and doctor status is hidden", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({
    hashes: { [doctorA]: hashA },
    adminJwt: true,
  });
  const doctorLogin = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.7.0.1",
    "Bearer doctor-session",
  );
  const hidden = await handleDoctorCardAccess(
    {
      action: "admin_status",
      doctor_id: doctorA,
      token: String(doctorLogin.body.token),
    },
    box.deps,
    "10.7.0.1",
    "Bearer admin-jwt",
  );
  assertEquals(hidden.status, 403);

  const set = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      doctor_id: doctorA,
      enabled: true,
      reset: true,
    },
    box.deps,
    "10.7.0.1",
    "Bearer admin-jwt",
  );
  assertEquals(set.status, 200);
  assertEquals(typeof set.body.activation_code, "string");
  assertEquals(JSON.stringify(set.body).includes("secret-a-111"), false);

  const noJwt = memoryDeps({ adminJwt: false });
  const denied = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      doctor_id: doctorA,
      enabled: true,
      reset: true,
    },
    noJwt.deps,
    "10.7.0.2",
    "Bearer anon",
  );
  assertEquals(denied.status, 403);
  assertEquals(noJwt.hashes.has(doctorA), false);
});

Deno.test("missing server secret fails closed", async () => {
  const box = memoryDeps();
  box.deps.tokenSecret = "";
  const res = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "admin-pass-99" },
    box.deps,
    "10.8.0.1",
    null,
  );
  assertEquals(res.status, 503);
  assertEquals(box.adminChecks(), 0);
});

const labA = "33333333-3333-4333-8333-333333333333";

Deno.test("activation code is single use, expiring, and replaced", async () => {
  const box = memoryDeps({ adminJwt: true });
  const first = await handleDoctorCardAccess(
    { action: "admin_configure", doctor_id: doctorA, enabled: true, permissions: ["bio"] },
    box.deps,
    "10.9.0.1",
    "Bearer admin",
  );
  const firstCode = String(first.body.activation_code);
  const second = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      doctor_id: doctorA,
      enabled: true,
      reissue: true,
      permissions: ["bio"],
    },
    box.deps,
    "10.9.0.1",
    "Bearer admin",
  );
  const secondCode = String(second.body.activation_code);
  const stale = await handleDoctorCardAccess(
    { action: "verify_code", doctor_id: doctorA, code: firstCode },
    box.deps,
    "10.9.0.2",
    null,
  );
  assertEquals(stale.status, 401);

  const current = box.access.get(`doctor:${doctorA}`)!;
  box.access.set(`doctor:${doctorA}`, {
    ...current,
    activationExpiresAt: box.deps.now() - 1,
  });
  const expired = await handleDoctorCardAccess(
    { action: "verify_code", doctor_id: doctorA, code: secondCode },
    box.deps,
    "10.9.0.3",
    null,
  );
  assertEquals(expired.body.code, "expired");
  box.access.set(`doctor:${doctorA}`, current);

  const verify = await handleDoctorCardAccess(
    { action: "verify_code", doctor_id: doctorA, code: secondCode },
    box.deps,
    "10.9.0.4",
    null,
  );
  const token = String(verify.body.activation_token);
  const done = await handleDoctorCardAccess(
    { action: "complete_activation", doctor_id: doctorA, token, new_password: "owner-pass-1" },
    box.deps,
    "10.9.0.4",
    null,
  );
  assertEquals(done.status, 200);
  const replay = await handleDoctorCardAccess(
    { action: "complete_activation", doctor_id: doctorA, token, new_password: "owner-pass-2" },
    box.deps,
    "10.9.0.5",
    null,
  );
  assertEquals(replay.status, 409);
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "owner-pass-1" },
    box.deps,
    "10.9.0.6",
    null,
  );
  assertEquals(login.status, 200);
});

Deno.test("permissions and a disabled session are enforced on save", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA }, adminJwt: true });
  box.access.set(`doctor:${doctorA}`, {
    ...box.access.get(`doctor:${doctorA}`)!,
    permissions: ["bio"],
  });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.9.1.1",
    null,
  );
  const token = String(login.body.token);
  const phone = await handleDoctorCardAccess(
    { action: "update", doctor_id: doctorA, token, fields: { phone: "07800000000" } },
    box.deps,
    "10.9.1.1",
    null,
  );
  assertEquals(phone.status, 403);
  const bio = await handleDoctorCardAccess(
    { action: "update", base_revision: 1, doctor_id: doctorA, token, fields: { bio: "نبذة" } },
    box.deps,
    "10.9.1.1",
    null,
  );
  assertEquals(bio.status, 200);

  await handleDoctorCardAccess(
    { action: "admin_configure", doctor_id: doctorA, enabled: false, permissions: ["bio"] },
    box.deps,
    "10.9.1.2",
    "Bearer admin",
  );
  const after = await handleDoctorCardAccess(
    { action: "update", doctor_id: doctorA, token, fields: { bio: "بعد الإيقاف" } },
    box.deps,
    "10.9.1.1",
    null,
  );
  assertEquals(after.status, 403);
  assertEquals(box.doctors.get(doctorA)?.bio, "نبذة");
});

Deno.test("lab and pharmacy owners cannot cross entities or restricted fields", async () => {
  const box = memoryDeps({ adminJwt: true });
  const issued = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "lab",
      entity_id: labA,
      enabled: true,
      permissions: ["bio", "packages"],
    },
    box.deps,
    "10.9.2.1",
    "Bearer admin",
  );
  const verify = await handleDoctorCardAccess(
    { action: "verify_code", entity_type: "lab", entity_id: labA, code: String(issued.body.activation_code) },
    box.deps,
    "10.9.2.2",
    null,
  );
  const done = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "lab",
      entity_id: labA,
      token: String(verify.body.activation_token),
      new_password: "lab-owner-pass",
    },
    box.deps,
    "10.9.2.2",
    null,
  );
  const token = String(done.body.token);
  const other = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "lab-owner-pass" },
    box.deps,
    "10.9.2.3",
    null,
  );
  assertEquals(other.body.role, undefined);
  const name = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "lab",
      entity_id: labA,
      token,
      fields: { lab_name: "مختبر" },
    },
    box.deps,
    "10.9.2.2",
    null,
  );
  assertEquals(name.status, 403);
  const pack = await handleDoctorCardAccess(
    {
      action: "upsert_package",
      base_revision: 1,
      entity_type: "lab",
      entity_id: labA,
      token,
      package: { package_name: "فحص", price: 10, display_order: 1 },
    },
    box.deps,
    "10.9.2.2",
    null,
  );
  assertEquals(pack.status, 403);

  const pharmacy = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "pharmacy",
      entity_id: "rehab",
      enabled: true,
      permissions: ["products"],
    },
    box.deps,
    "10.9.2.4",
    "Bearer admin",
  );
  const pharmacyVerify = await handleDoctorCardAccess(
    { action: "verify_code", entity_type: "pharmacy", entity_id: "rehab", code: String(pharmacy.body.activation_code) },
    box.deps,
    "10.9.2.5",
    null,
  );
  const pharmacyDone = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(pharmacyVerify.body.activation_token),
      new_password: "pharm-owner-1",
    },
    box.deps,
    "10.9.2.5",
    null,
  );
  const deniedName = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(pharmacyDone.body.token),
      fields: { name: "صيدلية" },
    },
    box.deps,
    "10.9.2.5",
    null,
  );
  assertEquals(deniedName.status, 403);
  const products = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(pharmacyDone.body.token),
      fields: { bundles: [{ name: "عرض" }] },
    },
    box.deps,
    "10.9.2.5",
    null,
  );
  assertEquals(products.status, 200);
  assertEquals(box.pharmacies.get("rehab")?.bundles != null, true);
});

Deno.test("unpublished pharmacy is not written and photos stay on that entity", async () => {
  const missing = memoryDeps({ adminJwt: true, missingPharmacy: true });
  const issued = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "pharmacy",
      entity_id: "rehab",
      enabled: true,
      permissions: ["products", "image"],
    },
    missing.deps,
    "10.9.3.1",
    "Bearer admin",
  );
  const verify = await handleDoctorCardAccess(
    {
      action: "verify_code",
      entity_type: "pharmacy",
      entity_id: "rehab",
      code: String(issued.body.activation_code),
    },
    missing.deps,
    "10.9.3.2",
    null,
  );
  const done = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(verify.body.activation_token),
      new_password: "pharm-owner-9",
    },
    missing.deps,
    "10.9.3.2",
    null,
  );
  const token = String(done.body.token);
  const blocked = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      fields: { bundles: [{ name: "محلي" }] },
    },
    missing.deps,
    "10.9.3.2",
    null,
  );
  assertEquals(blocked.status, 409);
  assertEquals(missing.pharmacies.has("rehab"), false);

  const box = memoryDeps({ adminJwt: true });
  const login = await handleDoctorCardAccess(
    { action: "login", entity_type: "pharmacy", entity_id: "rehab", password: "admin-pass-99" },
    box.deps,
    "10.9.3.3",
    null,
  );
  const upload = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(login.body.token),
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.9.3.3",
    null,
  );
  assertEquals(upload.status, 200);
  assertEquals(String(box.uploads[0]).startsWith("pharmacies/rehab/"), true);
  assertEquals(box.pharmacies.get("rehab")?.content_revision, 2);
  const other = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "shatra",
      token: String(login.body.token),
      image_base64: btoa(String.fromCharCode(...jpeg())),
    },
    box.deps,
    "10.9.3.3",
    null,
  );
  assertEquals(other.status, 403);
});

Deno.test("stale doctor and pharmacy saves lose whether admin or owner writes first", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const adminFirst = memoryDeps({ hashes: { [doctorA]: hashA }, adminJwt: true });
  const adminLogin = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "admin-pass-99" },
    adminFirst.deps,
    "10.9.4.1",
    null,
  );
  const ownerLogin = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    adminFirst.deps,
    "10.9.4.2",
    null,
  );
  const adminSave = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token: String(adminLogin.body.token),
      fields: { doctor_name: "اسم الإدارة" },
    },
    adminFirst.deps,
    "10.9.4.1",
    null,
  );
  assertEquals(adminSave.status, 200);
  const ownerLate = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token: String(ownerLogin.body.token),
      fields: { bio: "نبذة المالك" },
    },
    adminFirst.deps,
    "10.9.4.2",
    null,
  );
  assertEquals(ownerLate.status, 409);
  assertEquals(ownerLate.body.error, CONTENT_CONFLICT_MESSAGE);
  assertEquals(adminFirst.doctors.get(doctorA)?.bio, undefined);

  const ownerFirst = memoryDeps({ adminJwt: true });
  const issued = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "pharmacy",
      entity_id: "rehab",
      enabled: true,
      permissions: ["products"],
    },
    ownerFirst.deps,
    "10.9.4.3",
    "Bearer admin",
  );
  const verified = await handleDoctorCardAccess(
    {
      action: "verify_code",
      entity_type: "pharmacy",
      entity_id: "rehab",
      code: String(issued.body.activation_code),
    },
    ownerFirst.deps,
    "10.9.4.4",
    null,
  );
  const activated = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(verified.body.activation_token),
      new_password: "pharm-pass-11",
    },
    ownerFirst.deps,
    "10.9.4.4",
    null,
  );
  const ownerSave = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "pharmacy",
      entity_id: "rehab",
      token: String(activated.body.token),
      fields: { bundles: [{ title: "عرض المالك" }] },
    },
    ownerFirst.deps,
    "10.9.4.4",
    null,
  );
  assertEquals(ownerSave.status, 200);
  const adminLate = await ownerFirst.deps.savePharmacySnapshot(
    "rehab",
    { bundles: [{ title: "عرض الإدارة" }] },
    1,
  );
  assertEquals(adminLate, "conflict");
  const stored = ownerFirst.pharmacies.get("rehab")?.bundles as Array<{ title?: string }>;
  assertEquals(stored[0]?.title, "عرض المالك");
});

Deno.test("stale laboratory and package saves lose in both orders", async () => {
  const adminFirst = memoryDeps({ adminJwt: true });
  const issued = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "lab",
      entity_id: labA,
      enabled: true,
      permissions: ["bio", "packages"],
    },
    adminFirst.deps,
    "10.9.5.1",
    "Bearer admin",
  );
  const verified = await handleDoctorCardAccess(
    { action: "verify_code", entity_type: "lab", entity_id: labA, code: String(issued.body.activation_code) },
    adminFirst.deps,
    "10.9.5.2",
    null,
  );
  const activated = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "lab",
      entity_id: labA,
      token: String(verified.body.activation_token),
      new_password: "lab-pass-111",
    },
    adminFirst.deps,
    "10.9.5.2",
    null,
  );
  const ownerToken = String(activated.body.token);
  const adminLab = await adminFirst.deps.updateLab(labA, { description: "وصف الإدارة" }, 1);
  assertEquals(adminLab, 2);
  const ownerLate = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "lab",
      entity_id: labA,
      token: ownerToken,
      fields: { description: "وصف المالك" },
    },
    adminFirst.deps,
    "10.9.5.2",
    null,
  );
  assertEquals(ownerLate.status, 409);
  assertEquals(ownerLate.body.error, CONTENT_CONFLICT_MESSAGE);
  assertEquals(adminFirst.labs.get(labA)?.description, "وصف الإدارة");

  const ownerFirst = memoryDeps({ adminJwt: true });
  const issuedOwner = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "lab",
      entity_id: labA,
      enabled: true,
      permissions: ["packages"],
    },
    ownerFirst.deps,
    "10.9.5.3",
    "Bearer admin",
  );
  const verifiedOwner = await handleDoctorCardAccess(
    {
      action: "verify_code",
      entity_type: "lab",
      entity_id: labA,
      code: String(issuedOwner.body.activation_code),
    },
    ownerFirst.deps,
    "10.9.5.4",
    null,
  );
  const activatedOwner = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "lab",
      entity_id: labA,
      token: String(verifiedOwner.body.activation_token),
      new_password: "lab-pass-222",
    },
    ownerFirst.deps,
    "10.9.5.4",
    null,
  );
  const packageId = "44444444-4444-4444-8444-444444444444";
  const ownerPackage = await handleDoctorCardAccess(
    {
      action: "upsert_package",
      base_revision: 1,
      entity_type: "lab",
      entity_id: labA,
      token: String(activatedOwner.body.token),
      package_id: packageId,
      package: { package_name: "باقة المالك", price: 10 },
    },
    ownerFirst.deps,
    "10.9.5.4",
    null,
  );
  assertEquals(ownerPackage.status, 200);
  const adminLate = await ownerFirst.deps.upsertLabPackage(
    labA,
    packageId,
    { package_name: "باقة الإدارة" },
    1,
  );
  assertEquals(adminLate, null);
  assertEquals(ownerFirst.packages.get(packageId)?.package_name, "باقة المالك");
});

Deno.test("pharmacyBundlesPermissionDenied separates add edit delete", () => {
  const prev = [{ id: "b1", title: "أ" }];
  assertEquals(
    pharmacyBundlesPermissionDenied(["packages_add"], prev, [
      ...prev,
      { id: "b2", title: "ب" },
    ]),
    false,
  );
  assertEquals(
    pharmacyBundlesPermissionDenied(["packages_add"], prev, [
      { id: "b1", title: "معدّل" },
    ]),
    true,
  );
  assertEquals(
    pharmacyBundlesPermissionDenied(["packages_edit"], prev, [
      { id: "b1", title: "معدّل" },
    ]),
    false,
  );
  assertEquals(
    pharmacyBundlesPermissionDenied(["packages_edit"], prev, []),
    true,
  );
  assertEquals(
    pharmacyBundlesPermissionDenied(["packages_delete"], prev, []),
    false,
  );
  assertEquals(
    pharmacyBundlesPermissionDenied(["products"], prev, [
      { id: "new", title: "شامل" },
    ]),
    false,
  );
});

Deno.test("pharmacy owner package CRUD permissions and mid-session revoke", async () => {
  const hash = await hashPassword("pharm-pass-11", 2);
  const box = memoryDeps({ hashes: { rehab: hash } });
  box.access.set("pharmacy:rehab", {
    enabled: true,
    passwordHash: hash,
    sessionVersion: 1,
    permissions: ["packages_add"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });
  box.pharmacies.set("rehab", {
    bundles: [{ id: "keep", title: "باقة موجودة" }],
    content_revision: 1,
  });

  const login = await handleDoctorCardAccess(
    { action: "login", entity_type: "pharmacy", entity_id: "rehab", password: "pharm-pass-11" },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(login.status, 200);
  const token = String(login.body.token);

  const addOk = await handleDoctorCardAccess(
    {
      action: "update",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      base_revision: 1,
      fields: {
        bundles: [
          { id: "keep", title: "باقة موجودة" },
          { id: "new1", title: "جديدة" },
        ],
      },
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(addOk.status, 200);

  const editDenied = await handleDoctorCardAccess(
    {
      action: "update",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      base_revision: 2,
      fields: {
        bundles: [
          { id: "keep", title: "تعديل مرفوض" },
          { id: "new1", title: "جديدة" },
        ],
      },
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(editDenied.status, 403);
  assertEquals(editDenied.body.code, "forbidden");

  // سحب الصلاحية أثناء الجلسة المفتوحة
  box.access.set("pharmacy:rehab", {
    enabled: true,
    passwordHash: hash,
    sessionVersion: 1,
    permissions: ["packages_edit"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });

  const addAfterRevoke = await handleDoctorCardAccess(
    {
      action: "update",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      base_revision: 2,
      fields: {
        bundles: [
          { id: "keep", title: "باقة موجودة" },
          { id: "new1", title: "جديدة" },
          { id: "new2", title: "أخرى" },
        ],
      },
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(addAfterRevoke.status, 403);

  const editAfterGrant = await handleDoctorCardAccess(
    {
      action: "update",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      base_revision: 2,
      fields: {
        bundles: [
          { id: "keep", title: "معدّلة" },
          { id: "new1", title: "جديدة" },
        ],
      },
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(editAfterGrant.status, 200);

  const assetDenied = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      asset_only: true,
      image_base64: btoa(String.fromCharCode(...jpeg(48))),
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  // packages_edit يسمح برفع أصل الباقة
  assertEquals(assetDenied.status, 200);

  box.access.set("pharmacy:rehab", {
    enabled: true,
    passwordHash: hash,
    sessionVersion: 1,
    permissions: ["bio"],
    activationCodeHash: null,
    activationExpiresAt: null,
  });
  const assetRevoked = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      entity_type: "pharmacy",
      entity_id: "rehab",
      token,
      asset_only: true,
      image_base64: btoa(String.fromCharCode(...jpeg(48))),
    },
    box.deps,
    "10.20.1.1",
    null,
  );
  assertEquals(assetRevoked.status, 403);
});

Deno.test("service center owner edits only that center and a visitor cannot write", async () => {
  const box = memoryDeps({ adminJwt: true });
  const opticsId = "sc_optics_local";
  const beautyId = "sc_beauty_local";
  box.centers.set(opticsId, {
    name: "مركز تجريبي — للفحص",
    bio: "قبل",
    content_revision: 1,
  });
  box.centers.set(beautyId, {
    name: "مركز تجريبي — للفحص",
    bio: "تجميل",
    content_revision: 1,
  });

  const visitor = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "optics",
      entity_id: opticsId,
      fields: { bio: "من زائر" },
    },
    box.deps,
    "10.21.0.1",
    null,
  );
  assertEquals(visitor.status, 403);
  assertEquals(box.centers.get(opticsId)?.bio, "قبل");

  const issued = await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "optics",
      entity_id: opticsId,
      enabled: true,
      permissions: ["bio", "services", "hours", "location"],
    },
    box.deps,
    "10.21.0.2",
    "Bearer admin",
  );
  const verify = await handleDoctorCardAccess(
    {
      action: "verify_code",
      entity_type: "optics",
      entity_id: opticsId,
      code: String(issued.body.activation_code),
    },
    box.deps,
    "10.21.0.3",
    null,
  );
  const done = await handleDoctorCardAccess(
    {
      action: "complete_activation",
      entity_type: "optics",
      entity_id: opticsId,
      token: String(verify.body.activation_token),
      new_password: "optics-owner-1",
    },
    box.deps,
    "10.21.0.3",
    null,
  );
  const token = String(done.body.token);
  const saved = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "optics",
      entity_id: opticsId,
      token,
      fields: {
        bio: "بعد التعديل",
        services: ["فحص نظر محلي"],
        hours: "٩ صباحاً حتى ١ ظهراً",
        address: "عنوان فحص محلي",
        name: "اسم مسروق",
      },
    },
    box.deps,
    "10.21.0.3",
    null,
  );
  assertEquals(saved.status, 403);
  assertEquals(box.centers.get(opticsId)?.bio, "قبل");

  const allowed = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "optics",
      entity_id: opticsId,
      token,
      fields: {
        bio: "بعد التعديل",
        services: ["فحص نظر محلي"],
        hours: "٩ صباحاً حتى ١ ظهراً",
        address: "عنوان فحص محلي",
      },
    },
    box.deps,
    "10.21.0.3",
    null,
  );
  assertEquals(allowed.status, 200);
  const reopened = box.centers.get(opticsId);
  assertEquals(reopened?.bio, "بعد التعديل");
  assertEquals(reopened?.name, "مركز تجريبي — للفحص");
  assertEquals(reopened?.content_revision, 2);

  const other = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "beauty",
      entity_id: beautyId,
      token,
      fields: { bio: "تعديل مركز آخر" },
    },
    box.deps,
    "10.21.0.4",
    null,
  );
  assertEquals(other.status, 403);
  assertEquals(box.centers.get(beautyId)?.bio, "تجميل");

  await handleDoctorCardAccess(
    {
      action: "admin_configure",
      entity_type: "optics",
      entity_id: opticsId,
      enabled: false,
      permissions: ["bio"],
    },
    box.deps,
    "10.21.0.5",
    "Bearer admin",
  );
  const afterRevoke = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 2,
      entity_type: "optics",
      entity_id: opticsId,
      token,
      fields: { bio: "بعد الإلغاء" },
    },
    box.deps,
    "10.21.0.3",
    null,
  );
  assertEquals(afterRevoke.status, 403);
  assertEquals(box.centers.get(opticsId)?.bio, "بعد التعديل");
});

Deno.test("logo object path matches admin client folder/id/logos pattern", () => {
  const root = "doctors";
  const id = doctorA;
  const folder = `${root}/${id}/logos`;
  const path = `${folder}/logo-file.png`;
  assertEquals(path.startsWith(`${folder}/`), true);
  assertEquals(path, `doctors/${doctorA}/logos/logo-file.png`);
});

Deno.test("logo upload does not replace the portrait and needs image permission", async () => {
  const hashA = await hashPassword("secret-a-111", 2);
  const box = memoryDeps({ hashes: { [doctorA]: hashA } });
  box.doctors.set(doctorA, {
    image_url: "https://cdn.example/face.jpg",
    content_revision: 1,
  });
  box.access.set(`doctor:${doctorA}`, {
    ...box.access.get(`doctor:${doctorA}`)!,
    permissions: ["bio"],
  });
  const login = await handleDoctorCardAccess(
    { action: "login", doctor_id: doctorA, password: "secret-a-111" },
    box.deps,
    "10.22.0.1",
    null,
  );
  const token = String(login.body.token);
  const denied = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: { logo_url: "https://cdn.example/logo.png" },
    },
    box.deps,
    "10.22.0.1",
    null,
  );
  assertEquals(denied.status, 403);
  assertEquals(box.doctors.get(doctorA)?.image_url, "https://cdn.example/face.jpg");
  assertEquals(box.doctors.get(doctorA)?.logo_url, undefined);

  box.access.set(`doctor:${doctorA}`, {
    ...box.access.get(`doctor:${doctorA}`)!,
    permissions: ["image"],
  });
  const saved = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      doctor_id: doctorA,
      token,
      fields: { logo_url: "https://cdn.example/logo.png" },
    },
    box.deps,
    "10.22.0.1",
    null,
  );
  assertEquals(saved.status, 200);
  assertEquals(box.doctors.get(doctorA)?.image_url, "https://cdn.example/face.jpg");
  assertEquals(box.doctors.get(doctorA)?.logo_url, "https://cdn.example/logo.png");

  const uploaded = await handleDoctorCardAccess(
    {
      action: "upload_photo",
      doctor_id: doctorA,
      token,
      logo: true,
      image_base64: btoa(String.fromCharCode(...jpeg(48))),
    },
    box.deps,
    "10.22.0.1",
    null,
  );
  assertEquals(uploaded.status, 200);
  assertEquals(
    box.uploads.some((p) => p.startsWith(`doctors/${doctorA}/logos/`)),
    true,
  );
  assertEquals(box.doctors.get(doctorA)?.image_url, "https://cdn.example/face.jpg");

  const other = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "doctor",
      entity_id: doctorB,
      token,
      fields: { logo_url: "https://cdn.example/other.png" },
    },
    box.deps,
    "10.22.0.2",
    null,
  );
  assertEquals(other.status, 403);
});

Deno.test("radiology, physio and supply owners edit only their own card", async () => {
  const box = memoryDeps({ adminJwt: true });
  const radiologyId = "11111111-2222-4333-8444-555555555555";
  box.directory.set(`radiology:${radiologyId}`, { bio: "قبل", content_revision: 1 });
  box.directory.set("physio:physio_shatra", { bio: "قبل", content_revision: 1 });
  box.directory.set("supply:medequip_shatra", { bio: "قبل", content_revision: 1 });

  async function ownerToken(type: string, id: string, perms: string[], ip: string) {
    const issued = await handleDoctorCardAccess(
      { action: "admin_configure", entity_type: type, entity_id: id, enabled: true, permissions: perms },
      box.deps,
      ip,
      "Bearer admin",
    );
    const verify = await handleDoctorCardAccess(
      { action: "verify_code", entity_type: type, entity_id: id, code: String(issued.body.activation_code) },
      box.deps,
      ip,
      null,
    );
    const done = await handleDoctorCardAccess(
      {
        action: "complete_activation",
        entity_type: type,
        entity_id: id,
        token: String(verify.body.activation_token),
        new_password: `${type}-owner-1`,
      },
      box.deps,
      ip,
      null,
    );
    return String(done.body.token);
  }

  const visitor = await handleDoctorCardAccess(
    { action: "update", base_revision: 1, entity_type: "physio", entity_id: "physio_shatra", fields: { bio: "زائر" } },
    box.deps,
    "10.31.0.1",
    null,
  );
  assertEquals(visitor.status, 403);

  const physioToken = await ownerToken("physio", "physio_shatra", ["bio", "services", "hours"], "10.31.0.2");
  const physioSaved = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "physio",
      entity_id: "physio_shatra",
      token: physioToken,
      fields: { bio: "بعد", services: ["تأهيل"], hours: "4 - 9" },
    },
    box.deps,
    "10.31.0.2",
    null,
  );
  assertEquals(physioSaved.status, 200);
  assertEquals(box.directory.get("physio:physio_shatra")?.bio, "بعد");

  // نفس الجلسة ما تعدّل التجهيزات.
  const crossed = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "supply",
      entity_id: "medequip_shatra",
      token: physioToken,
      fields: { bio: "تعدي" },
    },
    box.deps,
    "10.31.0.3",
    null,
  );
  assertEquals(crossed.status, 403);
  assertEquals(box.directory.get("supply:medequip_shatra")?.bio, "قبل");

  // صلاحية غير ممنوحة (الأرقام) مرفوضة.
  const noContacts = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 2,
      entity_type: "physio",
      entity_id: "physio_shatra",
      token: physioToken,
      fields: { phone: "0770" },
    },
    box.deps,
    "10.31.0.2",
    null,
  );
  assertEquals(noContacts.status, 403);

  const radToken = await ownerToken("radiology", radiologyId, ["bio", "hours", "location"], "10.31.0.4");
  const radServices = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "radiology",
      entity_id: radiologyId,
      token: radToken,
      fields: { latitude: 31.4 },
    },
    box.deps,
    "10.31.0.4",
    null,
  );
  assertEquals(radServices.status, 403);
  const radSaved = await handleDoctorCardAccess(
    {
      action: "update",
      base_revision: 1,
      entity_type: "radiology",
      entity_id: radiologyId,
      token: radToken,
      fields: { bio: "مركز أشعة", hours: "٨ صباحاً - ٨ مساءً" },
    },
    box.deps,
    "10.31.0.4",
    null,
  );
  assertEquals(radSaved.status, 200);
  assertEquals(box.directory.get(`radiology:${radiologyId}`)?.bio, "مركز أشعة");
});
