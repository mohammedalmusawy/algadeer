// سياسة دخول بطاقة الطبيب. تُستدعى من Edge Function فقط.
// لا كلمات مرور ولا أسرار في هذا الملف.

export const PBKDF2_ITERATIONS = 210_000;
export const MAX_FAILURES = 5;
export const ATTEMPT_WINDOW_MS = 5 * 60 * 1000;
export const LOCK_MS = 5 * 60 * 1000;
export const ACTIVATION_TTL_MS = 2 * 60 * 60 * 1000;
export const TOKEN_TTL_SEC = 20 * 60;
export const ACTIVATION_TOKEN_TTL_SEC = 10 * 60;
export const CONTENT_CONFLICT_MESSAGE =
  "تعذر الحفظ لأن البيانات تغيّرت من جهة أخرى. ما كتبته ما زال في النموذج.";
export const MAX_IMAGE_BYTES = 1_500_000;
export const MIN_IMAGE_BYTES = 32;

export const DOCTOR_FIELDS = [
  "bio",
  "services",
  "short_description",
  "working_days",
  "working_hours",
  "phone",
  "whatsapp",
  "booking_status",
  "logo_url",
] as const;

export const ADMIN_FIELDS = [
  ...DOCTOR_FIELDS,
  "doctor_name",
  "specialty",
  "clinic_location",
  "is_active",
  "display_order",
] as const;

const DOCTOR_BOOKING = new Set(["available", "walk_in_only", "full"]);
const ADMIN_BOOKING = new Set([
  "available",
  "walk_in_only",
  "full",
  "unavailable",
]);

const TEXT_LIMITS: Record<string, number> = {
  bio: 4000,
  services: 4000,
  short_description: 4000,
  working_days: 2000,
  working_hours: 2000,
  phone: 40,
  whatsapp: 40,
  doctor_name: 200,
  specialty: 200,
  clinic_location: 300,
  logo_url: 2000,
};

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Role = "owner" | "admin";
export type EntityType =
  | "doctor"
  | "lab"
  | "pharmacy"
  | "optics"
  | "beauty"
  | "nursing"
  | "radiology"
  | "physio"
  | "supply";
export type AttemptKind = "password" | "activation";

export const OWNER_PERMISSIONS: Record<EntityType, readonly string[]> = {
  doctor: ["image", "bio", "services", "schedule", "contacts", "booking_status"],
  lab: ["image", "bio", "hours", "contacts", "packages"],
  pharmacy: [
    "image",
    "bio",
    "hours",
    "contacts",
    "products",
    "packages_add",
    "packages_edit",
    "packages_delete",
  ],
  optics: ["image", "bio", "services", "hours", "contacts", "location"],
  beauty: ["image", "bio", "services", "hours", "contacts", "location"],
  nursing: ["image", "bio", "services", "hours", "contacts", "location"],
  radiology: ["image", "bio", "hours", "contacts", "location"],
  physio: ["image", "bio", "services", "hours", "contacts", "location"],
  supply: ["image", "bio", "services", "hours", "contacts", "location"],
};

export type OwnerAccess = {
  enabled: boolean;
  passwordHash: string | null;
  sessionVersion: number;
  permissions: string[];
  activationCodeHash: string | null;
  activationExpiresAt: number | null;
};

export type AttemptState = {
  failures: number;
  windowStarted: number;
  lockedUntil: number | null;
};

export type AccessBody = {
  action?: string;
  entity_type?: string;
  entity_id?: string;
  doctor_id?: string;
  password?: string;
  code?: string;
  token?: string;
  fields?: Record<string, unknown>;
  old_password?: string;
  new_password?: string;
  image_base64?: string;
  enabled?: boolean;
  permissions?: unknown;
  reset?: boolean;
  reissue?: boolean;
  package?: Record<string, unknown>;
  package_id?: string;
  package_image?: boolean;
  asset_only?: boolean;
  logo?: boolean;
  base_revision?: number;
};

export type HandlerResult = {
  status: number;
  body: Record<string, unknown>;
};

export type DoctorMeta = { is_active: boolean; display_order: number };

export type CardDeps = {
  now(): number;
  tokenSecret: string;
  hashIterations?: number;
  loadAccess(type: EntityType, id: string): Promise<OwnerAccess | null>;
  saveAccess(type: EntityType, id: string, access: OwnerAccess): Promise<void>;
  consumeActivation(
    type: EntityType,
    id: string,
    codeHash: string,
    passwordHash: string,
    sessionVersion: number,
  ): Promise<number | null>;
  loadDoctorMeta(doctorId: string): Promise<DoctorMeta | null>;
  loadAttempt(
    sourceHash: string,
    type: EntityType,
    id: string,
    kind: AttemptKind,
  ): Promise<AttemptState | null>;
  saveAttempt(
    sourceHash: string,
    type: EntityType,
    id: string,
    kind: AttemptKind,
    state: AttemptState,
  ): Promise<void>;
  clearAttempt(
    sourceHash: string,
    type: EntityType,
    id: string,
    kind: AttemptKind,
  ): Promise<void>;
  updateDoctor(
    doctorId: string,
    patch: Record<string, unknown>,
    expectedRevision: number,
  ): Promise<number | null>;
  deleteDoctor(doctorId: string): Promise<void>;
  updateLab(
    labId: string,
    patch: Record<string, unknown>,
    expectedRevision: number,
  ): Promise<number | null>;
  upsertLabPackage(
    labId: string,
    packageId: string | null,
    patch: Record<string, unknown>,
    expectedRevision: number | null,
  ): Promise<number | null>;
  deleteLabPackage(labId: string, packageId: string): Promise<void>;
  savePharmacySnapshot(
    pharmacyId: string,
    patch: Record<string, unknown>,
    expectedRevision: number,
    permissions?: readonly string[],
  ): Promise<"ok" | "missing" | "conflict" | "forbidden">;
  saveServiceCenter(
    centerId: string,
    patch: Record<string, unknown>,
    expectedRevision: number,
  ): Promise<"ok" | "missing" | "conflict" | "forbidden">;
  /** الأشعة والعلاج الطبيعي والتجهيزات: نفس حقول المراكز، جدول لكل قسم. */
  saveDirectoryEntity(
    type: "radiology" | "physio" | "supply",
    id: string,
    patch: Record<string, unknown>,
    expectedRevision: number,
  ): Promise<"ok" | "missing" | "conflict" | "forbidden">;
  uploadImage(path: string, bytes: Uint8Array, contentType: string): Promise<string>;
  verifyAdminPassword(password: string): Promise<boolean>;
  verifyAdminJwt(authorization: string | null): Promise<boolean>;
  sourceHash(ip: string): Promise<string>;
};

export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export function clientIp(headers: Headers): string | null {
  const cf = headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const real = headers.get("x-real-ip")?.trim();
  if (real) return real;
  const forwarded = headers.get("x-forwarded-for");
  if (!forwarded) return null;
  const first = forwarded.split(",")[0]?.trim();
  return first || null;
}

export function isLocked(state: AttemptState | null, now: number): boolean {
  return state?.lockedUntil != null && state.lockedUntil > now;
}

export function nextFailure(
  prev: AttemptState | null,
  now: number,
): { state: AttemptState; locked: boolean } {
  const fresh = !prev ||
    (prev.lockedUntil != null && prev.lockedUntil <= now) ||
    now - prev.windowStarted >= ATTEMPT_WINDOW_MS;
  const failures = (fresh ? 0 : prev!.failures) + 1;
  const locked = failures >= MAX_FAILURES;
  return {
    locked,
    state: {
      failures,
      windowStarted: fresh ? now : prev!.windowStarted,
      lockedUntil: locked ? now + LOCK_MS : null,
    },
  };
}

export function validateNewPassword(raw: string): string | null {
  const password = raw.trim();
  if (password.length < 8) return "كلمة المرور قصيرة. الحد الأدنى 8 خانات.";
  if (password.length > 64) return "كلمة المرور طويلة جدًا.";
  if (/[\u0000-\u001f]/.test(password)) return "كلمة المرور غير مقبولة.";
  return null;
}

function b64urlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function asBuffer(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy;
}

function b64urlDecode(value: string): Uint8Array<ArrayBuffer> {
  const pad = value.length % 4 === 0 ? "" : "=".repeat(4 - (value.length % 4));
  const binary = atob(value.replaceAll("-", "+").replaceAll("_", "/") + pad);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

export function decodeBase64(value: string): Uint8Array {
  const clean = value.replace(/\s/g, "");
  const pad = clean.length % 4 === 0 ? "" : "=".repeat(4 - (clean.length % 4));
  const binary = atob(clean.replaceAll("-", "+").replaceAll("_", "/") + pad);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
  return out;
}

async function pbkdf2(
  password: string,
  salt: Uint8Array,
  iterations: number,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: asBuffer(salt), iterations },
    key,
    256,
  );
  return new Uint8Array(bits);
}

function safeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function hashPassword(
  password: string,
  iterations = PBKDF2_ITERATIONS,
): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, iterations);
  return `pbkdf2_sha256$${iterations}$${b64urlEncode(salt)}$${b64urlEncode(hash)}`;
}

export async function verifyPassword(
  stored: string | null,
  password: string,
): Promise<boolean> {
  const fallbackIterations = PBKDF2_ITERATIONS;
  let iterations = fallbackIterations;
  let salt = crypto.getRandomValues(new Uint8Array(16));
  let expected = new Uint8Array(32);
  let comparable = false;
  if (stored) {
    const parts = stored.split("$");
    if (parts.length === 4 && parts[0] === "pbkdf2_sha256") {
      const parsed = Number(parts[1]);
      if (Number.isFinite(parsed) && parsed >= 1 && parsed <= 2_000_000) {
        try {
          salt = b64urlDecode(parts[2]);
          expected = b64urlDecode(parts[3]);
          iterations = parsed;
          comparable = expected.length === 32 && salt.length >= 8;
        } catch {
          comparable = false;
        }
      }
    }
  }
  const actual = await pbkdf2(password, salt, iterations);
  if (!comparable) return false;
  return safeEqual(actual, expected);
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export type TokenSession = {
  entityType: EntityType;
  entityId: string;
  role: Role;
  sessionVersion: number;
  purpose: "session" | "activation";
  codeHash: string | null;
};

export async function signToken(
  secret: string,
  session: Omit<TokenSession, "codeHash"> & { codeHash?: string | null },
  nowSec: number,
  ttlSec = TOKEN_TTL_SEC,
): Promise<{ token: string; expiresAt: number }> {
  const expiresAt = nowSec + ttlSec;
  const payload = b64urlEncode(
    new TextEncoder().encode(JSON.stringify({
      d: session.entityId,
      y: session.entityType,
      r: session.role,
      e: expiresAt,
      sv: session.sessionVersion,
      p: session.purpose,
      c: session.codeHash ?? "",
    })),
  );
  const key = await hmacKey(secret);
  const sig = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)),
  );
  return { token: `${payload}.${b64urlEncode(sig)}`, expiresAt };
}

export async function readToken(
  secret: string,
  token: string,
  nowSec: number,
): Promise<TokenSession | null> {
  const parts = token.split(".");
  if (parts.length !== 2 || !secret) return null;
  try {
    const key = await hmacKey(secret);
    const ok = await crypto.subtle.verify(
      "HMAC",
      key,
      asBuffer(b64urlDecode(parts[1])),
      new TextEncoder().encode(parts[0]),
    );
    if (!ok) return null;
    const json = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
    const entityType = json?.y;
    if (!isEntityType(entityType)) return null;
    if (json?.r !== "owner" && json?.r !== "admin") return null;
    if (json?.p !== "session" && json?.p !== "activation") return null;
    if (typeof json.d !== "string" || !isEntityId(entityType, json.d)) return null;
    if (typeof json.e !== "number" || json.e < nowSec) return null;
    if (typeof json.sv !== "number") return null;
    return {
      entityType,
      entityId: json.d,
      role: json.r,
      sessionVersion: json.sv,
      purpose: json.p,
      codeHash: typeof json.c === "string" && json.c ? json.c : null,
    };
  } catch {
    return null;
  }
}

export function isEntityType(value: string): value is EntityType {
  return value === "doctor" || value === "lab" || value === "pharmacy" ||
    value === "optics" || value === "beauty" || value === "nursing" ||
    value === "radiology" || value === "physio" || value === "supply";
}

/** عوينات / تجميل / تمريض منزلي — كلها بجدول service_centers. */
export function isServiceCenterType(type: EntityType): boolean {
  return type === "optics" || type === "beauty" || type === "nursing";
}

/** أقسام الدليل اللي يعدّلها المالك بحقول المراكز وتنحفظ بجدولها. */
export function isDirectoryType(
  type: EntityType,
): type is "radiology" | "physio" | "supply" {
  return type === "radiology" || type === "physio" || type === "supply";
}

/** مجلد الصور لكل قسم بـ clinic-media. */
export function directoryImageRoot(type: "radiology" | "physio" | "supply"): string {
  return type === "radiology" ? "radiology" : type === "physio" ? "physio" : "supplies";
}

export function isEntityId(type: EntityType, id: string): boolean {
  if (type === "physio" || type === "supply") {
    return /^[A-Za-z0-9_-]{1,64}$/.test(id);
  }
  if (type === "pharmacy" || isServiceCenterType(type)) {
    return /^[A-Za-z0-9_-]{1,64}$/.test(id);
  }
  return isUuid(id);
}

export function acceptFields(
  role: Role,
  fields: Record<string, unknown>,
): { ok: true; patch: Record<string, unknown> } | { ok: false } {
  const allowed = new Set<string>(role === "admin" ? ADMIN_FIELDS : DOCTOR_FIELDS);
  const patch: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (!allowed.has(key)) return { ok: false };
    if (key === "is_active") {
      if (typeof value !== "boolean") return { ok: false };
      patch[key] = value;
      continue;
    }
    if (key === "display_order") {
      if (typeof value !== "number" || !Number.isInteger(value)) return { ok: false };
      if (value < 0 || value > 100_000) return { ok: false };
      patch[key] = value;
      continue;
    }
    if (typeof value !== "string") return { ok: false };
    const text = value.trim();
    const limit = TEXT_LIMITS[key] ?? 200;
    if (text.length > limit) return { ok: false };
    if (key === "booking_status") {
      const set = role === "admin" ? ADMIN_BOOKING : DOCTOR_BOOKING;
      if (!set.has(text)) return { ok: false };
    }
    if ((key === "doctor_name" || key === "specialty") && text.length === 0) {
      return { ok: false };
    }
    patch[key] = text;
  }
  if (Object.keys(patch).length === 0) return { ok: false };
  return { ok: true, patch };
}

export type ImageCheck =
  | { ok: true; ext: "jpg" | "png" | "webp"; contentType: string }
  | { ok: false };

export function inspectImage(bytes: Uint8Array): ImageCheck {
  if (bytes.length < MIN_IMAGE_BYTES || bytes.length > MAX_IMAGE_BYTES) {
    return { ok: false };
  }
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { ok: true, ext: "jpg", contentType: "image/jpeg" };
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return { ok: true, ext: "png", contentType: "image/png" };
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return { ok: true, ext: "webp", contentType: "image/webp" };
  }
  return { ok: false };
}

export function imageObjectPath(
  doctorId: string,
  ext: string,
  objectId: string,
): string | null {
  if (!isUuid(doctorId)) return null;
  if (ext !== "jpg" && ext !== "png" && ext !== "webp") return null;
  if (!/^[0-9a-f-]{36}$/i.test(objectId)) return null;
  return `doctors/${doctorId}/${objectId}.${ext}`;
}

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function generateActivationCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(10));
  let out = "";
  for (const b of bytes) out += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return out;
}

export async function hashActivationCode(secret: string, code: string): Promise<string> {
  const key = await hmacKey(secret);
  const normalized = code.trim().toUpperCase().replace(/\s+/g, "");
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`act|${normalized}`),
    ),
  );
  return b64urlEncode(sig);
}

export function cleanPermissions(type: EntityType, raw: unknown): string[] {
  const allowed = new Set<string>(OWNER_PERMISSIONS[type]);
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const item of raw) {
    if (typeof item === "string" && allowed.has(item) && !out.includes(item)) {
      out.push(item);
    }
  }
  return out;
}

function blankAccess(): OwnerAccess {
  return {
    enabled: false,
    passwordHash: null,
    sessionVersion: 1,
    permissions: [],
    activationCodeHash: null,
    activationExpiresAt: null,
  };
}

export function accessMode(access: OwnerAccess | null): "disabled" | "activate" | "password" {
  if (!access?.enabled) return "disabled";
  return access.passwordHash ? "password" : "activate";
}

export function waitMessage(now: number, lockedUntil: number): string {
  const totalSec = Math.max(1, Math.ceil((lockedUntil - now) / 1000));
  const minutes = Math.floor(totalSec / 60);
  const seconds = totalSec % 60;
  if (minutes > 0 && seconds > 0) {
    return `محاولات كثيرة. حاول بعد ${minutes} دقائق و${seconds} ثانية.`;
  }
  if (minutes > 0) return `محاولات كثيرة. حاول بعد ${minutes} دقائق.`;
  return `محاولات كثيرة. حاول بعد ${seconds} ثانية.`;
}

function resolveTarget(body: AccessBody): { type: EntityType; id: string } | null {
  const type = body.entity_type ?? (body.doctor_id ? "doctor" : "");
  const id = (body.entity_id ?? body.doctor_id ?? "").trim();
  if (!isEntityType(type)) return null;
  if (!isEntityId(type, id)) return null;
  return { type, id };
}

function doctorPermission(key: string): string | null {
  if (key === "bio" || key === "short_description") return "bio";
  if (key === "services") return "services";
  if (key === "working_days" || key === "working_hours") return "schedule";
  if (key === "phone" || key === "whatsapp") return "contacts";
  if (key === "booking_status") return "booking_status";
  if (key === "logo_url") return "image";
  return null;
}

const LAB_OWNER_FIELDS = new Set([
  "description",
  "slogan",
  "working_hours",
  "phone",
  "whatsapp",
  "logo_url",
]);

function labPermission(key: string): string | null {
  if (key === "description" || key === "slogan") return "bio";
  if (key === "working_hours") return "hours";
  if (key === "phone" || key === "whatsapp") return "contacts";
  if (key === "logo_url") return "image";
  return null;
}

const PHARMACY_FIELDS: Record<string, string> = {
  imageUrl: "image",
  logoUrl: "image",
  slogan: "bio",
  openFrom: "hours",
  openTo: "hours",
  phone: "contacts",
  whatsapp: "contacts",
  offerPercent: "products",
  offerImageUrl: "products",
  offerIconUrl: "products",
};

const CENTER_FIELDS: Record<string, string> = {
  imageUrl: "image",
  logoUrl: "image",
  bio: "bio",
  services: "services",
  hours: "hours",
  phone: "contacts",
  whatsapp: "contacts",
  address: "location",
  mapUrl: "location",
  latitude: "location",
  longitude: "location",
};

function acceptCenterFields(
  fields: Record<string, unknown>,
  permissions: readonly string[],
): Record<string, unknown> | null {
  const patch: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    const perm = CENTER_FIELDS[key];
    if (!perm || !permissions.includes(perm)) return null;
    if (key === "services") {
      if (!Array.isArray(value) || value.length > 40) return null;
      const services: string[] = [];
      for (const item of value) {
        if (typeof item !== "string") return null;
        const text = item.trim();
        if (!text || text.length > 120) return null;
        services.push(text);
      }
      patch.services = services;
      continue;
    }
    if (key === "latitude" || key === "longitude") {
      if (typeof value !== "number" || !Number.isFinite(value)) return null;
      const limit = key === "latitude" ? 90 : 180;
      if (value < -limit || value > limit) return null;
      patch[key] = value;
      continue;
    }
    if (typeof value !== "string") return null;
    const text = value.trim();
    if (text.length > 4000 || text.startsWith("data:")) return null;
    patch[key] = text;
  }
  return Object.keys(patch).length === 0 ? null : patch;
}

function pharmacyCanTouchBundles(permissions: readonly string[]): boolean {
  return permissions.includes("products") ||
    permissions.includes("packages_add") ||
    permissions.includes("packages_edit") ||
    permissions.includes("packages_delete");
}

/** يفرّق إضافة/تعديل/حذف باقة محفوظة عن صلاحية products الشاملة. */
export function pharmacyBundlesPermissionDenied(
  permissions: readonly string[],
  previous: unknown,
  next: unknown,
): boolean {
  if (permissions.includes("products")) return false;
  const prevList = Array.isArray(previous) ? previous : [];
  const nextList = Array.isArray(next) ? next : [];
  const prevById = new Map<string, string>();
  for (const row of prevList) {
    if (!row || typeof row !== "object") continue;
    const id = String((row as Record<string, unknown>).id ?? "");
    if (!id) continue;
    prevById.set(id, JSON.stringify(row));
  }
  const nextIds = new Set<string>();
  for (const row of nextList) {
    if (!row || typeof row !== "object") continue;
    const id = String((row as Record<string, unknown>).id ?? "");
    if (!id) continue;
    nextIds.add(id);
    const prev = prevById.get(id);
    if (prev == null) {
      if (!permissions.includes("packages_add")) return true;
    } else if (prev !== JSON.stringify(row)) {
      if (!permissions.includes("packages_edit")) return true;
    }
  }
  for (const id of prevById.keys()) {
    if (!nextIds.has(id) && !permissions.includes("packages_delete")) return true;
  }
  return false;
}

function pharmacyPatchHasPrivateImage(value: unknown): boolean {
  if (typeof value === "string") return value.trim().startsWith("data:");
  if (Array.isArray(value)) return value.some(pharmacyPatchHasPrivateImage);
  if (value && typeof value === "object") {
    return Object.values(value).some(pharmacyPatchHasPrivateImage);
  }
  return false;
}

const PACKAGE_FIELDS = new Set([
  "package_name",
  "description",
  "old_price",
  "price",
  "image_url",
  "tests",
  "is_active",
]);

function invalid(kind: AttemptKind = "password"): HandlerResult {
  return {
    status: 401,
    body: {
      ok: false,
      code: "invalid",
      error: kind === "activation" ? "رمز التفعيل غير صحيح" : "كلمة المرور غير صحيحة",
    },
  };
}

function locked(now: number, until: number): HandlerResult {
  const wait = Math.max(1, Math.ceil((until - now) / 1000));
  return {
    status: 429,
    body: {
      ok: false,
      code: "locked",
      error: waitMessage(now, until),
      wait_seconds: wait,
    },
  };
}

function conflict(): HandlerResult {
  return {
    status: 409,
    body: {
      ok: false,
      code: "conflict",
      error: CONTENT_CONFLICT_MESSAGE,
    },
  };
}

function expectedRevision(body: AccessBody): number | HandlerResult {
  const value = body.base_revision;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
    return {
      status: 400,
      body: { ok: false, code: "bad_request", error: "نسخة البيانات غير معروفة." },
    };
  }
  return value;
}

function forbidden(): HandlerResult {
  return {
    status: 403,
    body: { ok: false, code: "forbidden", error: "هذا التعديل غير مسموح لصلاحيتك." },
  };
}

function badImage(): HandlerResult {
  return {
    status: 400,
    body: {
      ok: false,
      code: "bad_image",
      error: "الصورة غير مقبولة. استخدم JPG أو PNG أو WEBP وبحجم أصغر.",
    },
  };
}

function unconfigured(): HandlerResult {
  return {
    status: 503,
    body: {
      ok: false,
      code: "unconfigured",
      error: "خدمة التحقق غير جاهزة. راجع إعداد المشروع.",
    },
  };
}

async function recordFailure(
  deps: CardDeps,
  sourceHash: string,
  type: EntityType,
  id: string,
  kind: AttemptKind,
  prev: AttemptState | null,
): Promise<HandlerResult> {
  const step = nextFailure(prev, deps.now());
  await deps.saveAttempt(sourceHash, type, id, kind, step.state);
  if (step.locked && step.state.lockedUntil) {
    return locked(deps.now(), step.state.lockedUntil);
  }
  return invalid(kind);
}


async function ownerContext(
  deps: CardDeps,
  session: TokenSession,
): Promise<{ access: OwnerAccess } | HandlerResult> {
  if (session.purpose !== "session" || session.role !== "owner") return forbidden();
  const access = await deps.loadAccess(session.entityType, session.entityId);
  if (!access?.enabled) {
    return {
      status: 403,
      body: { ok: false, code: "disabled", error: "تعديل المالك متوقف." },
    };
  }
  if (access.sessionVersion !== session.sessionVersion) {
    return {
      status: 403,
      body: { ok: false, code: "session", error: "انتهت الجلسة. أعد الدخول." },
    };
  }
  return { access };
}

function isHandler(value: { access: OwnerAccess } | HandlerResult): value is HandlerResult {
  return "status" in value;
}

async function assertAdmin(
  deps: CardDeps,
  body: AccessBody,
  target: { type: EntityType; id: string },
  authorization: string | null,
): Promise<boolean> {
  if (body.token) {
    const session = await readToken(
      deps.tokenSecret,
      body.token,
      Math.floor(deps.now() / 1000),
    );
    return session?.role === "admin" &&
      session.purpose === "session" &&
      session.entityType === target.type &&
      session.entityId === target.id;
  }
  return deps.verifyAdminJwt(authorization);
}

async function issueCode(
  deps: CardDeps,
  access: OwnerAccess,
): Promise<{ access: OwnerAccess; code: string; expiresAt: number }> {
  const code = generateActivationCode();
  const expiresAt = deps.now() + ACTIVATION_TTL_MS;
  return {
    code,
    expiresAt,
    access: {
      ...access,
      activationCodeHash: await hashActivationCode(deps.tokenSecret, code),
      activationExpiresAt: expiresAt,
    },
  };
}

export async function handleDoctorCardAccess(
  body: AccessBody,
  deps: CardDeps,
  sourceIp: string | null,
  authorization: string | null,
): Promise<HandlerResult> {
  if (!deps.tokenSecret) return unconfigured();
  const target = resolveTarget(body);
  if (!target) {
    return { status: 400, body: { ok: false, code: "bad_request", error: "البطاقة غير معروفة." } };
  }

  if (body.action === "preview") {
    const access = await deps.loadAccess(target.type, target.id);
    const mode = accessMode(access);
    let waitSeconds = 0;
    if (sourceIp && mode !== "disabled") {
      const kind: AttemptKind = mode === "activate" ? "activation" : "password";
      const prev = await deps.loadAttempt(
        await deps.sourceHash(sourceIp),
        target.type,
        target.id,
        kind,
      );
      if (isLocked(prev, deps.now()) && prev?.lockedUntil) {
        waitSeconds = Math.max(1, Math.ceil((prev.lockedUntil - deps.now()) / 1000));
      }
    }
    return {
      status: 200,
      body: {
        ok: true,
        mode,
        wait_seconds: waitSeconds,
        error: waitSeconds > 0 && access
          ? waitMessage(deps.now(), deps.now() + waitSeconds * 1000)
          : undefined,
      },
    };
  }

  if (body.action === "verify_code") {
    if (!sourceIp) return unconfigured();
    const sourceHash = await deps.sourceHash(sourceIp);
    const prev = await deps.loadAttempt(sourceHash, target.type, target.id, "activation");
    if (isLocked(prev, deps.now()) && prev?.lockedUntil) {
      return locked(deps.now(), prev.lockedUntil);
    }
    const access = await deps.loadAccess(target.type, target.id);
    if (accessMode(access) !== "activate" || !access?.activationCodeHash) return invalid("activation");
    if (!access.activationExpiresAt || access.activationExpiresAt <= deps.now()) {
      return { status: 401, body: { ok: false, code: "expired", error: "انتهت صلاحية رمز التفعيل." } };
    }
    const given = await hashActivationCode(deps.tokenSecret, body.code ?? "");
    if (given !== access.activationCodeHash) {
      return recordFailure(deps, sourceHash, target.type, target.id, "activation", prev);
    }
    const signed = await signToken(
      deps.tokenSecret,
      {
        entityType: target.type,
        entityId: target.id,
        role: "owner",
        sessionVersion: access.sessionVersion,
        purpose: "activation",
        codeHash: access.activationCodeHash,
      },
      Math.floor(deps.now() / 1000),
      ACTIVATION_TOKEN_TTL_SEC,
    );
    return {
      status: 200,
      body: { ok: true, activation_token: signed.token, expires_at: signed.expiresAt },
    };
  }

  if (body.action === "complete_activation") {
    const format = validateNewPassword(body.new_password ?? "");
    if (format) return { status: 400, body: { ok: false, code: "bad_request", error: format } };
    const session = body.token
      ? await readToken(deps.tokenSecret, body.token, Math.floor(deps.now() / 1000))
      : null;
    if (
      !session ||
      session.purpose !== "activation" ||
      session.entityType !== target.type ||
      session.entityId !== target.id ||
      !session.codeHash
    ) {
      return forbidden();
    }
    const passwordHash = await hashPassword(
      body.new_password!.trim(),
      deps.hashIterations ?? PBKDF2_ITERATIONS,
    );
    const version = await deps.consumeActivation(
      target.type,
      target.id,
      session.codeHash,
      passwordHash,
      session.sessionVersion,
    );
    if (version == null) {
      return {
        status: 409,
        body: { ok: false, code: "consumed", error: "رمز التفعيل لم يعد صالحًا." },
      };
    }
    const signed = await signToken(
      deps.tokenSecret,
      {
        entityType: target.type,
        entityId: target.id,
        role: "owner",
        sessionVersion: version,
        purpose: "session",
      },
      Math.floor(deps.now() / 1000),
    );
    const access = await deps.loadAccess(target.type, target.id);
    return {
      status: 200,
      body: {
        ok: true,
        role: "owner",
        token: signed.token,
        expires_at: signed.expiresAt,
        permissions: access?.permissions ?? [],
      },
    };
  }

  if (body.action === "login") {
    if (!sourceIp) return unconfigured();
    const sourceHash = await deps.sourceHash(sourceIp);
    const prev = await deps.loadAttempt(sourceHash, target.type, target.id, "password");
    if (isLocked(prev, deps.now()) && prev?.lockedUntil) {
      return locked(deps.now(), prev.lockedUntil);
    }
    const password = body.password ?? "";
    if (!password.trim()) return invalid();
    const access = await deps.loadAccess(target.type, target.id);
    const ownerOk = access?.enabled === true && access.passwordHash
      ? await verifyPassword(access.passwordHash, password)
      : await verifyPassword(null, password);
    let adminOk = false;
    if (!ownerOk) adminOk = await deps.verifyAdminPassword(password);
    if (!ownerOk && !adminOk) {
      return recordFailure(deps, sourceHash, target.type, target.id, "password", prev);
    }
    await deps.clearAttempt(sourceHash, target.type, target.id, "password");
    const signed = await signToken(
      deps.tokenSecret,
      {
        entityType: target.type,
        entityId: target.id,
        role: adminOk ? "admin" : "owner",
        sessionVersion: adminOk ? 0 : (access?.sessionVersion ?? 0),
        purpose: "session",
      },
      Math.floor(deps.now() / 1000),
    );
    return {
      status: 200,
      body: {
        ok: true,
        role: adminOk ? "admin" : "owner",
        token: signed.token,
        expires_at: signed.expiresAt,
        permissions: adminOk ? OWNER_PERMISSIONS[target.type] : (access?.permissions ?? []),
      },
    };
  }

  if (body.action === "admin_configure") {
    if (!await assertAdmin(deps, body, target, authorization)) return forbidden();
    const current = (await deps.loadAccess(target.type, target.id)) ?? blankAccess();
    const enabled = body.enabled === true;
    let next: OwnerAccess = {
      ...current,
      enabled,
      permissions: cleanPermissions(target.type, body.permissions ?? current.permissions),
    };
    let issued: { code: string; expiresAt: number } | null = null;
    if (body.reset === true) {
      const issuedCode = await issueCode(deps, {
        ...next,
        enabled: true,
        passwordHash: null,
        sessionVersion: current.sessionVersion + 1,
      });
      next = issuedCode.access;
      issued = { code: issuedCode.code, expiresAt: issuedCode.expiresAt };
    } else if (!enabled) {
      next = {
        ...next,
        sessionVersion: current.sessionVersion + 1,
        activationCodeHash: null,
        activationExpiresAt: null,
      };
    } else if (!next.passwordHash) {
      const stillValid = body.reissue !== true && next.activationCodeHash &&
        next.activationExpiresAt != null &&
        next.activationExpiresAt > deps.now();
      if (!stillValid) {
        const issuedCode = await issueCode(deps, next);
        next = issuedCode.access;
        issued = { code: issuedCode.code, expiresAt: issuedCode.expiresAt };
      }
    }
    await deps.saveAccess(target.type, target.id, next);
    return {
      status: 200,
      body: {
        ok: true,
        mode: accessMode(next),
        permissions: next.permissions,
        activation_code: issued?.code,
        expires_at: issued ? Math.floor(issued.expiresAt / 1000) : undefined,
      },
    };
  }

  if (body.action === "admin_status") {
    if (!await assertAdmin(deps, body, target, authorization)) return forbidden();
    const access = await deps.loadAccess(target.type, target.id);
    const meta = target.type === "doctor" ? await deps.loadDoctorMeta(target.id) : null;
    return {
      status: 200,
      body: {
        ok: true,
        mode: accessMode(access),
        permissions: access?.permissions ?? [],
        code_expires_at: access?.activationExpiresAt
          ? Math.floor(access.activationExpiresAt / 1000)
          : null,
        is_active: meta?.is_active ?? true,
        display_order: meta?.display_order ?? 0,
      },
    };
  }

  if (body.action === "update") {
    const session = body.token
      ? await readToken(deps.tokenSecret, body.token, Math.floor(deps.now() / 1000))
      : null;
    if (!session || session.entityType !== target.type || session.entityId !== target.id) {
      return forbidden();
    }
    const fields = body.fields;
    if (!fields || typeof fields !== "object" || Array.isArray(fields)) return forbidden();
    if (session.role === "admin" && session.purpose === "session") {
      if (target.type !== "doctor") return forbidden();
      const accepted = acceptFields("admin", fields);
      if (!accepted.ok) return forbidden();
      const expected = expectedRevision(body);
      if (typeof expected !== "number") return expected;
      const revision = await deps.updateDoctor(target.id, accepted.patch, expected);
      if (revision == null) return conflict();
      return { status: 200, body: { ok: true, content_revision: revision } };
    }
    const owner = await ownerContext(deps, session);
    if (isHandler(owner)) return owner;
    if (target.type === "doctor") {
      const accepted = acceptFields("owner", fields);
      if (!accepted.ok) return forbidden();
      for (const key of Object.keys(accepted.patch)) {
        const perm = doctorPermission(key);
        if (!perm || !owner.access.permissions.includes(perm)) return forbidden();
      }
      const expected = expectedRevision(body);
      if (typeof expected !== "number") return expected;
      const revision = await deps.updateDoctor(target.id, accepted.patch, expected);
      if (revision == null) return conflict();
      return { status: 200, body: { ok: true, content_revision: revision } };
    }
    if (target.type === "lab") {
      const patch: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(fields)) {
        if (!LAB_OWNER_FIELDS.has(key) || typeof value !== "string") return forbidden();
        const perm = labPermission(key);
        if (!perm || !owner.access.permissions.includes(perm)) return forbidden();
        if (value.trim().length > 4000) return forbidden();
        patch[key] = value.trim();
      }
      if (Object.keys(patch).length === 0) return forbidden();
      const expected = expectedRevision(body);
      if (typeof expected !== "number") return expected;
      const revision = await deps.updateLab(target.id, patch, expected);
      if (revision == null) return conflict();
      return { status: 200, body: { ok: true, content_revision: revision } };
    }
    if (isDirectoryType(target.type)) {
      const patch = acceptCenterFields(fields, owner.access.permissions);
      if (!patch) return forbidden();
      if (
        target.type === "radiology" &&
        ("latitude" in patch || "longitude" in patch || "services" in patch)
      ) {
        return forbidden();
      }
      const expected = expectedRevision(body);
      if (typeof expected !== "number") return expected;
      const published = await deps.saveDirectoryEntity(
        target.type,
        target.id,
        patch,
        expected,
      );
      if (published === "missing") {
        return {
          status: 409,
          body: {
            ok: false,
            code: "unpublished",
            error: "هذي البطاقة غير منشورة في الدليل المشترك بعد. راجع الإدارة.",
          },
        };
      }
      if (published === "forbidden") return forbidden();
      if (published === "conflict") return conflict();
      return { status: 200, body: { ok: true, content_revision: expected + 1 } };
    }
    if (isServiceCenterType(target.type)) {
      const patch = acceptCenterFields(fields, owner.access.permissions);
      if (!patch) return forbidden();
      const expected = expectedRevision(body);
      if (typeof expected !== "number") return expected;
      const published = await deps.saveServiceCenter(target.id, patch, expected);
      if (published === "missing") {
        return {
          status: 409,
          body: {
            ok: false,
            code: "unpublished",
            error: "هذا المركز غير منشور في الدليل المشترك بعد. راجع الإدارة.",
          },
        };
      }
      if (published === "forbidden") return forbidden();
      if (published === "conflict") return conflict();
      return { status: 200, body: { ok: true, content_revision: expected + 1 } };
    }
    const patch: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(fields)) {
      if (key === "bundles") {
        if (!pharmacyCanTouchBundles(owner.access.permissions)) return forbidden();
        patch[key] = value;
        continue;
      }
      const perm = PHARMACY_FIELDS[key];
      if (!perm || !owner.access.permissions.includes(perm)) return forbidden();
      patch[key] = value;
    }
    if (Object.keys(patch).length === 0) return forbidden();
    if (pharmacyPatchHasPrivateImage(patch)) {
      return {
        status: 400,
        body: {
          ok: false,
          code: "bad_image",
          error: "ارفع الصورة من زر الصورة حتى تُنشر لكل الأجهزة.",
        },
      };
    }
    const expected = expectedRevision(body);
    if (typeof expected !== "number") return expected;
    const published = await deps.savePharmacySnapshot(
      target.id,
      patch,
      expected,
      owner.access.permissions,
    );
    if (published === "missing") {
      return {
        status: 409,
        body: {
          ok: false,
          code: "unpublished",
          error: "الكتالوج المشترك لهذه الصيدلية غير منشور بعد. راجع الإدارة.",
        },
      };
    }
    if (published === "forbidden") return forbidden();
    if (published === "conflict") return conflict();
    return { status: 200, body: { ok: true, patch, content_revision: expected + 1 } };
  }

  if (body.action === "upload_photo") {
    const session = body.token
      ? await readToken(deps.tokenSecret, body.token, Math.floor(deps.now() / 1000))
      : null;
    if (!session || session.entityType !== target.type || session.entityId !== target.id) {
      return forbidden();
    }
    const packageImage = body.package_image === true;
    const assetOnly = body.asset_only === true;
    const logoOnly = body.logo === true;
    if (session.role === "owner") {
      const owner = await ownerContext(deps, session);
      if (isHandler(owner)) return owner;
      const allowed = owner.access.permissions;
      if (packageImage) {
        if (!allowed.includes("packages")) return forbidden();
      } else if (target.type === "pharmacy" && assetOnly) {
        if (
          !allowed.includes("image") &&
          !allowed.includes("products") &&
          !allowed.includes("packages_add") &&
          !allowed.includes("packages_edit")
        ) {
          return forbidden();
        }
      } else if (!allowed.includes("image")) {
        return forbidden();
      }
    } else if (session.role !== "admin" || session.purpose !== "session") {
      return forbidden();
    }
    if (packageImage && target.type !== "lab") return forbidden();
    if (logoOnly && packageImage) return forbidden();
    if (assetOnly && !logoOnly && target.type !== "pharmacy") return forbidden();
    if (!body.image_base64) return badImage();
    let bytes: Uint8Array;
    try {
      bytes = decodeBase64(body.image_base64);
    } catch {
      return badImage();
    }
    const image = inspectImage(bytes);
    if (!image.ok) return badImage();
    if (logoOnly) {
      // مسار موحّد مع عميل الإدارة: {folder}/{entityId}/logos/{file}
      const root = target.type === "lab"
        ? "labs"
        : target.type === "pharmacy"
        ? "pharmacies"
        : isServiceCenterType(target.type)
        ? "service-centers"
        : isDirectoryType(target.type)
        ? directoryImageRoot(target.type)
        : "doctors";
      const folder = `${root}/${target.id}/logos`;
      const path = `${folder}/${crypto.randomUUID()}.${image.ext}`;
      if (!path.startsWith(`${folder}/`)) return badImage();
      const url = await deps.uploadImage(path, bytes, image.contentType);
      return { status: 200, body: { ok: true, image_url: url } };
    }
    const folder = packageImage
      ? `labs/${target.id}/packages`
      : target.type === "lab"
      ? `labs/${target.id}`
      : target.type === "pharmacy"
      ? `pharmacies/${target.id}`
      : isServiceCenterType(target.type)
      ? `service-centers/${target.id}`
      : isDirectoryType(target.type)
      ? `${directoryImageRoot(target.type)}/${target.id}`
      : `doctors/${target.id}`;
    const path = `${folder}/${crypto.randomUUID()}.${image.ext}`;
    if (!path.startsWith(`${folder}/`)) return badImage();
    if (!packageImage && !assetOnly) {
      const gate = expectedRevision(body);
      if (typeof gate !== "number") return gate;
    }
    const url = await deps.uploadImage(path, bytes, image.contentType);
    if (packageImage || assetOnly) {
      return { status: 200, body: { ok: true, image_url: url } };
    }
    const expected = expectedRevision(body);
    if (typeof expected !== "number") return expected;
    if (target.type === "lab") {
      const revision = await deps.updateLab(target.id, { image_url: url }, expected);
      if (revision == null) return conflict();
      return { status: 200, body: { ok: true, image_url: url, content_revision: revision } };
    }
    if (target.type === "pharmacy") {
      const published = await deps.savePharmacySnapshot(
        target.id,
        { imageUrl: url },
        expected,
      );
      if (published === "missing") {
        return {
          status: 409,
          body: {
            ok: false,
            code: "unpublished",
            error: "الكتالوج المشترك لهذه الصيدلية غير منشور بعد. راجع الإدارة.",
          },
        };
      }
      if (published === "forbidden") return forbidden();
      if (published === "conflict") return conflict();
      return {
        status: 200,
        body: { ok: true, image_url: url, content_revision: expected + 1 },
      };
    }
    if (isDirectoryType(target.type)) {
      const published = await deps.saveDirectoryEntity(
        target.type,
        target.id,
        { imageUrl: url },
        expected,
      );
      if (published === "missing") {
        return {
          status: 409,
          body: {
            ok: false,
            code: "unpublished",
            error: "هذي البطاقة غير منشورة في الدليل المشترك بعد. راجع الإدارة.",
          },
        };
      }
      if (published === "forbidden") return forbidden();
      if (published === "conflict") return conflict();
      return {
        status: 200,
        body: { ok: true, image_url: url, content_revision: expected + 1 },
      };
    }
    if (isServiceCenterType(target.type)) {
      const published = await deps.saveServiceCenter(
        target.id,
        { imageUrl: url },
        expected,
      );
      if (published === "missing") {
        return {
          status: 409,
          body: {
            ok: false,
            code: "unpublished",
            error: "هذا المركز غير منشور في الدليل المشترك بعد. راجع الإدارة.",
          },
        };
      }
      if (published === "forbidden") return forbidden();
      if (published === "conflict") return conflict();
      return {
        status: 200,
        body: { ok: true, image_url: url, content_revision: expected + 1 },
      };
    }
    const revision = await deps.updateDoctor(target.id, { image_url: url }, expected);
    if (revision == null) return conflict();
    return { status: 200, body: { ok: true, image_url: url, content_revision: revision } };
  }

  if (body.action === "upsert_package" || body.action === "delete_package") {
    if (target.type !== "lab") return forbidden();
    const session = body.token
      ? await readToken(deps.tokenSecret, body.token, Math.floor(deps.now() / 1000))
      : null;
    if (!session || session.entityId !== target.id || session.entityType !== "lab") {
      return forbidden();
    }
    if (session.role === "owner") {
      const owner = await ownerContext(deps, session);
      if (isHandler(owner)) return owner;
      if (!owner.access.permissions.includes("packages")) return forbidden();
    } else if (session.role !== "admin") {
      return forbidden();
    }
    if (body.action === "delete_package") {
      if (!body.package_id || !isUuid(body.package_id)) return forbidden();
      await deps.deleteLabPackage(target.id, body.package_id);
      return { status: 200, body: { ok: true } };
    }
    const raw = body.package;
    if (!raw || typeof raw !== "object") return forbidden();
    const patch: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(raw)) {
      if (key === "lab_id") {
        if (value !== target.id) return forbidden();
        continue;
      }
      if (!PACKAGE_FIELDS.has(key)) return forbidden();
      patch[key] = value;
    }
    patch.lab_id = target.id;
    const packageId = body.package_id && isUuid(body.package_id) ? body.package_id : null;
    const expected = packageId == null ? null : expectedRevision(body);
    if (typeof expected !== "number" && expected != null) return expected;
    const revision = await deps.upsertLabPackage(target.id, packageId, patch, expected);
    if (revision == null) return conflict();
    return { status: 200, body: { ok: true, content_revision: revision } };
  }

  if (body.action === "change_password") {
    const session = body.token
      ? await readToken(deps.tokenSecret, body.token, Math.floor(deps.now() / 1000))
      : null;
    if (!session) return forbidden();
    const owner = await ownerContext(deps, session);
    if (isHandler(owner)) return owner;
    if (session.entityType !== target.type || session.entityId !== target.id) return forbidden();
    if (!sourceIp) return unconfigured();
    const sourceHash = await deps.sourceHash(sourceIp);
    const prev = await deps.loadAttempt(sourceHash, target.type, target.id, "password");
    if (isLocked(prev, deps.now()) && prev?.lockedUntil) return locked(deps.now(), prev.lockedUntil);
    const format = validateNewPassword(body.new_password ?? "");
    if (format) return { status: 400, body: { ok: false, code: "bad_request", error: format } };
    const oldOk = await verifyPassword(owner.access.passwordHash, body.old_password ?? "");
    if (!oldOk) return recordFailure(deps, sourceHash, target.type, target.id, "password", prev);
    await deps.saveAccess(target.type, target.id, {
      ...owner.access,
      passwordHash: await hashPassword(
        body.new_password!.trim(),
        deps.hashIterations ?? PBKDF2_ITERATIONS,
      ),
      sessionVersion: owner.access.sessionVersion + 1,
    });
    await deps.clearAttempt(sourceHash, target.type, target.id, "password");
    return { status: 200, body: { ok: true } };
  }

  if (body.action === "delete") {
    if (target.type !== "doctor") return forbidden();
    if (!await assertAdmin(deps, body, target, authorization)) return forbidden();
    await deps.deleteDoctor(target.id);
    return { status: 200, body: { ok: true } };
  }

  return { status: 400, body: { ok: false, code: "bad_request", error: "طلب غير معروف." } };
}
