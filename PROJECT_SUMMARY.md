# ملخص حالة مشروع عيادة الغدير

> تاريخ الملخص: 2026-09-20 — الفرع `main` — آخر commit: `f81894a`
> المرجع الدائم لقواعد المشروع هو `CLAUDE.md`؛ هذا الملف صورة عن الحالة فقط.
>
> **كيف أُعدّ هذا الملخص:** من قراءة الكود والملفات و`git`، ومن تشغيل `flutter analyze` و`flutter test`.
> لم يُشغَّل التطبيق يدويًا على جهاز أو متصفح، لذلك تصنيف الميزة «مكتملة» يعني أن كودها موجود ومغطّى
> باختبارات، وليس أنني جرّبتها بصريًا. لم يُفحص أيضًا ما هو مطبَّق فعلًا على مشروع Supabase الحي.

---

## 1. نظرة عامة

تطبيق Flutter لدليل عيادة: أطباء، مختبرات (مع باقات وتحاليل)، مراكز أشعة، إعلانات، وإشعارات،
مع مساعد نصي/صوتي اسمه **Smart Brain** (الواجهة بالعربية RTL وباللهجة العراقية).

- الحجم: نحو **104 ألف سطر Dart** في `lib/`، و**98 ملف اختبار** في `test/`.
- الإصدار في `pubspec.yaml`: `1.0.0+1`.
- الأولوية للموبايل، مع منصات web وmacOS وغيرها موجودة في المشروع.

## 2. التقنيات المستخدمة

| الجانب | المستخدم |
|---|---|
| الإطار | Flutter 3 / Dart (`sdk: ^3.13.2`) و Material 3 (اللون الأساسي `#0FAFA3`) |
| الخلفية | Supabase عبر `supabase_flutter ^2.10.0` (Postgres + Auth + Storage) |
| دالة الذكاء الاصطناعي | Supabase Edge Function بـ Deno/TypeScript: `supabase/functions/ai-assistant/index.ts` (تحليل نية فقط، لا تشخّص) |
| الصوت | `flutter_tts` (نطق) و `speech_to_text` (استماع) وقناة أصلية لـ TTS العربي على macOS |
| الصور | `image_picker` و `image_background_remover` و `flutter_onnxruntime` (إزالة خلفية صورة الطبيب) |
| أخرى | `url_launcher` (اتصال/واتساب) و `share_plus` و `qr_flutter` و `app_links` (روابط عميقة) و `shared_preferences` و `http` |
| الاختبار | `flutter_test` و `fake_async` و `flutter_lints ^6.0.0` |
| النشر | Netlify للنسخة web (`netlify.toml`: النشر من `build/web` مع SPA fallback وترويسات cache) |
| الذاكرة والتخزين المحلي | مستودعات محلية (`local_*_repository.dart`) لملف الرفيق والصحة والمتابعات؛ لا يُرسل شيء منها إلى Supabase |

**إعدادات وقت البناء (`lib/core/app_config.dart`)**: `SUPABASE_URL` و`SUPABASE_ANON_KEY` (المفتاح العام فقط)،
و`AI_EDGE_FUNCTION_URL` (فارغ افتراضيًا = الذكاء الاصطناعي غير مفعّل)،
و`SMART_BRAIN_CLINICAL_ENABLED` (افتراضيًا `false`)، و`GHADEER_OFFICIAL_SPONSOR`.

## 3. الشاشات الموجودة

### شاشات المستخدم
| الشاشة | الملف |
|---|---|
| بوابة الدخول (`AppEntryGate`) | `lib/onboarding/app_entry_gate.dart` |
| إدخال اسم المستخدم لأول مرة | `lib/onboarding/user_name_onboarding_page.dart` |
| الرئيسية (تشمل الترحيب، الرائج، إعلان، الأقسام) وتحتها شريط سفلي: **الرئيسية / أطبائي / المزيد** | `lib/main.dart` (`HomePage`) |
| أطبائي (المفضلة) | `lib/main.dart` (`FavoritesPage`) |
| كل التخصصات | `lib/doctors/all_specialties_page.dart` |
| ملف الطبيب | `lib/doctors/doctor_profile_page.dart` |
| البحث الذكي / محادثة Smart Brain (نص وصوت) | `lib/search/smart_search_page.dart` |
| المختبرات | `lib/labs/labs_page.dart` |
| ملف المختبر | `lib/labs/lab_profile_page.dart` |
| باقات المختبرات وتفاصيل الباقة | `lib/labs/lab_packages_page.dart` و`lab_package_detail_page.dart` |
| اختيار التحاليل (ورقة سفلية) | `lib/labs/lab_pick_analyses_sheet.dart` |
| مراكز الأشعة وملف المركز | `lib/radiology/radiology_page.dart` و`radiology_profile_page.dart` |
| صندوق الإشعارات | `lib/doctors/notifications_inbox_page.dart` |
| الإعدادات | `lib/settings/settings_page.dart` |
| إعدادات المساعد الصوتي | `lib/voice/voice_settings_page.dart` |

### شاشات الإدارة (خلف تسجيل دخول الإدارة)
| الشاشة | الملف |
|---|---|
| تسجيل دخول الإدارة، لوحة الإدارة | `lib/main.dart` (`AdminLoginPage`, `AdminPage`) |
| إدارة الأطباء + نموذج الطبيب | `lib/main.dart` (`DoctorsAdminPage`, `DoctorAdminFormPage`) |
| إجازات الأطباء | `lib/doctors/doctor_absences_admin_page.dart` |
| الإحصائيات | `lib/doctors/app_stats_admin_page.dart` |
| إدارة الإشعارات | `lib/doctors/notifications_admin_page.dart` |
| المختبرات والعروض (مركز، مختبرات، باقات، تحاليل، نماذج) | `lib/labs/admin/` (6 ملفات) |
| مراكز الأشعة (قائمة + نموذج) | `lib/radiology/admin/` |
| الإعلانات (قائمة + نموذج حملة) | `lib/ads/admin/` |
| العبارة الديناميكية (رسالة اليوم) | `lib/services/dynamic_message_admin_page.dart` |
| تغيير كلمة مرور الإدارة | `lib/services/admin_password_change_page.dart` |
| اختبار AI + توجيه (شاشة تجريبية للمطور) | `lib/voice/assistant_integration_page.dart` |
| المساعد الصوتي (تجربة الصوت) | `lib/voice/voice_settings_page.dart` |

## 4. الميزات المكتملة

كلها موجودة في الكود، ومحكومة باختبارات ما لم يُذكر غير ذلك.

- **الأطباء:** قائمة، بحث، تخصصات، مفضلة، ملف كامل، تقييمات، إحصائيات تفاعل (زيارات/اتصال/واتساب)،
  إجازات وغياب، إزالة خلفية صورة الطبيب، حالة الحجز وأيام وساعات الدوام.
- **المختبرات:** مختبرات وباقات وتحاليل، صور افتراضية، مقارنة/عروض باقات، إحصائيات، وإدارة كاملة
  (مكتبة تحاليل كبيرة في `labs_analyses_library.sql`).
- **الأشعة:** مراكز مع صفحة ملف وإدارة.
- **الإعلانات:** حملات مع وقت ومدة وحد ظهور لكل مستخدم ومكان في الرئيسية.
- **الإشعارات:** صندوق وارد للمستخدم ومركز إدارة (جدولة، مسودات، تكرار). **بلا Push** — داخل التطبيق فقط.
- **العبارة الديناميكية/التمييز** على الرئيسية، وإحصائيات استخدام التطبيق.
- **الإدارة:** دخول بكلمة سر، قفل اللوحة، تغيير كلمة المرور، استرجاع كلمة المرور بالرابط.
- **Smart Brain (بحث وتنفيذ):**
  - فهم لهجة عراقية، تصحيح أخطاء الإملاء في أسماء الأطباء والمختبرات والتحاليل.
  - بحث بالتخصص أو الاسم، فتح الاتصال/واتساب بالصوت، أوامر تنقل داخل التطبيق.
  - استمرارية المحادثة (الإحالة إلى «هذا الدكتور» و«باقاته»)، توضيح الغموض، ومحادثة موجَّهة بخطوات.
  - سلوك وأخلاقيات المحادثة (`conduct/`) وهوية «الغدير» والمحادثة الاجتماعية.
- **الصوت:** نطق واستماع، اختيار صوت عربي، تحية بدء التشغيل، مقاطعة الكلام، دورة حياة الميكروفون.
- **حماية التكلفة:** حصص يومية/شهرية وkill switch لدالة `understand_turn` (انظر القسم 6 لحالة التطبيق).

## 5. طبقات Smart Brain المكتوبة لكن غير مفعّلة افتراضيًا

هذه مكتملة برمجيًا ومختبَرة، لكن `AppConfig.smartBrainClinicalEnabled = false`
(النطاق الحالي: مساعد بحث وتنفيذ فقط). تُفعَّل بـ `--dart-define=SMART_BRAIN_CLINICAL_ENABLED=true`.

- الحوار السريري وحِزم المعرفة (تنفسي، أسنان، عضلي هيكلي، سكري وضغط، حمل، مراهقين): `lib/clinical_knowledge/packs/`.
- التوجيه الصحي وأسئلة المتابعة والأعراض والسلامة الطبية والدعم النفسي والرعاية المزمنة والوقاية: `lib/health/`.
- الرفيق الشخصي وملفات العائلة والذاكرة والمتابعات وسياق اليوم والعافية والتخطيط: `lib/companion/` و`memory/` و`follow_up/` و`daily_context/` و`wellness/` و`wellbeing_planner/`.
- قواعد السلامة: المساعد لا يشخّص ولا يصف دواءً، وقواعد الأعلام الحمراء في `lib/health/safety/`.

## 6. الميزات الناقصة / غير المكتملة

- **`understand_turn` غير مربوط بالعميل:** الدالة جاهزة على الخادم فقط ولا يستدعيها أي كود Dart (قرار المالك: يبقى كذلك الآن). مخططها سريري (أعراض)، وهو خارج نطاق «بحث وتنفيذ» الحالي.
- **الذكاء الاصطناعي غير مفعّل افتراضيًا:** `AI_EDGE_FUNCTION_URL` فارغ، فالتطبيق يعمل بالمحلي فقط حتى تُمرَّر القيمة وتُنشر الدالة.
- **حصص AI:** `supabase/ai_usage_quota_schema.sql` ملف جديد لم يُتحقق أنه طُبِّق على Supabase. الدالة تعتمد عليه حسب تعليقاتها.
- **فحص بيانات التواجد:** `supabase/doctor_schedule_data_check.sql` (قراءة فقط) لم يُعرف إن نُفِّذ. جواب «هل الطبيب متواجد اليوم؟» يعتمد على جودة `working_days` و`working_hours`، وحيث تنقص يكون الجواب «لا معلومة مؤكدة».
- **إشعارات Push:** غير موجودة (مركز الإدارة يذكر ذلك صراحة).
- **ملف الرفيق على Supabase:** `personal_companion_profiles_future.sql` مؤجَّل بالاسم؛ الرفيق محلي فقط اليوم.
- **README:** ما زال قالب Flutter الافتراضي ولا يصف المشروع.
- **الإصدار:** `1.0.0+1`، ولا يوجد ما يدل على نشر على متجر التطبيقات (لم يُفحص).

## 7. المشاكل المعروفة

**نتيجة الفحص (نُفِّذ في هذه الجلسة بعد commits المرحلة 4A):**

- `flutter test`: **2089 اختبار، كلها نجحت.** يتضمن `smart_brain_v1_ui_smoke_test.dart` فحص قراءة فقط على Supabase الحي، فالنجاح يتطلب اتصالًا.
- `flutter analyze`: **63 ملاحظة: 0 أخطاء، 9 تحذيرات، والباقي `info`.**
  - التحذيرات التسعة المتبقية في `lib/` (imports غير مستخدمة، `unnecessary_cast` في خدمات الرفيق والمتابعات والصحة، حقل `disabled` غير مستخدم، متغير `saved` غير مستخدم). لم تُعالَج لأنها خارج نطاق الإصلاح المطلوب.
  - `info`: `prefer_initializing_formals` في `smart_brain_planner.dart` و`wellbeing_planner_coordinator.dart` و`voice_settings.dart`.
  - `info`: استخدام deprecated: `Radio.groupValue/onChanged` في `voice_settings_page.dart:148-163` و`anonKey` في `test/doctor_profile_name_layout_test.dart:15`.
- لم أُشغِّل `flutter build web --release`، فلا أعرف حالة البناء.

**دَين هندسي (من قراءة الحجم والبنية):**

- ملفات ضخمة صعبة التعديل: `smart_brain_planner.dart` (6,729 سطر)، `main.dart` (3,723)، `smart_search_page.dart` (2,272)، `conversation_context.dart` (1,452). كل شاشات الرئيسية والإدارة والأطباء داخل `main.dart`.
- Smart Brain حساس: تعديل طبقة قد يغيّر أخرى، وسلوكه مضبوط بعشرات اختبارات المراحل. المرحلة 4A أضافت إليه مسار «بحث وتنفيذ» (`_planScoped`) وعدّلته بنحو 370 سطرًا.
- `assistant_integration_page.dart` شاشة تجريبية ضمن لوحة الإدارة، وليست ميزة للمستخدم.
- `supabase/functions/ai-assistant/index.ts` تضخّم في المرحلة 4A (+728 سطرًا)، وتفتح CORS على `*` (مقبول لدالة parse-only، لكنه يستحق مراجعة قبل الإنتاج).
- مفتاح Supabase العام ورابط المشروع مكتوبان كقيم افتراضية في `app_config.dart`. هذا مسموح حسب `CLAUDE.md`، لكن يجب ألا تُضاف إليه أي أسرار.
- اسم الراعي الرسمي (`GHADEER_OFFICIAL_SPONSOR`) مكتوب قيمة افتراضية في الكود.
- لا يوجد CI (لا مجلد `.github/`)، ولم أجد اختبارات تكامل على جهاز حقيقي.

## 8. حالة git

- الفرع `main`؛ التاريخ: `9aafcb4` (الأول) ← `1737450` ← `7d7ac1d` ← `4509415` ← `ea648ec` (خط الأساس) ← `8f863d3` ← `fa54a0a` ← المرحلة 4A:
  - `Phase 4A Step 1` — إصلاح تحذيرات المحلل (TTS macOS + imports الاختبارات).
  - `Phase 4A Step 2` — مساعد بحث وتنفيذ: مُعدِّلات «متوفر/اليوم/الأكثر طلبًا» وسؤال التواجد.
  - `Phase 4A Step 3` — وضع `understand_turn` وحصص AI (Edge Function + SQL).
  - commit رابع لهذا الملف.
- لم يُنفَّذ أي push؛ الـ commits محلية فقط.

## 9. هيكل المجلدات

```
ghadeer_clinic/
├── CLAUDE.md, AGENTS.md          قواعد المشروع (AGENTS.md رابط إلى CLAUDE.md)
├── PROJECT_SUMMARY.md            هذا الملف
├── pubspec.yaml, analysis_options.yaml, netlify.toml, README.md
├── android/ ios/ macos/ linux/ windows/ web/   منصات Flutter
├── assets/                       branding, labs/defaults, radiology, packages
├── tool/                         مجلد فارغ حاليًا
├── supabase/
│   ├── *.sql                     27 ملف schema/seed/تنظيف (تُطبَّق يدويًا من المستخدم)
│   └── functions/ai-assistant/   Edge Function (Deno)
├── test/                         98 ملف اختبار مسطّح، الأسماء بحسب الميزة أو المرحلة
└── lib/
    ├── main.dart                 نقطة الدخول والرئيسية والإدارة الأساسية
    ├── core/                     app_config.dart
    ├── doctors/ labs/ radiology/ ads/       مجالات الميزات (صفحات + خدمات + admin/)
    ├── home/ widgets/ branding/ utils/ models/ services/ settings/ onboarding/ medical/
    ├── search/                   البحث الذكي، مطابقات الأسماء، search_refiner، conversation/
    ├── voice/                    المنسّق والصوت وTTS/STT
    │   ├── intent/               smart_brain_planner وحلّالات الأهداف
    │   ├── guided_conversation/ clarification/ conduct/
    ├── unified_brain/ nlu/ ai/   فهم المحادثة واستدعاء الـ Edge Function
    ├── clinical_knowledge/       (packs/) المعرفة السريرية
    ├── health/                   safety, guidance, understanding, chronic_care, preventive, ...
    ├── companion/ memory/ follow_up/ daily_context/ wellness/ wellbeing_planner/
```

## 10. قاعدة البيانات (Supabase)

ملفات SQL في `supabase/`، مرتّبة بحسب المجال:

- **الأطباء:** `doctor_profile_schema`, `doctor_gender_schema`, `doctor_absences_schema`, `doctor_ratings_schema`, `doctor_schedule_data_check` (فحص قراءة فقط).
- **المختبرات:** `labs_schema`, `lab_profile_schema`, `lab_stats_schema`, `package_images_schema`, `package_stats_schema`, `labs_analyses_library` (3,892 سطرًا)، `analyses_description_ar`, `analyses_popular_order_seed`.
- **الأشعة:** `radiology_centers_schema`.
- **الإعلانات والإشعارات والرسائل:** `ads_campaigns_schema`, `notifications_admin_schema`, `notifications_repeat_schema`, `dynamic_messages_schema`, `dynamic_messages_highlight_schema`.
- **الإحصائيات:** `app_stats_schema`, `app_stats_periods_schema`.
- **الأمان والتنظيف:** `security_harden_zero_impact`, `normalize_ghadeer_logo_urls`, `strip_logo_placeholders_from_text`, `cleanup_temp_logo_helpers`.
- **الذكاء الاصطناعي:** `ai_usage_quota_schema` (لم يُطبَّق على Supabase؛ يطبّقه المالك يدويًا).
- **مؤجَّل:** `personal_companion_profiles_future`.

لا يمكنني التحقق مما طُبِّق فعلًا على المشروع الحي؛ قواعد المشروع تمنع تشغيل SQL عليه من جهتي.

## 11. الخطوات المقترحة (للنقاش، بلا تنفيذ)

1. مراجعة الـ commits المحلية ثم قرار push من المستخدم.
2. تأكيد تطبيق `ai_usage_quota_schema.sql` قبل نشر الدالة أو تمرير `AI_EDGE_FUNCTION_URL`.
3. معالجة التحذيرات التسعة المتبقية في `lib/` بتغييرات صغيرة.
4. تحديث `README.md` ليصف المشروع.
5. لاحقًا، تقسيم `main.dart` بعد تثبيت الاختبارات، وليس كتعديل جانبي.
