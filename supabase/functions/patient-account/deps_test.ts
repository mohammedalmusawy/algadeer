import { assertEquals } from "https://deno.land/std@0.224.0/assert/assert_equals.ts";
import { buildDeps } from "./deps.ts";

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status });
}

function withEnv(fn: () => Promise<void>): Promise<void> {
  Deno.env.set("SUPABASE_URL", "https://example.invalid");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-only");
  Deno.env.set("SUPABASE_ANON_KEY", "test-only");
  return fn();
}

Deno.test("Storage DELETE يرسل أسماء الملفات ويستبعد مالكًا آخر", async () => {
  await withEnv(async () => {
    const deps = buildDeps();
    const calls: unknown[] = [];
    globalThis.fetch = ((_, opts?: RequestInit) => {
      calls.push(JSON.parse(String(opts?.body ?? "{}")));
      return Promise.resolve(jsonResponse([]));
    }) as typeof fetch;
    await deps!.deleteStorage("user-a", [
      "user-a/file.png",
      "user-b/private.png",
    ]);
    assertEquals(calls, [{ prefixes: ["user-a/file.png"] }]);
  });
});

Deno.test("قائمة فارغة لا ترسل DELETE", async () => {
  await withEnv(async () => {
    const deps = buildDeps();
    globalThis.fetch = (() => {
      throw new Error("unexpected fetch");
    }) as typeof fetch;
    await deps!.deleteStorage("user-a", []);
  });
});

Deno.test("حذف التخزين يُقسَّم على 1000 اسم", async () => {
  await withEnv(async () => {
    const deps = buildDeps();
    const sizes: number[] = [];
    globalThis.fetch = ((_, opts?: RequestInit) => {
      const body = JSON.parse(String(opts?.body ?? "{}"));
      sizes.push((body.prefixes as string[]).length);
      return Promise.resolve(jsonResponse([]));
    }) as typeof fetch;
    await deps!.deleteStorage(
      "user-a",
      Array.from({ length: 2001 }, (_, i) => `user-a/${i}.png`),
    );
    assertEquals(sizes, [1000, 1000, 1]);
  });
});

Deno.test("قائمة التخزين تتصفح المجلدات المتداخلة", async () => {
  await withEnv(async () => {
    const deps = buildDeps();
    const calls: Array<[string, number]> = [];
    globalThis.fetch = ((_, opts?: RequestInit) => {
      const body = JSON.parse(String(opts?.body ?? "{}"));
      calls.push([body.prefix, body.offset]);
      if (body.prefix === "user-a/nested/") {
        return Promise.resolve(jsonResponse([{ id: "nested", name: "inner.png" }]));
      }
      if (body.offset === 0) {
        return Promise.resolve(
          jsonResponse(
            Array.from({ length: 1000 }, (_, i) => ({
              id: `id-${i}`,
              name: `${i}.png`,
            })),
          ),
        );
      }
      return Promise.resolve(
        jsonResponse([
          { id: "last", name: "last.png" },
          { id: null, name: "nested" },
        ]),
      );
    }) as typeof fetch;
    const paths = await deps!.listStoragePaths("user-a");
    assertEquals(paths.length, 1002);
    assertEquals(paths.includes("user-a/nested/inner.png"), true);
    assertEquals(calls, [
      ["user-a/", 0],
      ["user-a/", 1000],
      ["user-a/nested/", 0],
    ]);
  });
});

Deno.test("استجابة القائمة غير الصالحة تفشل قبل الحذف", async () => {
  await withEnv(async () => {
    const deps = buildDeps();
    globalThis.fetch = (() => Promise.resolve(jsonResponse({ bad: true }))) as typeof fetch;
    let failed = false;
    try {
      await deps!.listStoragePaths("user-a");
    } catch {
      failed = true;
    }
    assertEquals(failed, true);
  });
});
