import { assertEquals } from "https://deno.land/std@0.224.0/assert/assert_equals.ts";
import {
  defaultAdminEmail,
  handlePatientAccount,
  storageDeleteBody,
  type PatientAccountDeps,
} from "./policy.ts";

function box() {
  const deleted = {
    storage: [] as string[],
    rows: [] as string[],
    users: [] as string[],
    listed: ["user-a/file.png"] as string[],
  };
  const deps: PatientAccountDeps = {
    now: () => 1,
    adminEmail: defaultAdminEmail,
    readUser: async (authorization) => {
      if (authorization === "Bearer patient") {
        return { id: "user-a", email: "patient@example.com" };
      }
      if (authorization === "Bearer admin") {
        return { id: "admin-id", email: defaultAdminEmail };
      }
      return null;
    },
    listStoragePaths: async (userId) =>
      deleted.listed.filter((path) => path.startsWith(`${userId}/`)),
    deleteStorage: async (userId, paths) => {
      const body = storageDeleteBody(userId, paths);
      deleted.storage.push(...body.prefixes, ...body.names);
    },
    deleteRows: async (userId) => {
      deleted.rows.push(userId);
    },
    deleteAuthUser: async (userId) => {
      deleted.users.push(userId);
    },
  };
  return { deps, deleted };
}

Deno.test("حساب الإدارة لا يحذف حساب مريض", async () => {
  const { deps, deleted } = box();
  const result = await handlePatientAccount(
    { action: "delete_own" },
    deps,
    "Bearer admin",
  );
  assertEquals(result.status, 403);
  assertEquals(result.body.code, "admin_forbidden");
  assertEquals(deleted.storage.length, 0);
  assertEquals(deleted.users.length, 0);
});

Deno.test("الحذف يمر على Storage API قبل الصفوف والحساب", async () => {
  const { deps, deleted } = box();
  const result = await handlePatientAccount(
    { action: "delete_own" },
    deps,
    "Bearer patient",
  );
  assertEquals(result.status, 200);
  assertEquals(result.steps, [
    "list_storage",
    "delete_storage",
    "delete_rows",
    "delete_user",
  ]);
  assertEquals(deleted.storage.includes("user-a/"), true);
  assertEquals(deleted.storage.includes("user-a/file.png"), true);
  assertEquals(deleted.rows, ["user-a"]);
  assertEquals(deleted.users, ["user-a"]);
});

Deno.test("مسار تخزين خارج مجلد المالك يُستبعد", () => {
  const body = storageDeleteBody("user-a", [
    "user-a/ok.png",
    "user-b/stolen.png",
    "../etc/passwd",
  ]);
  assertEquals(body.prefixes, ["user-a/"]);
  assertEquals(body.names, ["user-a/ok.png"]);
});

Deno.test("فشل التخزين يعيد المحاولة ثم يتوقف قبل حذف الحساب", async () => {
  let storageCalls = 0;
  const { deps, deleted } = box();
  deps.deleteStorage = async () => {
    storageCalls += 1;
    throw new Error("storage down");
  };
  const result = await handlePatientAccount(
    { action: "delete_own" },
    deps,
    "Bearer patient",
  );
  assertEquals(result.status, 503);
  assertEquals(result.body.code, "retry_exhausted");
  assertEquals(storageCalls, 3);
  assertEquals(deleted.rows.length, 0);
  assertEquals(deleted.users.length, 0);
});
