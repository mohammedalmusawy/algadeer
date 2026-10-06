export const defaultAdminEmail = "almusawyalmusawy90@gmail.com";

export type DeleteStep =
  | "list_storage"
  | "delete_storage"
  | "delete_rows"
  | "delete_user";

export type PatientAccountDeps = {
  now: () => number;
  adminEmail: string;
  readUser: (
    authorization: string | null,
  ) => Promise<{ id: string; email: string } | null>;
  listStoragePaths: (userId: string) => Promise<string[]>;
  deleteStorage: (userId: string, paths: string[]) => Promise<void>;
  deleteRows: (userId: string) => Promise<void>;
  deleteAuthUser: (userId: string) => Promise<void>;
};

export type HandlerResult = {
  status: number;
  body: Record<string, unknown>;
  steps: DeleteStep[];
};

function isAdminEmail(email: string, adminEmail: string): boolean {
  return email.trim().toLowerCase() === adminEmail.trim().toLowerCase();
}

function folderAllowed(userId: string, path: string): boolean {
  return path === userId || path.startsWith(`${userId}/`);
}

export function storageDeleteBody(
  userId: string,
  paths: string[],
): { prefixes: string[]; names: string[] } {
  const names = paths.filter((path) => folderAllowed(userId, path));
  return { prefixes: [`${userId}/`], names };
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  attempts = 3,
): Promise<T> {
  let last: unknown;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (error) {
      last = error;
    }
  }
  throw last;
}

export async function handlePatientAccount(
  body: Record<string, unknown>,
  deps: PatientAccountDeps,
  authorization: string | null,
): Promise<HandlerResult> {
  const steps: DeleteStep[] = [];
  if (body.action !== "delete_own") {
    return {
      status: 400,
      body: { ok: false, code: "bad_request", error: "طلب غير معروف." },
      steps,
    };
  }
  const user = await deps.readUser(authorization);
  if (!user) {
    return {
      status: 401,
      body: { ok: false, code: "not_authenticated", error: "سجّل الدخول أولاً." },
      steps,
    };
  }
  if (isAdminEmail(user.email, deps.adminEmail)) {
    return {
      status: 403,
      body: {
        ok: false,
        code: "admin_forbidden",
        error: "حساب الإدارة لا يحذف حساب مريض.",
      },
      steps,
    };
  }

  try {
    steps.push("list_storage");
    const listed = await withRetry(() => deps.listStoragePaths(user.id));
    const { names, prefixes } = storageDeleteBody(user.id, listed);
    if (prefixes.length === 0) {
      return {
        status: 400,
        body: { ok: false, code: "bad_request", error: "مسار التخزين غير مقبول." },
        steps,
      };
    }
    steps.push("delete_storage");
    await withRetry(() => deps.deleteStorage(user.id, names));
    steps.push("delete_rows");
    await withRetry(() => deps.deleteRows(user.id));
    steps.push("delete_user");
    await withRetry(() => deps.deleteAuthUser(user.id));
  } catch {
    return {
      status: 503,
      body: {
        ok: false,
        code: "retry_exhausted",
        error: "تعذر إكمال الحذف. حاول مرة أخرى.",
      },
      steps,
    };
  }
  return {
    status: 200,
    body: { ok: true },
    steps,
  };
}
