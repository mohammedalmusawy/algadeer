// Edge Function — NLU parse-only.
// المفتاح يبقى في Supabase Secrets. لا يُرجع جواباً طبياً للمستخدم.
//
// الأوضاع (mode):
//   nlu_parse       — القديم (تنفسي فقط) — لم يتغيّر.
//   understand_turn — فهم الرسالة (Schema v2): نص مكتوب أو ناتج speech_to_text
//                     بنفس الشكل والمخرجات. parse-only: لا تشخيص ولا أسماء ولا أسعار.
//                     محمي بحصص (يومي لكل زائر/IP + شهري عام) وkill switch — انظر أسفل.
//
// أسرار حماية التكلفة (كلها اختيارية؛ الافتراضيات محافظة وليست «بلا حد»):
//   AI_UT_KILL_SWITCH            true|1|on|yes → يعطّل understand_turn فوراً (بلا OpenAI ولا DB)
//   AI_UT_VISITOR_DAILY_LIMIT    طلبات/يوم لكل visitor_key   (افتراضي 30)
//   AI_UT_IP_DAILY_LIMIT         طلبات/يوم لكل IP            (افتراضي 120)
//   AI_UT_MONTHLY_LIMIT          طلبات/شهر عامة              (افتراضي 20000)
//   AI_UT_MONTHLY_TOKEN_LIMIT    توكنز/شهر عامة، 0 = معطّل   (افتراضي 0)
//   AI_UT_HASH_SALT              ملح للـhash المخزَّن (اختياري)
// يتطلب تنفيذ supabase/ai_usage_quota_schema.sql. SUPABASE_URL و
// SUPABASE_SERVICE_ROLE_KEY تُحقنان تلقائياً في Edge Functions.
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
    if (mode === "understand_turn") {
      return await handleUnderstandTurn(body?.request ?? {}, edgeLog, req);
    }
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

// ───────────────────────── understand_turn (Schema v2) ─────────────────────────
// parse-only: يفهم الرسالة ولا يجيب. الكتابة والصوت (speech_to_text) يدخلان
// بنفس الشكل ويخرجان بنفس الـschema. لا تشخيص، لا أسماء أطباء/مختبرات كحقائق،
// لا أسعار. أسماء الكيانات «تلميحات» تُحلّ لاحقاً من بيانات Supabase فقط.

const UT_INTENTS = [
  "clinical_complaint",
  "clinical_continuation",
  "care_direction",
  "doctor_search",
  "lab_search",
  "analysis_search",
  "package_search",
  "offer_search",
  "app_action",
  "social",
  "unknown",
] as const;

// مفاتيح أعراض مغلقة (لا نص حر). other = عرض غير مدرج (بلا تسمية).
const UT_SYMPTOM_KEYS = [
  "cough",
  "fever",
  "breathlessness",
  "sputum",
  "hemoptysis",
  "chest_pain",
  "headache",
  "dizziness",
  "knee_pain",
  "joint_pain",
  "back_pain",
  "neck_pain",
  "abdominal_pain",
  "nausea",
  "vomiting",
  "diarrhea",
  "sore_throat",
  "runny_nose",
  "ear_pain",
  "eye_symptom",
  "toothache",
  "rash",
  "swelling",
  "fatigue",
  "urinary_symptom",
  "other",
] as const;

// نفس معرّفات SpecialtyCatalog في Flutter (lib/doctors/specialty_catalog.dart).
const UT_SPECIALTY_IDS = [
  "internal", "pediatrics", "obgyn", "ent", "ortho", "joints",
  "general_surgery", "ophthalmology", "dentistry", "dermatology",
  "cardiology", "neurology", "gastro", "urology", "nephrology",
  "endocrine", "rheumatology", "pulmonology", "oncology", "hematology",
  "psychiatry", "allergy", "infectious", "family", "gp", "neurosurgery",
  "cardiac_surgery", "pediatric_surgery", "urology_surgery", "plastic",
  "vascular", "anesthesia", "radiology", "ultrasound",
] as const;

const UT_STATUS = ["present", "absent", "unknown"] as const;
const UT_SEVERITY = ["mild", "moderate", "severe", "unknown"] as const;
const UT_BUCKET = ["hours", "days", "weeks", "months", "unknown"] as const;
const UT_SUBJECT = ["self", "child", "other", "inherit", "unknown"] as const;
const UT_POLARITY = ["affirmative", "negative", "mixed", "none"] as const;
const UT_ACTIONS = [
  "none",
  "care_direction",
  "call",
  "whatsapp",
  "show_profile",
  "share",
  "book",
  "location",
  "unknown",
] as const;
const UT_RED_KINDS = [
  "none",
  "breathing",
  "chest_pain",
  "neurological",
  "bleeding",
  "consciousness",
  "severe_pain",
  "child_fever",
  "pregnancy",
  "other",
] as const;
const UT_TOPICS = [
  "none",
  "respiratory",
  "msk",
  "dental",
  "chronic",
  "pregnancy",
  "adolescent",
  "clinical_other",
  "doctor_search",
  "lab_search",
  "package_search",
  "analysis_search",
] as const;
const UT_ENTITY_TYPES = [
  "none",
  "doctor",
  "lab",
  "package",
  "analysis",
] as const;
const UT_SOURCES = ["text", "speech"] as const;

const UT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "schema_version",
    "intent",
    "rewritten_query",
    "symptoms",
    "duration",
    "subject",
    "polarity",
    "requested_action",
    "specialty_candidates",
    "entity_hints",
    "confidence",
    "possible_red_flag",
  ],
  properties: {
    schema_version: { type: "integer", enum: [2] },
    intent: { type: "string", enum: [...UT_INTENTS] },
    rewritten_query: { type: "string" },
    symptoms: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["key", "status", "severity"],
        properties: {
          key: { type: "string", enum: [...UT_SYMPTOM_KEYS] },
          status: { type: "string", enum: [...UT_STATUS] },
          severity: { type: "string", enum: [...UT_SEVERITY] },
        },
      },
    },
    duration: {
      type: "object",
      additionalProperties: false,
      required: ["bucket", "value"],
      properties: {
        bucket: { type: "string", enum: [...UT_BUCKET] },
        value: { type: ["integer", "null"] },
      },
    },
    subject: { type: "string", enum: [...UT_SUBJECT] },
    polarity: { type: "string", enum: [...UT_POLARITY] },
    requested_action: { type: "string", enum: [...UT_ACTIONS] },
    specialty_candidates: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "confidence"],
        properties: {
          id: { type: "string", enum: [...UT_SPECIALTY_IDS] },
          confidence: { type: "number" },
        },
      },
    },
    entity_hints: {
      type: "object",
      additionalProperties: false,
      required: [
        "doctor_name",
        "lab_name",
        "analysis_name",
        "package_name",
        "specialty_text",
      ],
      properties: {
        doctor_name: { type: ["string", "null"] },
        lab_name: { type: ["string", "null"] },
        analysis_name: { type: ["string", "null"] },
        package_name: { type: ["string", "null"] },
        specialty_text: { type: ["string", "null"] },
      },
    },
    confidence: {
      type: "object",
      additionalProperties: false,
      required: ["overall", "intent", "symptoms"],
      properties: {
        overall: { type: "number" },
        intent: { type: "number" },
        symptoms: { type: "number" },
      },
    },
    possible_red_flag: {
      type: "object",
      additionalProperties: false,
      required: ["flag", "kind"],
      properties: {
        flag: { type: "boolean" },
        kind: { type: "string", enum: [...UT_RED_KINDS] },
      },
    },
  },
} as const;

const UT_SYSTEM_PROMPT =
  "You are a linguistic parser for Iraqi/Arabic chat of a clinic directory app. " +
  "Return ONLY the JSON schema. You do NOT answer the user. " +
  "Never diagnose, never name a disease as a conclusion, never recommend treatment or drugs. " +
  "Never output a doctor, lab, package or price unless the words appear in the CURRENT user message. " +
  "entity_hints are copied from the user's own words (null if absent); they are only hints. " +
  "Never invent numbers, prices or names. " +
  "rewritten_query: a short clean Arabic restatement using only what the user said " +
  "(fix dialect/typos, keep meaning, max ~25 words). If unsure, copy the message. " +
  "symptoms: only symptoms the CURRENT message states or clearly denies " +
  "(status=absent for denial like 'ماكو حرارة'); use key 'other' for unlisted ones. " +
  "severity only if stated (شديد/قوي/عالي=severe), else unknown. " +
  "duration: the time the user states (من يومين → days,2; شهر → months,1); unknown if not stated. " +
  "polarity: affirmative/negative when the message is mainly a yes/no answer " +
  "(ايوه/نعم/اي → affirmative; لا/كلا/ماكو → negative), mixed if both, else none. " +
  "subject: self, child (ابني/بنتي/طفل), other, inherit when a pronoun continues the session subject. " +
  "specialty_candidates: at most 3 catalog ids that a clinic directory could route this " +
  "complaint or request to, with confidence 0..1; empty if not applicable. This is routing only, not diagnosis. " +
  "requested_action: call/whatsapp/show_profile/share/book/location only when explicitly asked. " +
  "intent: doctor_search / lab_search / analysis_search (a lab test like ESR or السكر الصائم) / " +
  "package_search (checkup packages like فحص شامل) / offer_search / care_direction / " +
  "clinical_complaint / clinical_continuation / app_action / social / unknown. " +
  "possible_red_flag: flag=true only for words suggesting danger " +
  "(breathing difficulty, chest pain, fainting, heavy bleeding, sudden weakness, child with high fever); " +
  "you can only raise caution, never lower it. " +
  "The message may come from typing OR from speech-to-text: expect missing punctuation, " +
  "dialect spelling and misrecognized words; interpret leniently but never add facts. " +
  "Use the compact session only to resolve pronouns/short answers, never to add symptoms the user did not say now.";

const UT_MAX_MESSAGE = 500;
const UT_TIMEOUT_MS = 7000;

function utInEnum<T extends readonly string[]>(
  list: T,
  v: unknown,
  fallback: T[number],
): T[number] {
  return typeof v === "string" && (list as readonly string[]).includes(v)
    ? (v as T[number])
    : fallback;
}

function utClamp01(v: unknown): number {
  const n = typeof v === "number" && Number.isFinite(v) ? v : 0;
  return Math.round(Math.min(1, Math.max(0, n)) * 100) / 100;
}

// تطبيع عربي خفيف للمقارنة فقط (لا يُرسل لأحد).
function utNorm(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFKC")
    .replace(/[ً-ٰٟـ]/g, "")
    .replace(/[إأآٱ]/g, "ا")
    .replace(/[ىیي]/g, "ي")
    .replace(/ک/g, "ك")
    .replace(/ة/g, "ه")
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function utTokens(s: string): string[] {
  return utNorm(s)
    .split(" ")
    .filter((t) => t.length >= 2)
    .map((t) => (t.startsWith("ال") && t.length > 3 ? t.slice(2) : t));
}

// التلميح يُقبل فقط إن كانت كل كلماته موجودة في رسالة المستخدم (لا اختلاق).
function utGrounded(hint: unknown, msgTokens: string[]): string | null {
  if (typeof hint !== "string") return null;
  const clean = hint.trim().slice(0, 60);
  if (!clean) return null;
  const toks = utTokens(clean);
  if (toks.length === 0) return null;
  const ok = toks.every((t) =>
    msgTokens.some((m) =>
      m === t ||
      (m.length >= 3 && t.length >= 3 && (m.startsWith(t) || t.startsWith(m)))
    )
  );
  return ok ? clean : null;
}

function utNumbers(s: string): string[] {
  return utNorm(s).match(/\d+/g) ?? [];
}

// إخفاء أرقام الهاتف والبريد قبل الإرسال لمزوّد الذكاء (لا بيانات تعريفية).
function utRedact(s: string): string {
  return s
    .replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, "[email]")
    .replace(/(?:\+?[\d٠-٩][\d٠-٩\s\-]{6,}[\d٠-٩])/g, "[num]");
}

function utSanitizeSession(raw: unknown): Record<string, unknown> {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<
    string,
    unknown
  >;
  const known = Array.isArray(r.known_symptoms)
    ? r.known_symptoms
      .filter((k): k is string =>
        typeof k === "string" &&
        (UT_SYMPTOM_KEYS as readonly string[]).includes(k)
      )
      .slice(0, 8)
    : [];
  const q = typeof r.last_question_key === "string" &&
      /^[A-Za-z_]{1,40}$/.test(r.last_question_key)
    ? r.last_question_key
    : null;
  const count = typeof r.result_count === "number" &&
      Number.isFinite(r.result_count)
    ? Math.min(50, Math.max(0, Math.trunc(r.result_count)))
    : 0;
  return {
    active_topic: utInEnum(UT_TOPICS, r.active_topic, "none"),
    last_question_key: q,
    known_symptoms: known,
    duration_bucket: utInEnum(UT_BUCKET, r.duration_bucket, "unknown"),
    subject: utInEnum(UT_SUBJECT, r.subject, "unknown"),
    population: utInEnum(["child", "adult", "unknown"] as const, r.population, "unknown"),
    age_known: r.age_known === true,
    last_entity_type: utInEnum(UT_ENTITY_TYPES, r.last_entity_type, "none"),
    result_count: count,
  };
}

// تحقق وتقييد مخرجات النموذج. يُرجع null إن كان الشكل غير صالح.
function utSanitizeParse(raw: unknown, userMessage: string) {
  if (!raw || typeof raw !== "object") return null;
  const p = raw as Record<string, unknown>;
  if (p.schema_version !== 2) return null;

  const msgTokens = utTokens(userMessage);

  const intent = utInEnum(UT_INTENTS, p.intent, "unknown");

  // rewritten_query: قصير، ولا يحمل أرقاماً (أسعاراً) غير موجودة في الرسالة.
  let rewritten = typeof p.rewritten_query === "string"
    ? p.rewritten_query.replace(/\s+/g, " ").trim().slice(0, 160)
    : "";
  const msgNums = new Set(utNumbers(userMessage));
  if (!rewritten || utNumbers(rewritten).some((n) => !msgNums.has(n))) {
    rewritten = userMessage.replace(/\s+/g, " ").trim().slice(0, 160);
  }

  const seen = new Set<string>();
  const symptoms: { key: string; status: string; severity: string }[] = [];
  if (Array.isArray(p.symptoms)) {
    for (const it of p.symptoms) {
      if (!it || typeof it !== "object") continue;
      const o = it as Record<string, unknown>;
      const key = utInEnum(UT_SYMPTOM_KEYS, o.key, "other");
      if (key !== "other" && seen.has(key)) continue;
      seen.add(key);
      symptoms.push({
        key,
        status: utInEnum(UT_STATUS, o.status, "unknown"),
        severity: utInEnum(UT_SEVERITY, o.severity, "unknown"),
      });
      if (symptoms.length >= 6) break;
    }
  }

  const d = (p.duration && typeof p.duration === "object"
    ? p.duration
    : {}) as Record<string, unknown>;
  const bucket = utInEnum(UT_BUCKET, d.bucket, "unknown");
  let value: number | null = null;
  if (
    bucket !== "unknown" && typeof d.value === "number" &&
    Number.isInteger(d.value) && d.value >= 1 && d.value <= 365
  ) {
    value = d.value;
  }

  const specSeen = new Set<string>();
  const specialties: { id: string; confidence: number }[] = [];
  if (Array.isArray(p.specialty_candidates)) {
    const list = p.specialty_candidates
      .filter((x) => x && typeof x === "object")
      .map((x) => {
        const o = x as Record<string, unknown>;
        return {
          id: utInEnum(UT_SPECIALTY_IDS, o.id, "" as never) as string,
          confidence: utClamp01(o.confidence),
        };
      })
      .filter((x) => x.id && x.confidence >= 0.2)
      .sort((a, b) => b.confidence - a.confidence);
    for (const it of list) {
      if (specSeen.has(it.id)) continue;
      specSeen.add(it.id);
      specialties.push(it);
      if (specialties.length >= 3) break;
    }
  }

  const h = (p.entity_hints && typeof p.entity_hints === "object"
    ? p.entity_hints
    : {}) as Record<string, unknown>;
  const conf = (p.confidence && typeof p.confidence === "object"
    ? p.confidence
    : {}) as Record<string, unknown>;
  const rf = (p.possible_red_flag && typeof p.possible_red_flag === "object"
    ? p.possible_red_flag
    : {}) as Record<string, unknown>;
  const flag = rf.flag === true;

  return {
    schema_version: 2,
    intent,
    rewritten_query: rewritten,
    symptoms,
    duration: { bucket, value },
    subject: utInEnum(UT_SUBJECT, p.subject, "unknown"),
    polarity: utInEnum(UT_POLARITY, p.polarity, "none"),
    requested_action: utInEnum(UT_ACTIONS, p.requested_action, "none"),
    specialty_candidates: specialties,
    entity_hints: {
      doctor_name: utGrounded(h.doctor_name, msgTokens),
      lab_name: utGrounded(h.lab_name, msgTokens),
      analysis_name: utGrounded(h.analysis_name, msgTokens),
      package_name: utGrounded(h.package_name, msgTokens),
      specialty_text: utGrounded(h.specialty_text, msgTokens),
    },
    confidence: {
      overall: utClamp01(conf.overall),
      intent: utClamp01(conf.intent),
      symptoms: utClamp01(conf.symptoms),
    },
    possible_red_flag: {
      flag,
      kind: flag ? utInEnum(UT_RED_KINDS, rf.kind, "other") : "none",
    },
  };
}

// عائلة GPT-5 / o-series تستعمل max_completion_tokens وترفض temperature المخصّص؛
// النماذج الأقدم (مثل gpt-4o-mini) تبقى على max_tokens + temperature:0.
function utIsReasoningModel(model: string): boolean {
  return /^(gpt-5|o\d)/i.test(model.trim());
}

function utBuildPayload(
  model: string,
  reasoningFamily: boolean,
  messages: unknown[],
) {
  const base: Record<string, unknown> = {
    model,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "ghadeer_understand_turn_v2",
        strict: true,
        schema: UT_SCHEMA,
      },
    },
    messages,
  };
  if (reasoningFamily) {
    base.max_completion_tokens = 1200;
    const effort = Deno.env.get("OPENAI_NLU_REASONING_EFFORT");
    if (effort && /^[a-z]{3,12}$/.test(effort)) base.reasoning_effort = effort;
  } else {
    base.temperature = 0;
    base.max_tokens = 450;
  }
  return base;
}

// ───────────────────────── حماية التكلفة (understand_turn فقط) ─────────────────────────
// المتاح للنشر فقط بعد تنفيذ SQL. فشل مخزن الحصص = رفض (fail-closed): لا استدعاء OpenAI بلا عدّاد.

function utEnvInt(name: string, def: number, max: number): number {
  const raw = Deno.env.get(name);
  if (raw === undefined || raw.trim() === "") return def;
  const n = Number(raw);
  if (!Number.isFinite(n)) return def;
  return Math.min(max, Math.max(0, Math.trunc(n)));
}

function utKillSwitchOn(): boolean {
  return /^(1|true|on|yes|disabled)$/i.test(
    (Deno.env.get("AI_UT_KILL_SWITCH") ?? "").trim(),
  );
}

async function utHash(value: string): Promise<string> {
  const salt = Deno.env.get("AI_UT_HASH_SALT") ?? "ghadeer-ai-usage";
  const bytes = new TextEncoder().encode(`${salt}|${value}`);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 32);
}

function utClientIp(req: Request | undefined): string {
  const h = req?.headers;
  const raw = h?.get("cf-connecting-ip") ??
    (h?.get("x-forwarded-for") ?? "").split(",")[0] ?? "";
  const ip = raw.trim().slice(0, 64);
  return ip || "unknown";
}

async function utRpc(name: string, args: Record<string, unknown>) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("quota_store_unconfigured");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  try {
    const res = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(args),
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`quota_store_http_${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

type UtQuota = { ok: true } | { ok: false; reason: string };

async function utConsumeQuota(
  visitorKey: unknown,
  req: Request | undefined,
): Promise<UtQuota> {
  try {
    const visitorRaw = typeof visitorKey === "string" &&
        visitorKey.trim().length >= 8
      ? visitorKey.trim().slice(0, 100)
      : "anonymous";
    const out = await utRpc("ai_usage_consume", {
      p_visitor: await utHash(`v:${visitorRaw}`),
      p_ip: await utHash(`ip:${utClientIp(req)}`),
      p_visitor_day_limit: utEnvInt("AI_UT_VISITOR_DAILY_LIMIT", 30, 100000),
      p_ip_day_limit: utEnvInt("AI_UT_IP_DAILY_LIMIT", 120, 1000000),
      p_month_limit: utEnvInt("AI_UT_MONTHLY_LIMIT", 20000, 100000000),
      p_month_token_limit: utEnvInt("AI_UT_MONTHLY_TOKEN_LIMIT", 0, 2000000000),
    });
    if (out === "ok") return { ok: true };
    const known = ["visitor_daily", "ip_daily", "monthly", "monthly_tokens"];
    if (typeof out === "string" && known.includes(out)) {
      return { ok: false, reason: `quota_${out}` };
    }
    return { ok: false, reason: "quota_unavailable" };
  } catch {
    return { ok: false, reason: "quota_unavailable" };
  }
}

async function utRecordTokens(total: unknown): Promise<void> {
  if (typeof total !== "number" || !Number.isFinite(total) || total <= 0) return;
  try {
    await utRpc("ai_usage_add_tokens", { p_tokens: Math.trunc(total) });
  } catch {
    // best-effort فقط؛ الحد بعدد الطلبات يبقى ساري.
  }
}

async function handleUnderstandTurn(
  request: Record<string, unknown>,
  edgeLog: (m: string) => void,
  req?: Request,
): Promise<Response> {
  const fail = (reason: string) => {
    edgeLog(`understand_turn failure: ${reason}`);
    return json({
      ok: false,
      fallback: true,
      mode: "understand_turn",
      reason,
      ...(reason.startsWith("quota_") || reason === "kill_switch"
        ? { quota: true }
        : {}),
    });
  };
  try {
    // نفس المسار للنص المكتوب وللصوت: الفرق فقط input_source (يُسجَّل، لا يغيّر الـschema).
    const source = utInEnum(UT_SOURCES, request.input_source, "text");
    const userMessage = String(request.user_message ?? "").slice(0, UT_MAX_MESSAGE);
    if (!userMessage.trim()) return fail("empty_message");

    const apiKey = Deno.env.get("AI_API_KEY") ?? "";
    const modelEnv = Deno.env.get("OPENAI_NLU_MODEL");
    const model = modelEnv ?? "gpt-4o-mini";
    edgeLog(
      `understand_turn config key=${apiKey ? "present" : "missing"} model_env=${
        modelEnv ? "present" : "default"
      } source=${source}`,
    );
    if (!apiKey) return fail("provider_unconfigured");

    // حماية التكلفة: تحدث قبل أي استدعاء لـ OpenAI.
    if (utKillSwitchOn()) return fail("kill_switch");
    const quota = await utConsumeQuota(request.visitor_key, req);
    if (!quota.ok) return fail(quota.reason);

    const stt = typeof request.stt_confidence === "number"
      ? utClamp01(request.stt_confidence)
      : null;
    const messages = [
      { role: "system", content: UT_SYSTEM_PROMPT },
      {
        role: "user",
        content: JSON.stringify({
          user_message: utRedact(userMessage),
          input_source: source,
          ...(source === "speech" && stt !== null ? { stt_confidence: stt } : {}),
          session: utSanitizeSession(request.session),
        }),
      },
    ];

    const call = async (reasoningFamily: boolean) => {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), UT_TIMEOUT_MS);
      return await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(utBuildPayload(model, reasoningFamily, messages)),
        signal: controller.signal,
      }).finally(() => clearTimeout(timer));
    };

    const started = Date.now();
    let family = utIsReasoningModel(model);
    let res = await call(family);
    if (res.status === 400) {
      // اسم النموذج قد لا يطابق العائلة المتوقعة: أعد مرة واحدة بالمعاملات المقابلة
      // فقط إن كان الخطأ عن معامل غير مدعوم. لا نسجّل نص الخطأ.
      const errText = (await res.text()).toLowerCase();
      if (/max_tokens|max_completion_tokens|temperature|unsupported/.test(errText)) {
        family = !family;
        edgeLog("understand_turn retry with alternate token params");
        res = await call(family);
      }
    }
    edgeLog(
      `understand_turn OpenAI status=${res.status} ms=${Date.now() - started}`,
    );
    if (!res.ok) {
      edgeLog(`understand_turn upstream: ${openaiSafeCategory(res.status)}`);
      return fail("upstream_http");
    }

    const data = await res.json();
    const usage = data?.usage;
    await utRecordTokens(
      usage?.total_tokens ??
        (Number(usage?.prompt_tokens) || 0) +
          (Number(usage?.completion_tokens) || 0),
    );
    if (usage && typeof usage === "object") {
      edgeLog(
        `understand_turn tokens in=${usage.prompt_tokens ?? "?"} out=${
          usage.completion_tokens ?? "?"
        }`,
      );
    }
    const msg = data?.choices?.[0]?.message;
    if (msg?.refusal) return fail("model_refusal");
    const content = msg?.content;
    if (typeof content !== "string" || !content.trim()) {
      return fail("empty_model_output");
    }
    let raw: unknown;
    try {
      raw = JSON.parse(content);
    } catch {
      return fail("invalid_provider_json");
    }
    const parse = utSanitizeParse(raw, userMessage);
    if (!parse) return fail("bad_schema");
    return json({ ok: true, mode: "understand_turn", parse });
  } catch (err) {
    const aborted = (err as { name?: string } | null)?.name === "AbortError";
    return fail(aborted ? "timeout" : "understand_failure");
  }
}

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
