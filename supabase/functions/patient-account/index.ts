// حذف حساب المريض: Storage API ثم الصفوف ثم auth.users (ومعها الجلسات).
// لا تُحذف storage.objects مباشرة من SQL.
// حساب الإدارة ممنوع. لا تُسجَّل مسارات أو بيانات صحية.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { handlePatientAccount } from "./policy.ts";
import { buildDeps } from "./deps.ts";

export { buildDeps } from "./deps.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
      error: "خدمة الحساب غير جاهزة. راجع إعداد المشروع.",
    });
  }
  let body: Record<string, unknown> = {};
  try {
    body = JSON.parse(await req.text() || "{}");
  } catch {
    return json(400, { ok: false, code: "bad_request", error: "طلب غير معروف." });
  }
  try {
    const result = await handlePatientAccount(
      body,
      deps,
      req.headers.get("Authorization"),
    );
    return json(result.status, result.body);
  } catch {
    return json(500, {
      ok: false,
      code: "bad_request",
      error: "تعذر إكمال الطلب. حاول لاحقًا.",
    });
  }
});
