// Edge Function — NLU parse-only (Phase 1).
// المفتاح يبقى في Supabase Secrets. لا يُرجع جواباً طبياً للمستخدم.
//
// أسرار:
//   supabase secrets set AI_API_KEY=sk-... OPENAI_NLU_MODEL=gpt-4o-mini
//
// Flutter:
//   --dart-define=AI_EDGE_FUNCTION_URL=https://<project>.supabase.co/functions/v1/ai-assistant

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const NLU_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "schema_version",
    "intent",
    "continuation",
    "subject",
    "population",
    "age_years",
    "duration",
    "slots",
    "requested_action",
    "confidence",
  ],
  properties: {
    schema_version: { type: "integer", enum: [1] },
    intent: {
      type: "string",
      enum: [
        "clinical_continuation",
        "clinical_complaint",
        "care_direction",
        "doctor_search",
        "lab_search",
        "offer_search",
        "app_action",
        "unknown",
      ],
    },
    continuation: { type: "boolean" },
    subject: {
      type: "string",
      enum: ["self", "child", "other", "inherit", "unknown"],
    },
    population: { type: "string", enum: ["child", "adult", "unknown"] },
    age_years: { type: ["integer", "null"] },
    duration: {
      type: "object",
      additionalProperties: false,
      required: ["bucket"],
      properties: {
        bucket: {
          type: "string",
          enum: ["hours", "days", "weeks", "months", "unknown"],
        },
      },
    },
    slots: {
      type: "object",
      additionalProperties: false,
      required: ["cough", "fever", "breathlessness", "sputum", "hemoptysis"],
      properties: {
        cough: { type: "string", enum: ["present", "absent", "unknown"] },
        fever: { type: "string", enum: ["present", "absent", "unknown"] },
        breathlessness: {
          type: "string",
          enum: ["present", "absent", "unknown"],
        },
        sputum: { type: "string", enum: ["present", "absent", "unknown"] },
        hemoptysis: { type: "string", enum: ["present", "absent", "unknown"] },
      },
    },
    requested_action: {
      type: "string",
      enum: ["none", "care_direction", "call", "whatsapp", "show_profile", "unknown"],
    },
    confidence: {
      type: "object",
      additionalProperties: false,
      required: ["overall", "slots"],
      properties: {
        overall: { type: "number" },
        slots: {
          type: "object",
          additionalProperties: false,
          required: ["cough", "fever", "breathlessness", "sputum", "hemoptysis"],
          properties: {
            cough: { type: "number" },
            fever: { type: "number" },
            breathlessness: { type: "number" },
            sputum: { type: "number" },
            hemoptysis: { type: "number" },
          },
        },
      },
    },
  },
} as const;

const SYSTEM_PROMPT =
  "You are a linguistic parser for Iraqi/Arabic medical chat. " +
  "Return ONLY the JSON schema. Never diagnose, never choose a doctor, " +
  "never choose a care destination, never prescribe, never invent facts. " +
  "Fill a slot only if the CURRENT user message explicitly states it. " +
  "If a session already has population/age/duration, do not invent new ones. " +
  "Pronouns like عنده with an active child session → subject=inherit, continuation=true. " +
  "Iraqi ضيق بنفس / ضيق بالتنفس means breathlessness=present. " +
  "حرارة/حمى means fever=present. Unknown when not stated.";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const edgeLog = (msg: string) => console.log(`[NLU-EDGE] ${msg}`);
  edgeLog("request received");

  try {
    const body = await req.json();
    const mode = body?.mode ?? "nlu_parse";
    if (mode !== "nlu_parse") {
      edgeLog("failure: unsupported_mode");
      return json({ ok: false, fallback: true, reason: "unsupported_mode" });
    }

    const request = body?.request ?? {};
    const userMessage = String(request.user_message ?? "").slice(0, 500);
    const session = request.session ?? {};
    if (!userMessage.trim()) {
      edgeLog("failure: empty_message");
      return json({ ok: false, fallback: true, reason: "empty_message" });
    }

    const apiKey = Deno.env.get("AI_API_KEY") ?? "";
    const modelEnv = Deno.env.get("OPENAI_NLU_MODEL");
    const model = modelEnv ?? "gpt-4o-mini";
    edgeLog(
      `config key=${apiKey ? "present" : "missing"} model_env=${
        modelEnv ? "present" : "default"
      }`,
    );
    if (!apiKey) {
      edgeLog("fallback: missing_api_key");
      return json({
        ok: false,
        fallback: true,
        reason: "provider_unconfigured",
      });
    }

    const payload = {
      model,
      temperature: 0,
      max_tokens: 220,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "ghadeer_nlu_v1",
          strict: true,
          schema: NLU_SCHEMA,
        },
      },
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: JSON.stringify({
            user_message: userMessage,
            session: {
              active_pack: session.active_pack ?? "respiratory",
              continuation_expected: session.continuation_expected === true,
              population: session.population ?? "unknown",
              age_known: session.age_known === true,
              last_question_key: session.last_question_key ?? null,
              slots: session.slots ?? {},
              duration_bucket: session.duration_bucket ?? "unknown",
            },
          }),
        },
      ],
    };

    edgeLog("OpenAI request started");
    const openaiStarted = Date.now();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 6000);
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    }).finally(() => clearTimeout(timer));
    edgeLog(`OpenAI completed: ${Date.now() - openaiStarted}`);
    edgeLog(`OpenAI status: ${res.status}`);

    if (!res.ok) {
      const category = openaiSafeCategory(res.status);
      edgeLog(`fallback: ${category}`);
      return json({ ok: false, fallback: true, reason: "upstream_http" });
    }
    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      edgeLog("fallback: invalid_provider_json");
      return json({ ok: false, fallback: true, reason: "empty_model_output" });
    }
    let parse: unknown;
    try {
      parse = JSON.parse(content);
    } catch {
      edgeLog("fallback: invalid_provider_json");
      return json({ ok: false, fallback: true, reason: "nlu_failure" });
    }
    if ((parse as { schema_version?: unknown } | null)?.schema_version !== 1) {
      edgeLog("fallback: invalid_provider_json");
      return json({ ok: false, fallback: true, reason: "bad_schema" });
    }
    edgeLog("response returned");
    return json({ ok: true, parse });
  } catch (err) {
    const aborted = (err as { name?: string } | null)?.name === "AbortError";
    edgeLog(`fallback: ${aborted ? "timeout" : "unknown"}`);
    return json({ ok: false, fallback: true, reason: "nlu_failure" });
  }
});

function openaiSafeCategory(status: number): string {
  if (status === 401 || status === 403) return "authentication";
  if (status === 429) return "rate_limit";
  if (status === 400) return "bad_request";
  if (status === 404) return "model_not_found";
  if (status >= 500) return "provider_error";
  return "unknown";
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
