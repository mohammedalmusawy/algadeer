// Edge Function — ai-assistant
// Provider API keys تبقى هنا فقط (Secrets في Supabase Dashboard).
//
// نشر:
//   supabase functions deploy ai-assistant
//   supabase secrets set AI_PROVIDER=openai AI_API_KEY=sk-...
//
// Flutter:
//   --dart-define=AI_EDGE_FUNCTION_URL=https://<project>.supabase.co/functions/v1/ai-assistant

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type AssistantBody = {
  mode?: "assistant_query" | "dynamic_message";
  query?: string;
  purpose?: string;
  context?: Record<string, unknown>;
  search_results?: Array<Record<string, unknown>>;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as AssistantBody;
    const mode = body.mode ?? "assistant_query";
    const provider = Deno.env.get("AI_PROVIDER") ?? "";
    const apiKey = Deno.env.get("AI_API_KEY") ?? "";

    // بدون مزود — رد آمن للاختبار (Text + Navigation pipeline).
    if (!provider || !apiKey) {
      const query = (body.query ?? body.purpose ?? "").trim();
      const hits = body.search_results?.length ?? 0;
      const answer =
        mode === "dynamic_message"
          ? "رسالة اليوم — المزود غير مفعّل بعد."
          : hits > 0
            ? `وجدت ${hits} نتيجة محلية لـ «${query}». اختر من القائمة للتوجيه الآمن.`
            : query
              ? `لم أجد نتائج محلية لـ «${query}». جرّب اسم طبيب أو اختصاص أو مختبر.`
              : "اكتب سؤالك أو ابحث عن طبيب أو مختبر.";

      return json({
        answer,
        provider_configured: false,
        structured: {
          intent: mode === "dynamic_message" ? "message" : "search",
          entity_type: null,
          urgency: "low",
          recommended_specialties: [],
          priority: [],
          reason: "مزود AI غير مفعّل — Structured Output جاهز للاستهلاك لاحقاً.",
          search_terms: query ? [query] : [],
          filters: { active_only: true },
          navigation: { direct_if_single_confident_match: true },
        },
      });
    }

    // TODO: ربط المزود الحقيقي (OpenAI / Anthropic / …) هنا فقط.
    const query = (body.query ?? "").trim();
    const systemPrompt =
      "أنت مساعد عيادة الغدير. ساعد في التوجيه لطبيب/مختبر فقط. لا تشخيص ولا وصفات.";

    const answer = await callProviderPlaceholder({
      provider,
      apiKey,
      systemPrompt,
      userMessage: query || JSON.stringify(body),
    });

    return json({
      answer,
      provider_configured: true,
      structured: {
        intent: "navigation",
        urgency: "low",
        recommended_specialties: [],
        priority: [],
        reason: "placeholder — Structured Output جاهز لربط Provider الحقيقي لاحقاً.",
        search_terms: query ? [query] : [],
      },
    });
  } catch (error) {
    return json(
      { error: `${error}`, answer: null },
      { status: 500 },
    );
  }
});

async function callProviderPlaceholder(args: {
  provider: string;
  apiKey: string;
  systemPrompt: string;
  userMessage: string;
}): Promise<string> {
  // استبدل هذا باستدعاء HTTP للمزود المختار.
  return `[${args.provider}] ${args.userMessage}`.slice(0, 500);
}

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}
