# PROJECT_CONTEXT.md — عيادة الغدير (Al-Ghadeer / Ghadeer Clinic)

> **Canonical persistent project memory.** Read this file first in every future AI/Cursor session before changing code.
>
> **How this document was built (2026-09-28):** from the live working tree + `git` + committed docs (`CLAUDE.md`, `PROJECT_SUMMARY.md`) + directory/code inspection of `lib/`, `test/`, `supabase/`, platforms, and config. **Not** from chat history.
>
> **Source of truth (layers — do not collapse them):**
> - **Git committed history** = authoritative record of **completed/committed milestones**.
> - **Current working tree** = authoritative record of **newer local uncommitted implementation**.
> - **`PROJECT_CONTEXT.md`** = canonical **handoff/index of both layers** (committed + dirty tree).
> - **Never discard or overwrite newer working-tree work** merely because committed HEAD is older.
> - If this file **disagrees** with actual Git/code, **inspect both layers** before updating the context.
>
> Related docs: `CLAUDE.md` / `AGENTS.md` (hard development rules), `PROJECT_SUMMARY.md` (snapshot dated 2026-09-20 around Phase 4A; **partially outdated** relative to the current dirty working tree).

---

## 1. PROJECT IDENTITY

| Field | Value |
|-------|--------|
| Arabic name | عيادة الغدير / منصة الغدير |
| English names | Ghadeer Clinic, Al-Ghadeer |
| Tagline (home UI) | «دليلك الصحي في الشطرة» |
| Package name (`pubspec.yaml`) | `ghadeer_clinic` |
| App version | `1.0.0+1` |
| Dart SDK | `^3.13.2` |
| Git remote | `origin` → `https://github.com/mohammedalmusawy/algadeer.git` |
| Current branch | `main` (tracks `origin/main`, up to date with remote **for committed commits**) |
| Committed HEAD | `9b443db06679343412bbfe602f5739e2ea2e8439` |
| HEAD message | `Phase 4A Step 5 - editable WhatsApp message template` |
| Author/date (HEAD) | Mohammed Almusawy — Sun Sep 20 16:03:44 2026 +0300 |
| Stable baseline (do not rewrite) | `ea648ec` — `Phase 3D Step 4 - follow-up regression fixes` (2026-09-20) |
| Other local branch | `cursor/phase2g-explicit-intent-switch` @ `7d7ac1d` |
| Stash present | `stash@{0}: On main: before-codex-test` |

**Target platforms (Flutter folders present):**

- **Primary:** mobile (Android + iOS) — Mobile First is the design reference
- Also present: `web/` (Netlify SPA), `macos/` (Arabic TTS channel), `linux/`, `windows/`

**Approx. size (working tree, 2026-09-28):**

- `lib/`: ~461 Dart files, ~124k lines
- `test/`: ~134 Dart files, ~46k lines
- Very large hubs: `smart_brain_planner.dart` (~9.5k lines), `main.dart` (~3.3k), `smart_search_page.dart` (~2.6k), `conversation_context.dart` (~1.9k)

**Critical identity note:** Committed HEAD is Phase 4A Step 5, but the **working tree is heavily dirty** with large uncommitted feature work (pharmacies, physio, supplies, Smart Brain M1–M7, home Phase 1, social links, entity PIN, etc.). Sessions must inspect `git status` — not only HEAD — before concluding “what exists.”

---

## 2. PRODUCT PURPOSE

### What it is

A Flutter clinic **directory + assistant** app for the Al-Ghadeer platform (Iraqi Arabic UI, RTL, Iraqi dialect). Users find and act on local health providers: doctors, labs (packages/analyses), radiology, pharmacies, physiotherapy, and medical supplies. The assistant (“Smart Brain” / local brain) is a **search-and-execute** helper: find entities, clarify, call, WhatsApp, open profiles — **not** a diagnosing doctor.

### Intended users

- Residents of الشطرة / local area seeking clinics and services
- Clinic staff / owner via hidden admin hub
- Per-entity managers via local PIN gates (lab packages, pharmacy bundles)

### Major product areas

1. Home shell + service grid + notifications + daily tip
2. Directory modules (doctors / labs / radiology / pharmacies / physio / supplies)
3. Smart Search conversation UI (text + voice)
4. Favorites (doctors primary; labs/radiology local)
5. Contact actions (call / WhatsApp / social / share / QR for doctors)
6. Admin CRUD + stats + ads + icons + dynamic messages
7. Intentionally gated clinical/companion brain (code preserved, default off)

### Local / cloud architecture

| Layer | Role |
|-------|------|
| **Client (Flutter)** | All UI; rule-based Smart Brain; STT/TTS; SharedPreferences for favorites, voice prefs, local catalogs, PINs |
| **Supabase** | Postgres + Auth + Storage for doctors, labs, packages, radiology, ads, notifications, stats, icons, social columns |
| **Edge Function** | `supabase/functions/ai-assistant` — optional NLU / `understand_turn`; **not required** for default app path |
| **Local-only catalogs (working tree)** | Pharmacies, physio, supplies — SharedPreferences + in-code seed catalogs (no Supabase tables in `lib/` for these) |
| **Clinical/companion memory** | Local repositories only when clinical path is enabled; `personal_companion_profiles_future.sql` is deferred |

Default product mode: **local brain + live/catalog data**, clinical AI off, Edge AI URL empty.

---

## 3. ARCHITECTURE

### Flutter / Dart structure

```
lib/
  main.dart              App entry, Home shell, bottom nav, many admin pages, favorites
  core/app_config.dart   dart-define feature flags + Supabase public config
  doctors/ labs/ radiology/ pharmacies/ physio/ supplies/ ads/
  search/                Smart Search UI + matchers + conversation widgets
  voice/                 Smart Brain planner, STT/TTS, clarification, conduct, intent/
  unified_brain/ nlu/ ai/ clinical_knowledge/ health/ companion/ memory/ follow_up/
  home/ branding/ widgets/ services/ models/ settings/ onboarding/ medical/ utils/
```

### State management

- **No** Provider / Riverpod / Bloc in `pubspec.yaml`
- Pattern: `StatefulWidget` + service singletons/classes + `SharedPreferences` + Supabase queries
- Conversation authority: in-memory `ConversationContext` on `SmartSearchPage` (not the chat widget list)

### Data / storage

| Kind | Mechanism |
|------|-----------|
| Remote entities | `supabase_flutter` `.from(table)` + optional Realtime (`doctors-live`) |
| Media | Storage bucket `clinic-media` |
| Local prefs | favorites, voice, WhatsApp template, PINs, local entity stores, ads frequency, icon cache |
| Companion/health local repos | Used when clinical paths run; not the default scoped path |

### Supabase integration

- Init via `AppConfig.supabaseUrl` / `supabaseAnonKey` (publishable only; overridable by `--dart-define`)
- Admin: Supabase Auth `signInWithPassword` with `kAdminEmail` in `lib/services/admin_password_change_page.dart`
- Schema changes: SQL files under `supabase/` applied **manually by the user** (agents must not run SQL against live)

### Important configuration / feature flags (`lib/core/app_config.dart`)

| Flag | Default | Effect |
|------|---------|--------|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Built-in publishable defaults | Backend connection |
| `AI_EDGE_FUNCTION_URL` | `''` (empty) | AI backend off → `isAiBackendConfigured == false` |
| `SMART_BRAIN_CLINICAL_ENABLED` | `false` | Scoped search/execute only; clinical/companion/`_planImpl` skipped |
| `GHADEER_OFFICIAL_SPONSOR` | Commercial default string | Sponsor display |

### Platform integrations

- `url_launcher` — tel / WhatsApp / maps
- `speech_to_text` / `flutter_tts` — voice
- `macos_arabic_tts_channel.dart` — macOS Arabic TTS
- `geolocator` — near-me for pharmacies / physio / supplies
- `image_picker` + `image_background_remover` + `flutter_onnxruntime` — doctor image processing
- `share_plus` / `qr_flutter` / `app_links` — doctor card share / deep links
- Netlify: publish `build/web`, SPA fallback (`netlify.toml`)

---

## 4. CURRENT USER-FACING MODULES

Status labels are based **only on repository evidence** in the working tree.

### Doctors — **IMPLEMENTED**

- Browse specialties → specialty list → profile
- Availability today from Supabase fields (`working_days`, `working_hours`, `booking_status`, absences); clinic clock = Baghdad UTC+3; never invents “present right now”
- Ratings, engagement stats, favorites, call/WhatsApp/share/QR
- Admin CRUD in `main.dart` + absences admin
- Key: `lib/doctors/`, `lib/models/doctor_item.dart`
- Data: Supabase `doctors`, `doctor_ratings`, `doctor_absences`, storage

### Specialties / categories — **IMPLEMENTED**

- `specialty_catalog.dart`, `all_specialties_page.dart`, `specialty_doctors_page.dart`
- Empty specialty may show «قريباً» when count is 0

### Labs — **IMPLEMENTED**

- List, profile, packages, package detail, analyses pick sheet, WhatsApp order message
- Favorites via `favoriteLabIds`
- Full admin hub under `lib/labs/admin/`
- Data: `labs`, `lab_packages`, `lab_package_analyses`, `analyses`, `package_templates`, `package_images` (optional tables graceful)

### Packages / tests / offers — **IMPLEMENTED** (labs)

- Package browsing, visibility/hide behavior covered by tests (`package_visibility_hide_test.dart`)
- Intelligence engines + speech helpers for packages/analyses exist in search/voice layers

### Radiology — **IMPLEMENTED**

- Centers list + profile + admin
- Favorites: `favoriteRadiologyIds`
- Data: `radiology_centers`

### Pharmacies — **PARTIAL**

- Full public UI + local admin + bundles + WhatsApp + near-me
- Shared rows live in `public.pharmacies` after an administrator publishes them (§14). Device prefs remain a fallback. Package management is the single «الباقات» draft path (2026-10-04).
- Profile still has «قريباً» for product filter / pharmacy offers
- Favorite heart on profile is **session-only** (not persisted)
- Wired into home grid + Smart Brain

### Physiotherapy — **PARTIAL**

- UI + local admin + near-me
- Local store `physio_local_v1` + catalog
- No Supabase backend; no favorites persistence found
- Smart Brain M4 coverage

### Medical supplies — **PARTIAL**

- Same local pattern as physio (`supplies_local_v1`)
- Smart Brain M4 + `supplies_catalog_test.dart`

### Booking — **PARTIAL / PLANNED**

- Doctor metadata: `booking_status` (`available` | `full` | `unavailable`, …), `show_booking_button`
- Profile booking button → guidance to call/WhatsApp, **no appointment API**
- Bottom tab **مواعيدي** → `ServiceComingSoonPage`
- Smart Brain `bookAppointment` → informational “no automatic booking” message

### Favorites — **IMPLEMENTED** (doctors); **PARTIAL** elsewhere

- Bottom tab المفضلة: doctors via `favoriteDoctorIds`
- Labs / radiology: separate SharedPreferences keys on their pages
- Pharmacy: ephemeral UI only
- `FavoritesPage` class in `main.dart` appears **LEGACY** (superseded by tab; not navigated to)

### Sharing / contact / WhatsApp — **IMPLEMENTED**

- `lib/utils/contact_launch.dart`, `entity_contact_actions.dart`, social sheet/icons
- Editable WhatsApp template (Phase 4A Step 5) in settings
- Doctor digital card: share + QR + deep links
- Voice/contact commands via `voice_contact_command.dart` + planner `prepareCall` / `prepareWhatsApp`
- Engagement RPCs for taps/views

### Social links — **IMPLEMENTED** (working tree)

- Model `entity_social_links.dart`; SQL `entity_social_links_schema.sql` (untracked) alters doctors/labs/radiology
- Pharmacies/physio/supplies carry social fields in local models / admin

### Ads — **IMPLEMENTED** (home placement; working tree 2026-10-04)

- Admin CRUD + activate toggle + optional inbox notify on activate
- Eligibility: `is_active` + UTC schedule (`starts_at`/`ends_at`; null end = no auto-expiry) + global impression cap + local per-user/day caps + renderable media
- `display_seconds` = slide auto-hide only (not campaign length)
- One eligible campaign shown per placement, highest `priority` first; badge label «إعلان»
- `HomeAdSlot` wired into Phase 1 home (after Ask banner); pull-to-refresh + admin save/toggle/delete bump `AdsCatalogRefresh` so an open home reloads
- Admin form placements `doctors`/`labs`/`radiology` exist in data model; **UI slot only wired for `home`**
- Ads are **not** mixed into Smart Search ranking; paid placement is the labeled home slot only
- Fake schedule/priority coverage: `test/ads_campaign_eligibility_test.dart` (no production campaign edits)

### Notifications — **IMPLEMENTED** (in-app only)

- Inbox + admin scheduling/drafts/repeat
- **No push** notifications

### Dynamic daily message / tip — **IMPLEMENTED**

- Home tip via `DynamicMessageService` + admin page

### App icons (slot icons) — **IMPLEMENTED** (working tree)

- `app_ui_icons` table schema (untracked SQL) + `AppIconsService` + admin page + `AppSlotIcon`

### Home Phase 1 shell — **IMPLEMENTED** (working tree)

- Header, search row, «اسأل الغدير», 6-service grid, health tip
- Bottom nav: رئيسية / بحث (opens Smart Search) / مواعيدي (coming soon) / المفضلة / حسابي
- Older `home_welcome_banner.dart` / trending section not driving current home composition

### Onboarding / settings / profile — **IMPLEMENTED**

- Name onboarding gate, settings (profile + voice + WhatsApp template)
- `UserProfileService` / companion profile fields when used

### Admin — **IMPLEMENTED** (see §9)

### Clinical / companion / wellness (user-facing when flag on) — **DISABLED by default / PRESERVED**

- Full code trees exist; product default = clinical off → users get scope message for medical/symptom chat

---

## 5. SMART BRAIN / LOCAL BRAIN

**Especially important.** Default product brain = **scoped local search-and-execute**. Clinical “full brain” is preserved behind a flag.

### Current architecture

Single planner entry: `SmartBrainPlanner.plan({query, context})` in `lib/voice/intent/smart_brain_planner.dart`.

```
Typed or Voice transcript
  → ConversationConduct (+ crisis gate, Ghadeer identity, social small-talk)
  → if clinicalEnabled: _planImpl (Unified Brain, packs, companion, guided, NLU…)
    else: _planScoped (search & execute)
  → decorate plan
  → SmartSearchPage._executeActionPlan (+ optional TTS if voice)
  → fallback only via SmartBrainFallbackPolicy (legacy orchestrator forbidden on this page)
```

**SmartSearchPage** constructs the planner with `clinicalEnabled: AppConfig.smartBrainClinicalEnabled` (default **false**). Direct planner construction in tests often passes `clinicalEnabled: false` explicitly; constructor default may be `true` for legacy test convenience — **UI uses AppConfig**.

### Intent parsing

- `RuleBasedIntentResolver` (`intent_resolver.dart`)
- Arabic normalization + Iraqi aliases (`ArabicTextUtils`, `VoiceContactCommand.canonicalizeAliases`)
- Priority includes: stop/repeat → out-of-scope early → corrections → pure ordinal `selectResult` → contact/entity intents → specialty/doctor → general/unknown
- **No hardcoded doctor names** in resolver; names resolved via matchers later

### Entity resolution

Per-type target resolvers: doctor, laboratory, radiology, pharmacy, physio, supply, analysis, package.

Sources typically: `explicitName` | `ordinal` (1-based; `-1` = last) | `selectedContext` | `unresolved` + clarification.

`EntityTargetResolver` disambiguates package vs analysis vs lab using action hints + `activeEntityType`.

### Contextual commands

- Pronouns / «هذا الدكتور» / return-to-entity via `ConversationReferenceResolver`
- Pending clarification, pending doctor/entity suggestions, pending yes/no actions
- `ResultContext` is the **typed** authority for list ordinals (PC-0.2); do not treat loose `lastResults` alone as authoritative

### Filtering (M3)

- `ResultSetRefiner` filters **current** `ResultContext` (WhatsApp-capable, female doctor, etc.) **without** a new platform search
- Wired early in `_planScoped` before consuming pending call/WhatsApp

### Ordinal references («الثاني», …)

- Pure ordinal utterances → `AssistantIntent.selectResult`
- Mixed phrases like «دكتور علي الثاني» must **not** be stolen by pure-ordinal path
- `_planSelect` uses `currentResultContext` first

### Live entity revalidation (M7.1)

- Before call/WhatsApp-style actions: re-fetch authoritative catalog by canonical ID (`_revalidateLiveResult` / `_withLiveEntity`)
- Fail-closed if entity disappeared or contact fields missing
- Covered by `test/live_entity_revalidation_parity_test.dart`

### Doctor / lab / pharmacy / physio / supply / radiology handling

| Entity | Intent examples | Lookup | Grounded actions |
|--------|-----------------|--------|------------------|
| Doctor | search, specialty, availability, call, WhatsApp | Supabase / injectable lookup | profile, call, WhatsApp, location |
| Lab | findLab, packages, analyses | Supabase | same |
| Radiology | findRadiology | Supabase | same |
| Pharmacy | findPharmacy | local store lookup | same |
| Physio | findPhysio | local store | same |
| Supply | findSupply | local store | same |

### Call and WhatsApp actions

- Plans: `AssistantActionKind.prepareCall` / `prepareWhatsApp`
- UI launches via contact helpers; TTS must not block call launch (regression tests exist)
- Platform grounding: require navigable entity + `canCall` / `canWhatsApp`; **do not infer WhatsApp from phone alone**

### Booking actions

- Informational only — `canExecute: false` + Iraqi message that booking is not automatic

### Favorites / share

- Intent path may clarify share-or-favorite rather than silently executing

### Health / clinical routing

- **Default off.** Symptom-like language → `_scopedSymptomRedirect` / scope message
- When `SMART_BRAIN_CLINICAL_ENABLED=true`: `_planImpl` unlocks clinical packs, health guidance, companion, guided conversation, Unified Brain arbitration, respiratory NLU overlay

### Safety boundaries

1. `GhadeerScopeGate` — refuse general knowledge / diagnosis asks / out-of-platform chat with polite Iraqi message listing platform domains
2. `PlatformGrounding` — no invented providers, phones, prices, or locations
3. Crisis emotional support gate runs even when clinical is off
4. Conduct/ethics layer (abuse) without overriding medical urgency when clinical on
5. Urgent health session can block commercial package intents (clinical path)
6. No client-side AI secrets; Edge AI optional and empty by default
7. Live revalidation before external contact actions

### AI / backend dependencies

| Piece | Status |
|-------|--------|
| Rule-based planner | **Primary path** |
| `NluClient` / `nlu_parse` | Optional; skipped when AI URL empty; used mainly for respiratory overlay in clinical path |
| `AiService` (`dynamic_message`, `assistant_query`) | Optional; modes may not match current Edge `index.ts` (which implements `nlu_parse` + `understand_turn`) |
| `understand_turn` | **Server-only** in Edge + SQL quotas; **not called from Dart** (intentional per `PROJECT_SUMMARY.md`) |

### Local-Only behavior

- Default: clinical off, AI URL empty, no LLM packages in `pubspec.yaml`
- Pharmacies/physio/supplies catalogs local
- Companion memory serialization from conversation context disabled for persistent memory (`allowsPersistentMemorySerialization => false` pattern in context)

### Feature flags (brain)

- `SMART_BRAIN_CLINICAL_ENABLED` (default false)
- `AI_EDGE_FUNCTION_URL` (default empty)
- Planner injectable lookups for tests (no live network required for unit corpora)

### Intentionally disabled / preserved clinical code

Keep unless user explicitly re-enables:

- `lib/clinical_knowledge/packs/*`
- `lib/health/**`
- `lib/companion/**`, `lib/memory/**`, `lib/follow_up/**`, `lib/daily_context/**`, `lib/wellness/**`, `lib/wellbeing_planner/**`
- `lib/unified_brain/**`, much of `lib/nlu/**`
- Pack feature toggles in models may hardcode `full*PackEnabled => false` for some packs

### Known limitations (brain)

- Booking not automatic
- Scoped mode does not triage symptoms
- Short common names without type cue stay in confirm band (`SmartBrainConfidencePolicy`)
- Unified catalog load fail-closed if sources unavailable
- Analysis/package may not share the same live-revalidation path as provider entities
- `SmartSearchService.search` is doctor/lab-centric; multi-entity grounded lists must pass `candidates` to avoid dropping pharmacy/physio/supply/radiology
- M6/M7 corpora encode expected ≥95% intent / ≥90% refuse metrics **inside those tests** — not a substitute for a fresh full-suite run after large edits

### Working-tree Smart Brain milestone labels (uncommitted test names)

These are **progress labels in the dirty tree**, not Git commits titled M1–M7:

| Label | Evidence |
|-------|----------|
| M1 | Pharmacy list candidates grounded; interrupt pending clarification |
| M2 | Confidence policy in name resolution (`smart_brain_confidence_wiring_test.dart`); planner comments |
| M3 | `ResultSetRefiner` / `smart_brain_result_refinement_test.dart` |
| M4 | Physio + supplies Iraqi intents |
| M5 | `UnifiedEntityDiscovery` + confidence execute/confirm |
| M6 / M6.5 | Iraqi corpus + regression repair |
| M7 / M7.1 | Corpus stress + live revalidation parity |

---

## 6. VOICE SYSTEM

### Speech recognition

- `speech_recognition_service.dart` + `voice_input_service.dart`
- Feeds **final transcript** into the same `SmartSearchPage._runSearch` as typed text (`QueryInputSource.voice`)
- Mic lifecycle / same-process permission / greeting regressions have dedicated tests
- Second-app launch path explicitly **permanently disabled** (deprecated API on recognition service)

### TTS

- `text_to_speech_service.dart`, `flutter_tts`, macOS `macos_arabic_tts_channel.dart`
- `VoiceResponseController` for broader spoken responses
- Interruption / call-not-blocked-by-TTS regressions exist
- Auto-play preference in `VoiceSettingsService` (`voice_auto_play_responses`)

### Arabic behavior

- Prefer Arabic device voices; migrate/clear legacy English voice identity keys (Samantha, en-US, …)
- Default assistant gender: **male** (`AssistantVoiceGender`)
- Iraqi phrasing throughout planner messages and scope gate
- `arabic_speech_numbers.dart` for spoken numbers

### Voice interaction flow

1. User taps mic on Smart Search / home entry
2. STT → transcript
3. `SmartBrainPlanner.plan`
4. Execute plan (results, clarification, dialer/WhatsApp prep)
5. Optional TTS of assistant message when input source is voice
6. Suggested action chips (`smart_brain_suggested_actions.dart`)

### Supported actions (via brain, not separate voice DSL)

Search entities, ordinal select, refine list, call, WhatsApp, open profile/location, stop speaking, repeat last response, show more, help, open «ملفي الصحي» / بطاقة المتابعة (gate + auth; no auto-share); booking = message only.

### Current voice configuration

- Settings UI: `voice_settings_page.dart`
- Storage: SharedPreferences gender + auto-play
- Startup greeting coordinators exist (`startup_greeting.dart`, `startup_voice_greeting_coordinator.dart`)

### Relationship: Voice ↔ Smart Brain

Voice is an **input/output modality**. Business logic lives in Smart Brain + `ConversationContext`. Smart Search UI is the executor/presenter. Do not reintroduce `AssistantOrchestrator` as the primary Smart Search path (`allowLegacyOrchestrator` must stay false there).

---

## 7. SEARCH SYSTEM

### Architecture

- **UI:** `smart_search_page.dart` (conversation + results)
- **Brain:** `SmartBrainPlanner` (authority for intent/actions)
- **Local search service:** `smart_search_service.dart` — documented as local/Supabase search **without AI**; used for doctor/lab-style search and fallbacks
- **Matchers:** doctor, laboratory, pharmacy, radiology, catalog, package, analysis name matchers + `arabic_text_utils.dart`
- **Refiner:** `search_refiner.dart` + `SearchModifiers` (availability / by-demand)
- **Navigation:** `smart_navigation.dart`, `medical_navigation_service.dart`

### Smart Search

- Chat models/widgets are **display**; session authority is `ConversationContext`
- Suggested actions builder for chips after results
- Fallback policy blocks legacy medical navigation / orchestrator; when clinical off, health-language firewall maps to scope messaging

### Entity catalogs

- Live Supabase for doctors/labs/radiology
- Local SharedPreferences catalogs for pharmacies/physio/supplies
- Injectable lookups on planner for tests and grounding

### Ranking / filtering

- Specialty search defaults toward **byDemand** inside specialty results in scoped mode
- Modifiers: متوفر / اليوم / الأكثر طلباً
- M3 result-set filters on current list only

### Live vs cached / local

- Doctors: live Supabase (+ realtime channel usage in app)
- Labs/packages: live Supabase with graceful optional tables
- Pharmacies/physio/supplies: device-local until a backend is added
- Icons: Supabase + prefs cache

### Fallback behavior

- `_runAuthoritativeSafeFallback` after unhandled plans
- Must not invent entities; prefer scope / controlled messages

### Known limitations

- General `SmartSearchService.search` does not fully cover all new entity types alone
- Near-me depends on geolocator permissions; pharmacy distance has a fallback origin constant for degraded cases
- README still Flutter template — not a product search guide

---

## 8. DATA / SUPABASE

### Important tables / entities inferred from code + SQL

**From client `.from(...)` / services (non-exhaustive but central):**

`doctors`, `doctor_ratings`, `doctor_absences`, `labs`, `lab_packages`, `lab_package_analyses`, `analyses`, `package_templates`, `package_images`, `radiology_centers`, `ad_campaigns`, `app_notifications`, `notification_settings`, `dynamic_messages`, `app_users`, `app_stat_events`, `app_ui_icons`

**Storage:** bucket `clinic-media`

**Edge/service-role oriented:** `ai_usage_counters` (+ RPC `ai_usage_consume`) — not a normal client table path

**Future / commented:** `personal_companion_profiles` in `personal_companion_profiles_future.sql`

### Public vs admin data flow

- Public: read catalogs, write engagement/stats via RPCs where defined, local favorites
- Admin: Supabase Auth session → CRUD on entities, notifications, ads, icons, dynamic messages
- Entity PIN (local prefs) is retired from public entry points. It was not an approved access setting, so owner editing stays off until an administrator enables it. Do not copy the PIN store for new secrets.
- Owner access (2026-10-02): doctor card 3 taps, laboratory and pharmacy cards 5 taps. Activation codes, permissions, and saves go through Edge Function `doctor-card-access` and `entity_owner_access`. The function is deployed on project `ployefiobsnqqahdwnkh`. The Flutter app itself is not published, and `main` is not merged. See §14.
- Pharmacies: shared table `public.pharmacies` exists on the live project. Visitors see it only after the administrator publishes the device copy. Physio/supplies remain device-local.

### Images

- Uploads to `clinic-media`
- Lab/radiology/package default assets under `assets/`
- Doctor background removal pipeline for admin imagery

### Live refresh / revalidation

- Doctors realtime channel
- Smart Brain M7.1 re-fetch before contact actions
- Pull-to-refresh patterns on list pages (module-specific)

### Offline / local

- SharedPreferences favorites and local entity modules
- Clinical companion local repos (when enabled)
- No full offline-first sync layer for Supabase entities

### Secrets

- **Do not** put service_role or AI API keys in client code
- Publishable Supabase URL/anon key may live in `app_config.dart` defaults (already the project pattern)
- Never commit `.env`, keystores, or `supabase/.temp/`
- This document intentionally does **not** duplicate credential values

---

## 9. ADMIN SYSTEM

### Hidden access

- **5× logo tap** on home → `AdminLoginPage` or unlocked `AdminPage` via `AdminLaunchSession`
- Password auth against Supabase; password change + recovery flows exist
- Session lock clears `AdminLaunchSession`

### Capabilities (implemented)

| Area | Capabilities |
|------|----------------|
| Doctors | Create/edit, booking flags, images, schedule fields, absences, reorder/list admin in `main.dart` |
| Labs | Hub: labs, packages, analyses/templates; forms; PIN setup |
| Radiology | List + form CRUD |
| Pharmacies | Local CRUD + lat/lng + bundles manage + PIN |
| Physio / Supplies | Local CRUD + social fields |
| Notifications | Schedule, drafts, repeat (in-app) |
| Ads | Campaign CRUD + frequency caps |
| Dynamic message | Admin editor |
| App icons | Slot → image URL |
| Voice / AI integration pages | Dev/test surfaces inside admin (`voice_settings_page`, `assistant_integration_page`) |
| Stats | `app_stats_admin_page.dart` |

### Visibility / booking controls

- Doctor `show_booking_button`, `booking_status`
- Package visibility/hide (tests + admin forms)
- Specialty empty state «قريباً»

### Image upload

- Doctor/lab/ads/icons via picker + storage; pharmacy fit-image helpers for local images

---

## 10. BUSINESS AND DOMAIN RULES

Durable rules found in code:

1. **Clinic timezone for “today”:** Baghdad UTC+3 (no DST handling) in `DoctorTodayAvailability` — not device local TZ.
2. **Availability honesty:** Never claim “present this minute”; only day/period from `working_hours` / leave ranges; unknown when data incomplete.
3. **Booking statuses:** at least `available`, `full`, `unavailable` drive UI states; button may show without creating appointments.
4. **No fake booking:** assistant and clinical packs must not invent appointment slots.
5. **WhatsApp template:** user-editable; used when composing outbound WhatsApp text (Phase 4A Step 5).
6. **WhatsApp capability:** explicit field — do not infer from phone.
7. **Scope lock:** assistant is platform-only (doctors, specialties, pharmacies, labs, packages, radiology, physio, supplies, in-app actions).
8. **Medical safety:** do not diagnose or prescribe; red-flag / safety engines preserved under `lib/health/safety/` for clinical mode.
9. **Iraqi localization:** RTL Arabic copy; dialect in assistant messages; specialty vocabulary in scope cues.
10. **Official sponsor:** single config value `GHADEER_OFFICIAL_SPONSOR`.
11. **Favorites:** doctor favorites are the primary cross-app favorites tab.
12. **Near-me:** geolocation optional; modules degrade with fallbacks rather than crashing.
13. **Entity PIN:** local device secret for labs/pharmacies only; forgot-PIN path routes toward WhatsApp admin support. Doctor cards do not use this store.
14. **Doctor card edit:** a doctor password edits only that card (photo, bio, services, schedule, booking phone/WhatsApp, booking status `available` / `walk_in_only` / `full`, and own password after the old one). Name, specialty, clinic address, hide, order, and delete stay with clinic admin. Admin password or the existing admin session can set/reset a doctor password. The password is handed to the doctor outside the app. Changes are public as soon as the trusted write succeeds; no approval queue.
15. **Ads frequency:** local cap store + server impression/click RPCs when ads are shown.
16. **Package/order messages:** dedicated builders for lab package and pharmacy bundle WhatsApp text (parity tests).

---

## 11. SECURITY / PRIVACY

### Secrets / configuration

- Client may contain **publishable** Supabase URL + anon/publishable key only
- AI keys only on Edge (Deno env), never in Flutter
- `DOCTOR_CARD_TOKEN_SECRET` is an Edge secret only. It signs doctor-card sessions. It must not be placed in the Flutter client, SharedPreferences, or logs. Doctor password hashes are not readable by `anon` or `authenticated`.
- `AI_EDGE_FUNCTION_URL` empty ⇒ no AI network calls from client helpers that check the flag

### Environment variables

- Flutter: `--dart-define=SUPABASE_URL|SUPABASE_ANON_KEY|AI_EDGE_FUNCTION_URL|SMART_BRAIN_CLINICAL_ENABLED|GHADEER_OFFICIAL_SPONSOR`
- Edge: OpenAI + quota/kill-switch envs for `understand_turn` (see function comments / `ai_usage_quota_schema.sql`)

### User data

- Profile name/birth/sex in prefs / companion local stores
- Favorites and entity PINs on device via SharedPreferences (and similar local stores)
- Clinical memory intended local-only (future cloud SQL explicitly deferred)
- **Local security clarification:** values in SharedPreferences — including local entity PINs, profile fields, and preferences — are **local application state**. Do **not** describe them as strong encrypted secret storage unless the implementation actually provides that protection. This document does not claim such protection.

### Never commit

- `.env`, `.env.*` (except `.env.example` if added)
- Android `key.properties`, `*.jks`, `*.keystore`
- `supabase/.temp/`
- Service role keys, AI API keys, real user PHI dumps

### External actions requiring revalidation

- Call / WhatsApp / open profile based on conversation memory → live catalog check (M7.1)
- Do not trust stale result cards alone after catalog edits/hides

---

## 12. TESTS AND QUALITY

### Important suites (flat `test/`; names encode domain/phase)

| Suite | What it covers |
|-------|----------------|
| `smart_brain_pipeline_test.dart`, `smart_brain_phase2_full_integration_test.dart`, `smart_brain_v1_release_gate_test.dart` | Core brain release/regression |
| `smart_brain_search_scope_test.dart`, `smart_brain_fallback_authority_test.dart`, `ghadeer_scope_gate_test.dart`, `smart_brain_platform_grounding_test.dart` | Scope + grounding |
| `smart_brain_master_m1_test.dart` … `smart_brain_m7_corpus_stress_test.dart`, `m65_regression_repair_test.dart` | Working-tree M1–M7 expansion |
| Fixtures JSON under `test/fixtures/` | Scope utterances, M6/M7 corpora, utterance corpus |
| `*_phase2*_test.dart`, `*_phase3*_test.dart` | Historical Smart Brain conversation phases |
| `whatsapp_contact_message_phase4a_test.dart` | Phase 4A WhatsApp template |
| Voice/TTS/mic: `tts_interruption_hotfix_test.dart`, `voice_settings_test.dart`, `startup_greeting_test.dart`, `mic_lifecycle_greeting_regression_test.dart`, `voice_turn_hotfix_test.dart`, `voice_call_launch_not_blocked_by_tts_test.dart` | Voice reliability |
| Clinical/companion/safety (many `*_clinical_*`, `personal_companion_*`, `medical_safety_*`) | Preserved clinical stack |
| UI: `responsive_home_layout_test.dart`, `bottom_nav_body_height_test.dart`, `doctor_profile_name_layout_test.dart`, `smart_brain_conversation_ui_test.dart` | Layout / RTL |
| Pharmacy/lab/radiology WhatsApp parity + near-me + supplies catalog | New directory modules |
| `live_entity_revalidation_parity_test.dart` | M7.1 contact safety |
| `entity_access_pin_service_test.dart`, `app_icon_slots_test.dart`, `entity_social_links_test.dart` | Cross-cutting WT features |

### Historical pass counts (**historical — verifiable artifact only**)

These figures are **historical**. They describe a past run recorded in committed `PROJECT_SUMMARY.md` (prepared around Phase 4A, document header references `f81894a`). They are **not** a current PASS count for HEAD or the dirty working tree.

- `flutter test`: **2089 tests, all passed** (historical; includes a smoke test that needs live Supabase network)
- `flutter analyze`: **63 issues: 0 errors, 9 warnings, rest info** (historical)

**Not verified in the session that wrote this PROJECT_CONTEXT.md:** current dirty working tree full `flutter test` / `flutter analyze` results. `test/tmp_m71_full_out.txt` contains sandbox errors only — **no trustworthy pass count**.

### Test result recording rule

- Historical pass counts must **always** be labeled **historical**.
- A **new** pass count may be recorded in `PROJECT_CONTEXT.md` **only** after the corresponding suite was **actually executed successfully** against the relevant current tree/commit.
- **Never infer** a current PASS count from old reports, test file presence, corpus expectations (e.g. M6/M7 ≥95%/≥90% inside fixtures), or previous milestones.

### Coverage gaps (evidence-based)

- No `.github/` CI workflows found
- README is still Flutter template
- Ads public home wiring missing
- Pharmacies/physio/supplies lack Supabase sync tests (local only)
- مواعيدي / real booking flow untested because unimplemented
- Edge `understand_turn` unused by Dart client
- Full device/manual E2E not encoded as automated suite
- Some clinical packs mark `full*PackEnabled => false`

---

## 13. COMPLETED MILESTONES (from Git history)

Reliable **committed** milestones on `main` (newest first):

| Commit | Message |
|--------|---------|
| `9b443db` | Phase 4A Step 5 - editable WhatsApp message template |
| `922bb5c` | Phase 4A Step 4 - add PROJECT_SUMMARY.md |
| `f81894a` | Phase 4A Step 3 - AI understand_turn with usage quotas |
| `a6d412b` | Phase 4A Step 2 - scoped search assistant: availability and demand modifiers |
| `7236ae6` | Phase 4A Step 1 - fix analyzer warnings |
| `fa54a0a` | Fix Supabase name columns and remove trending rank badge |
| `8f863d3` | Project workflow instructions |
| `ea648ec` | Phase 3D Step 4 - follow-up regression fixes (**baseline**) |
| `4509415` | Phase 3D Step 4 - stable baseline |
| `7d7ac1d` | Save complete Ghadeer Smart Brain V1 work through Phase 2G |
| `1737450` | Add Phase 2G explicit service intent switch from clinical flow |
| `9aafcb4` | Initial commit: Ghadeer Clinic Flutter app |

**Do not invent** milestone names for uncommitted work. Working-tree Smart Brain M1–M7 labels exist in tests/code comments only (§5).

---

## 14. CURRENT VERIFIED STATE

### Committed HEAD (`9b443db`)

- Product through **Phase 4A Step 5** on `main`, synced with `origin/main` for commits
- Scoped Smart Brain (clinical default off), WhatsApp editable template, doctors/labs/radiology/ads/notifications core
- AI Edge `understand_turn` + quota SQL **committed** but client still local-first

### Working tree (2026-09-28 inspection) — **ahead of HEAD, uncommitted**

Large dirty/untracked expansion including:

- Home Phase 1 UI + coming-soon appointments tab
- Pharmacies / physio / supplies modules (local data)
- Smart Brain multi-entity expansion (scope gate, platform grounding, unified discovery, confidence, M1–M7 tests/fixtures)
- Entity social links, contact row widgets, speak button, PIN gates, app icon slots
- Many modified voice/search/planner files and parity tests
- Untracked SQL: `app_ui_icons_schema.sql`, `entity_social_links_schema.sql`, `cleanup_duplicate_sabah_omari.sql`

**Verification status of this dirty tree:** architecture and module presence confirmed by code inspection; **full test suite not re-run** for this document. Treat uncommitted work as **implemented in the tree but not yet a Git milestone**.

### Owner access for doctors, laboratories, and pharmacies (2026-10-02, function deployed, app not published, not merged)

Gestures only open a dialog: 3 taps on a doctor card, 5 taps on a laboratory or pharmacy card. Ordinary opening is delayed until the tap window ends. Call, WhatsApp, and favorite controls stay immediate.

Trusted path: `supabase/functions/doctor-card-access` + `supabase/doctor_card_access_schema.sql` (`entity_owner_access`, `entity_owner_attempts`). Owner editing is off until an administrator enables that entity. Local PIN values are not migrated.

- First enable issues a random activation code, shown once to the signed-in administrator with a copy button. It is bound to that entity, expires after 2 hours, and is single-use. A replacement or reset invalidates the previous code. The code is consumed only when the new password is saved.
- After activation the owner signs in with a password only. Five failures of a password or a code lock that source for 5 minutes, with the remaining wait in Arabic. Another source is not locked.
- Administrator controls sit in the existing editors: doctor form in `lib/main.dart`, laboratory form, and pharmacy edit page. Reset invalidates the password, code, and owner sessions, then issues a new code. The old password is never shown.
- The existing administrator password still opens the entity dialog, checked by Supabase Auth on the function. It is not embedded in the client.
- Owner saves publish immediately, but only for the permissions the administrator checked. Name, specialty, address, deletion, visibility, order, and access management stay administrator-only. A direct request with a forbidden field is rejected.
- Laboratory package content, prices, tests, and visibility can be saved by an owner who has the packages permission. Display order, featured, and home placement stay administrator-only.
- Pharmacy public catalog is `public.pharmacies`. The schema is applied on the live project. Owner patches merge into `profile` only after that row exists. Device prefs stay as a fallback and are not deleted. Admin publishes them with «نشر النسخة المحفوظة على هذا الجهاز». A local write does not replace a published row for visitors. See the pharmacy persistence note below.
- Disabling access or changing permissions is checked again on the next save, including a session that was already open.

**Live setup on project `ployefiobsnqqahdwnkh` (2026-10-02):**

1. `supabase/doctor_card_access_schema.sql` — the SQL editor run did not leave `entity_owner_access` or `entity_owner_attempts` in the database. Saving owner permissions then returned HTTP 500 `PGRST205` (table absent from the API schema cache) and the app showed «تعذر إكمال الطلب. حاول لاحقًا.». The same file was applied once through the linked project after that check. `pharmacies_public_schema.sql` and `entity_content_revision.sql` were not run again. A test row was deleted afterwards.
2. `supabase/pharmacies_public_schema.sql` — applied. The in-app button «نشر النسخة المحفوظة على هذا الجهاز» is still the step that fills the empty table.
3. `supabase/entity_content_revision.sql` — applied after the pharmacies table existed. Not rerun.
4. `DOCTOR_CARD_TOKEN_SECRET` was created once. Its value is not recorded in this file. Do not set it again unless the current tokens must be invalidated.
5. `supabase functions deploy doctor-card-access` — deployed on `ployefiobsnqqahdwnkh` and redeployed after the access tables existed. The signed-in administrator session matched `is_clinic_admin()`. `admin_status` returned 200. `admin_configure` for a temporary entity returned 200 with the requested permission, then that row was deleted. `DOCTOR_CARD_TOKEN_SECRET` was left in place.
6. Hosted `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_ANON_KEY` were already present and were left unchanged. `CLINIC_ADMIN_EMAIL` was not set; the function keeps the email in `is_clinic_admin()`.

The Flutter web/mobile build is not published, and `main` is not merged. Manual card checks still use the local app.

**Manual acceptance still open:** tap the live cards, enable one entity, copy the code, activate, fail five times, reset from the admin editor, change a permission while an editor is open, and upload an allowed image. Do this after the SQL and function are deployed.

**Verification run on 2026-10-02 (local, not production):**

- `deno test supabase/functions/doctor-card-access/policy_test.ts` — 16 passed, including both stale-save orders for doctors, pharmacies, laboratories, and packages. `deno check` on `index.ts` passed. Password change still requires the current password (existing test in that file).
- `flutter test test/pharmacy_shared_catalog_test.dart` — 2 passed. After a successful shared fetch, a hidden or removed pharmacy is not restored from device prefs or the bundled catalog. Before that first fetch, local then bundled fallback still applies. An unpublished local-only pharmacy stays available to admin.
- `flutter test test/doctor_card_access_test.dart` — 6 passed (3-tap and 5-tap counters, single tap still opens, triple tap does not, favorite and list drag do not open).
- `flutter analyze` on the touched Dart files — no new issues. `main.dart` still reports its older infos (unused import, async context, deprecated dropdown value, extra underscores).
- Full `flutter test` was not re-run. `main` was not merged, and the Flutter application was not published. The three SQL files and the `doctor-card-access` function were applied later the same day; see the live setup list above.

### Pharmacy package editor (2026-10-02)

Progressive Arabic RTL editor (`PharmacyPackageFormPage`): Category → Template → Products → Details → Review/Save. Saved packages stay on `PharmacyBundlesManagePage` separate from creation. Local suggestion catalog `pharmacy_package_suggestions.dart` (version 1): 6 categories, 12 templates, 13 vitamins + minerals/multivitamin/omega-3/probiotic; NIH ODS consumer fact-sheet URLs + `reviewedOn`. Templates never auto-select all ingredients. Pharmacist review checkbox required before publish. Package cover + per-product images via `uploadPharmacyAsset` (`asset_only`) when owner has `image` / `products` / `packages_add` / `packages_edit`. Separate owner permissions `packages_add` / `packages_edit` / `packages_delete` (plus legacy `products` = full). Server enforces via `pharmacyBundlesPermissionDenied` on every update (fresh `loadAccess`). Empty public pharmacy page after shared load with no active rows: messaging + admin publish CTA; does not unhide inactive pharmacies.

Tests: `pharmacy_package_suggestions_test.dart`, `pharmacy_package_editor_test.dart`, `pharmacy_shared_catalog_test.dart`. Policy tests for package CRUD added to `policy_test.ts` (deno not available in this agent run — re-run locally). Edge function must be redeployed for permission enforcement; no new SQL migration required for this editor step.

### Pharmacy packages — single «الباقات» path (2026-10-04)

The package tools are no longer spread through the pharmacy form. Admin and owner editors keep the basic pharmacy fields and open packages from one button, «الباقات». Inside: saved packages, then «إضافة باقة», then a suggested package, then an editor that lists only that template’s items. Choosing a template copies names into a draft. It does not write doses, therapeutic claims, or the template’s caution text, and it does not change the template or previously saved packages. The pharmacist can accept the names, delete or rename an item, edit its description, add an item, and set the package name, description, image, price, and optional previous price. Nothing is stored until «حفظ الباقة». Cancel returns no bundle. Add, edit, delete, show, and hide stay, with the same `packages_add` / `packages_edit` / `packages_delete` / `products` permissions.

### Patient health file — «ملفي الصحي» (2026-10-04)

Browsing doctors, labs, radiology, and pharmacies stays open without an account. Booking on a doctor card is still contact guidance (call/WhatsApp); it does not ask for a new login. «ملفي الصحي» is on the settings page and uses Supabase Auth email/password. The clinic admin email cannot be used as a patient account.

Password recovery and email confirmation for patients use `#/patient-health`. Admin recovery uses `#/admin-recovery`. Those two redirects stay separate. Opening a recovery link still routes by email: admin email → admin password page, any other email → patient password page. After confirmation, a `#/patient-health` return opens the patient gate.

The patient can record more than one diagnosed condition (pressure, diabetes, thalassemia, or another chronic condition), pressure readings, glucose readings with unit and timing, and thalassemia appointments, transfusions, and lab results they type in. The screen says the patient entered the data. There is no automatic treatment schedule, no shared targets, and no automatic medical alerts. Validation only rejects impossible numbers, units, and dates, including Arabic digits.

«عرض بطاقة المتابعة» lets the patient pick one condition, a period, which parts to include, and whether to show their name. Images and attachments are **not** included unless the patient turns on «تضمين الصور والمرفقات» and ticks each file. The export preview shows those chosen images. PDF is the Arabic card page followed by one contained page per selected image. The image export shares the card PNG plus each selected image as separate files; if the share sheet fails, each file is downloaded or saved locally. A selected image that fails to load is named before export and the export is aborted. The share step still warns that the copy cannot be pulled back from the recipient’s device. No public health-file URL is created. In the health file, an attachment shows a tappable thumbnail and opens a zoomable viewer (loading and error states included); bytes stay private in `patient-health` and are read only by the owner.

Schema applied on the live project (2026-10-04, by the owner): `supabase/patient_health_file_schema.sql` and `supabase/security_harden_zero_impact.sql`. Do not re-run those two files. The six patient tables have RLS enabled and forced; bucket `patient-health` is private.

Hardening SQL and Edge Function `patient-account` were corrected after review (2026-10-04): trigger `patient_user_id_immutable` sets `search_path = public`; deletion lists `patient-health` with pagination and nested folders, then deletes **exact listed names** in batches of 1000 (not a folder prefix and not SQL `storage.objects`). Empty listings skip Storage DELETE. The review note said composite FKs/triggers and function version 2 may already be on the live project — **do not blindly re-run** `patient_health_hardening.sql`. SMTP, redirect URLs, and real account-deletion acceptance remain external. `main` was not merged and the site was not published.

### App icon write and doctor photo upload (recorded 2026-10-04)

Live corrections, documented in project SQL (do not re-run the already-applied harden file; `admin_write_policy_correction.sql` is review-only):

1. **App icons** — `app_ui_icons_auth_write` is `is_clinic_admin()` in `app_ui_icons_schema.sql` and in `security_harden_zero_impact.sql`. Storage folder `ui_icons/` is admin-only.
2. **Doctor photos** — the hosted policy named `Admin upload doctor images 5uiklb_0` was restricted to `is_clinic_admin()`. The same rule is recorded in `supabase/admin_write_policy_correction.sql` (drop that dashboard name, keep `clinic_media_doctors_auth_insert` admin-only). An enabled doctor with the `image` permission still uploads through `doctor-card-access` (`upload_photo` → Storage API → `doctors/{that id}/`). After the image permission is removed, that path returns 403. Booking status `available` / `walk_in_only` / `full` is the same owner field path; admin may also set `unavailable`.

External setup still required before email confirmation and password recovery actually arrive: a mail provider, custom SMTP credentials in Supabase Authentication (not in the app), confirm email left enabled, Site URL, and Redirect URLs that include the patient and admin hashes (`#/patient-health` and `#/admin-recovery`) plus the web origin. The app reports that the send was requested and does not claim the inbox was checked. Deploy `patient-account` and apply `patient_health_hardening.sql` only after review. `main` was not merged and the site was not published.

Verification on 2026-10-04 (local, not production): booking widget test without login; in-memory two-account isolation including UPDATE of `condition_id`; doctor `upload_photo` allow then revoke; Arabic card layout plus a generated Arabic PNG wrapped in PDF; Deno 23 passed (`doctor-card-access` 19, `patient-account` 4); `deno check` on `patient-account/index.ts` passed. Full `flutter analyze`: 63 info, 0 error, 0 warning (exit 1 because of infos; none new as errors). Full `flutter test`: all passed. Widget `toImage` of `FollowUpCardView` is still unreliable in the headless test binding; the running app captures that widget. Live two-account Storage isolation was not exercised against production.

### Ads + local Smart Brain review (2026-10-04)

Reviewed existing ads path and local brain; did **not** add a second ads system or an external AI service. Fixed the main gap: `HomeAdSlot` was unwired — now on Phase 1 home with `AdsCatalogRefresh` after admin changes and pull-to-refresh. Pure eligibility helpers + fake-campaign unit tests cover schedule/priority/expiry/`display_seconds` vs campaign window. Production ad rows were not created or edited.

Smart Brain on this tree remains the local M1–M7.1 search-and-execute stack (`clinicalEnabled` default off). Live revalidation before call/WhatsApp already existed; added coverage that a **changed phone** after search uses the live number. New intents: «ملفي الصحي» / «بطاقة المتابعة» → `openPatientHealth` → `PatientHealthGate` (login required for data; share stays explicit inside the health UI). Paid ads do not alter natural search ranking.

Targeted verification (2026-10-04): `ads_campaign_eligibility_test`, `patient_health_brain_intent_test`, `live_entity_revalidation_parity_test`, `doctor_booking_no_login_test` — **28 passed**. Analyzed touched Dart paths: 0 errors/warnings (pre-existing infos only). No SQL applied, no deploy, no `main` merge.

Local Chrome preview (same day): `--dart-define=ADS_LOCAL_PREVIEW=true` injects an in-memory home campaign (`lib/ads/ads_local_preview.dart`) with no Supabase reads/writes. Verified on `http://127.0.0.1:7357/`: image + «إعلان» badge under Ask Ghadeer; click opened `https://example.com/`; deactivate and campaign end hid the slot; `display_seconds=2` auto-hid the slide. Preview bar stays for controls only when the define is on.

### Local Smart Brain next-step suggestions (2026-10-05)

Contextual next-step chips (0–3) replace the old static «تفاصيل/اتصال/واتساب/المزيد» strip. Builder: `SmartBrainSuggestedActionsBuilder.suggest` in `lib/search/conversation/smart_brain_suggested_actions.dart`. Each chip carries `id`, `kind`, `entityId`, `resultTurnId`, `conversationGeneration`, and `executionQuery`; tap selects by entity id then runs the same `_runSearch` path as typing (live revalidation for call/WhatsApp/booking). Stale chips (old generation/result turn) are refused with an Arabic snackbar. Bare «نعم» executes only a single pending yes-offer; multiple chips ask which step. Auth change clears offer session. No chat/health text stored; ads do not rank suggestions.

Examples covered in unit tests: multi-doctor ordinal open labels; after select → details/booking/hours by goal; after hours → booking+location; WhatsApp only if `canWhatsApp`; lab packages/analyses/location; empty+`availableOnly` → relax one filter (awaits user); thanks → no chips; patient health → gate only without share.

Targeted verification: `smart_brain_next_step_suggestions_test` + `smart_brain_suggested_actions_test` + `smart_brain_open_select_parity_test` — **29 passed**. Interactive Chrome / 360px visual not completed in this agent environment (device Chrome launch previously failed).

### Local Smart Brain context + open/select parity (2026-10-05)

Fixed the proven bug: after «أريد طبيب أطفال», «افتح الثاني» must open (same path as «عرض التفاصيل»); «الثاني» selects only; «افتح التفاصيل / افتح بطاقته / ورّيني معلوماته» use the selected entity and must not start a new name search for «التفاصيل». Safety net `_upgradeOpenSelect` + ordinal-before-name in `DoctorTargetResolver` + profile UI-word filter.

Also in this pass (local, no external AI, no deploy, no `main` merge, no production SQL):

- Auth user change / sign-out clears `ConversationContext` on Smart Search (no account-context leak).
- «ورّيني رقمه» shows the live phone; «اتصل بيه» prepares call; booking stays non-automatic and suggests same-list alternatives when `booking_status=full` without auto-selecting.
- Compound: «دورلي طبيب أطفال وافتح الثاني» (strips open/ordinal from specialty parse).
- Availability copy says «حسب الدوام المسجّل» (never «موجود الآن» from schedule alone).
- `AppFunctionCatalog` + `BrainQualityMetrics` (device counters, no chat/health text) surfaced on `AppStatsAdminPage`.
- Review-only optional fields: `supabase/doctor_brain_fields_optional.sql` (commented; not applied).
- Meaning-search model: **not** enabled; evaluate later against Iraqi held-out phrases.

Targeted verification (2026-10-05): `smart_brain_open_select_parity_test`, `smart_brain_search_scope_test`, `live_entity_revalidation_parity_test`, `patient_health_brain_intent_test` — **76 passed**. Touched-path analyze: 0 errors/warnings (pre-existing infos only). Full `flutter test` / interactive Chrome conversation walkthrough not claimed in this note — run locally before release.

### Local Smart Brain hours follow-up context (2026-10-06)

Proven device bug: after pediatrics results, «شنو دوامه» was treated as a **keyword search**, which called `beginNewDoctorSearch` + empty `rememberResults` and wiped the list; «افتح الأول» then had nothing to open. Tapping «علي ناصر السعيدي» opened the card without keeping a durable selected id for the return trip, so hours after back also searched empty.

Cause (UI → planner → executor): `DoctorPresenceQuestion.isContextual` missed hours phrases (`شنو` was a block token); resolver mapped the line to `generalSearch`; fallback allowed a data search; `selectDoctor` cleared a pending hours clarification before the ordinal/chip query could resume it.

Fix (local only; no production SQL, no deploy, no `main` merge):

- Hours phrases (`شنو دوامه` / `دوامه` / `وريني دوامه`) classify as `doctorAvailability` (entity info, not a word search).
- No selected doctor + several results → «تقصد أي طبيب؟» with options, `pendingAction=doctorAvailability`. After pick, answer from recorded hours (`DoctorTodayAvailability.describe`); if unrecorded say so — never «لا نتائج» and never guess.
- Failed/unknown follow-ups with preserved results do not start a new doctor search.
- Chip tap selects by `entityId` before open; `selectDoctor` keeps pending hours/location/booking so the info question survives selection.
- Relax-filter chips are not offered for doctor-info intents.

Verification (2026-10-06): `smart_brain_conversation_ui_test` (including search → tap suggestion → open → back → hours, and hours-before-select then chip answers pending) + `smart_brain_open_select_parity_test` + `smart_brain_search_scope_test` + `smart_brain_next_step_suggestions_test` + `smart_brain_suggested_actions_test` — **90 passed**. Touched-path `flutter analyze`: no issues. Full `flutter test` not run. Updated local web-server served `lib/main.dart` at `http://127.0.0.1:7362` (onboarding gate «تخطي الآن» visible). Interactive hours sequence in that agent browser was **not** completed (Flutter web canvas has no usable accessibility tree; coordinate click missed skip). Tabs on `:7357` / `:7358` may be stale. Booking remains contact guidance only; patient health / privacy paths unchanged.

### Pharmacy persistence (2026-10-02)


Nothing in the pharmacy catalog was in Supabase before this change. Doctors and labs are. Pharmacy list, products, prices, offers, hours, phones, and images lived in `pharmacies_local_v1` on each device, with `PharmaciesCatalog` as the built-in fallback.

Shared after `pharmacies_public_schema.sql` is applied: the `pharmacies` row (`name`, `is_active`, and `profile`). Owner saves that pass the edge function update `profile` for the permitted keys only: image, logo, slogan, hours, phones, bundles, and offer fields. Those rows are what other devices read.

Still device-local until an administrator publishes: edits that never went through that table, including the old PIN-era bundle edits. Publishing does not delete `pharmacies_local_v1`. Before the shared catalog has ever loaded, visitors still see the local copy, then the built-in catalog. After a successful load, visitors see only active shared rows, including an empty list when the administrator hid or removed every pharmacy. An offline failure keeps that last shared result and does not restore a hidden pharmacy from the device or the bundle. An open pharmacy page no longer borrows another pharmacy's bundles when its own list is empty.

A direct write to SharedPreferences does not change the visitor list once a shared row exists. Public clients have no insert policy. Owner product images that are `data:` URLs are rejected; they must be uploaded to `pharmacies/{that id}/` with the image or products permission.

Owner password change stays a separate action from saving the card. In the doctor, laboratory, and pharmacy owner editors it opens from «تغيير كلمة المرور» into a dialog with the current password, the new password, and confirmation. Cancel closes that dialog and leaves unsaved profile text in place. The server still checks the current password, requires at least 8 characters, and bumps `session_version`. First-time activation remains on the entry sheet. Photo upload checks the session entity id and the image permission, then stores the file under that entity's folder.

### تعارض النسخة عند الحفظ (2026-10-02، العمود موجود على المشروع الحي)

الحماية لم تكن موجودة. أصبحت على الأطباء والمختبرات وباقات التحاليل والصيدليات، بما فيها نشر صف صيدلية موجود.

كل حفظ محتوى يرسل `content_revision` التي فُتحت بها الشاشة. التحديث يطابق هذا الرقم ويرفعه واحدًا في نفس الطلب. صفر صفوف يعني رفضًا. الإدراج الجديد (طبيب أو مختبر أو باقة بلا معرف، أو أول نشر لصيدلية غير موجودة) لا يُعامل كنسخة قديمة. إن وُجد الصف أثناء محاولة الإدراج يُرفض الكتابة.

المسار نفسه للإدارة والمالك. رسالة الرفض الواحدة:

`تعذر الحفظ لأن البيانات تغيّرت من جهة أخرى. ما كتبته ما زال في النموذج.`

النموذج لا يُغلق ولا تُمسح الحقول. لا يُعاد تحميل صف الخادم داخل النموذج، لأن ذلك يمسح ما كتبه المستخدم. إعادة الحفظ بنفس النسخة تبقى مرفوضة إلى أن يخرج ويعيد الفتح.

التحقق المحلي لكلا الترتيبين نجح داخل `policy_test.ts`:

- الإدارة أولًا: حفظ الطبيب بالنسخة 1 ينجح ويصبح 2، ثم حفظ المالك بالنسخة 1 يرجع 409 ولا يغيّر النبذة.
- المالك أولًا: حفظ منتجات الصيدلية بالنسخة 1 ينجح، ثم نشر الإدارة بالنسخة 1 يرجع تعارضًا ويُبقي عرض المالك.
- المختبر: وصف الإدارة أولًا، ثم وصف المالك القديم يُرفض والنص المنشور يبقى وصف الإدارة.
- الباقة: حفظ المالك أولًا، ثم حفظ الإدارة بنفس النسخة يُرفض ويُبقي اسم باقة المالك.

`deno test` لهذه السياسة: 16 نجح. `deno check` على `index.ts` نجح. اختبار ظهور الصيدليات: 2 نجح. تحليل ملفات Dart الملموسة لم يُظهر مشاكل جديدة؛ معلومات `main.dart` القديمة بقيت كما هي.

ملفات SQL الثلاثة نُفِّذت على المشروع الحي، ودالة `doctor-card-access` منشورة. التطبيق نفسه لم يُنشر، و`main` لم يُدمج. نشر كتالوج الصيدليات من زر الإدارة ما زال يدويًا لأن الجدول أُنشئ فارغًا.

### What “done” means operationally today

Default shipping brain = **local search-and-execute over platform entities**, with clinical/AI stacks **parked**. Directory breadth in the working tree exceeds committed HEAD.

---

## 15. KNOWN UNFINISHED / PARTIAL WORK

### Real unfinished work (code evidence)

- مواعيدي tab = coming soon; no appointment booking backend
- Doctor booking button = contact guidance only
- Patient email confirm/reset: app redirects are coded; custom SMTP + Redirect URLs `#/patient-health` and `#/admin-recovery` are still external
- `patient_health_hardening.sql` / `patient-account`: do not blindly re-run SQL; SMTP and live delete-acceptance still untested
- Pharmacies: `public.pharmacies` is applied on live Supabase and starts empty until the administrator publishes the device copy. Physio/supplies remain device-local
- Pharmacy product filter / offers snackbars «قريباً»
- Pharmacy favorite not persisted
- Ads: home slot wired; other placement keys in admin have no list-page UI yet
- Push notifications absent
- README still template
- Possible client/Edge mode mismatch (`dynamic_message` / `assistant_query` vs Edge `nlu_parse` / `understand_turn`)
- Untracked SQL may not be applied on live Supabase
- Bloated hub files (`smart_brain_planner.dart`, `main.dart`) — maintenance risk
- Dirty working tree not committed/reviewed as a release
- Smart Brain: relative dates («باچر / الخميس الجاي») and local meaning-search eval still open; optional doctor brain columns in `doctor_brain_fields_optional.sql` not applied; admin quality panel shows counters only (not live “missing/stale field” inventory from Supabase yet)
- Interactive Chrome QA of the open/select + next-step chips path after 2026-10-05 changes still needs a manual pass on device/browser (including 360px width)
- Next-step: package price / lab analyses chips depend on planner understanding those short queries; some entity types share the generic details/location/contact bundle only

### Intentionally disabled features (preserve)

- `SMART_BRAIN_CLINICAL_ENABLED=false` clinical/companion/unified paths
- Empty `AI_EDGE_FUNCTION_URL`
- `understand_turn` not wired to Dart (owner decision recorded in `PROJECT_SUMMARY.md`)
- Some clinical pack “full pack” toggles false
- Second Ghadeer STT instance launch permanently disabled
- Legacy `FavoritesPage` / unused home welcome/trending as primary UI

### Future ideas (named as future in repo)

- `personal_companion_profiles_future.sql`
- Re-enable clinical Smart Brain when product scope expands
- CI pipeline (none present)

### Technical debt

- Mega-files; admin still concentrated in `main.dart`
- PROJECT_SUMMARY outdated vs working tree
- Analyzer warnings historically left outside phase scopes
- `tool/tmp_*.dart` and `test/tmp_m71_full_out.txt` look like scratch artifacts
- No automated store release evidence in-repo

---

## 16. NEXT MILESTONE

Not selected yet. Review the verified project state and unfinished items with the user before selecting the next milestone.

---

## 17. PERMANENT DEVELOPMENT RULES

1. **Read `PROJECT_CONTEXT.md` before future work.**
2. **Confirm against Git before changing code** (`git status`, `git log`, HEAD hash).
3. **Git committed history** is authoritative for **completed/committed milestones**; the **current working tree** is authoritative for newer uncommitted implementation; this file indexes both — never discard dirty-tree work merely because HEAD is older.
4. **Do not repeat completed milestones/tests merely for reassurance.**
5. **Re-run tests only when relevant changes require regression verification**; prefer targeted suites, then broaden if risk spans Smart Brain/voice. Label old pass counts **historical**; record a new pass count here only after an actual successful run on the relevant tree/commit — never infer PASS from old reports, file presence, corpus expectations, or prior milestones.
6. **Preserve intentionally disabled systems** unless the user explicitly re-enables them (`SMART_BRAIN_CLINICAL_ENABLED`, AI URL, deferred SQL).
7. **Never expose or commit secrets** (service_role, AI keys, keystores, `.env`).
8. **Keep commits focused**; only commit when the user explicitly orders it (see `CLAUDE.md`).
9. **Update `PROJECT_CONTEXT.md` after completed milestones or durable architecture/product decisions.**
10. **Mobile First:** phone layout is the primary reference; preserve existing responsive tablet/desktop/web behavior (`lib/utils/responsive.dart` and related tests).
11. Obey hard rules in `CLAUDE.md` / `AGENTS.md` (no push/reset/secret edits without explicit order; do not break Smart Brain/voice/Supabase/medical safety as drive-by changes).
12. New user-facing copy: natural Iraqi Arabic, RTL-correct.
13. Schema: write SQL files; user applies to live Supabase.
14. Compare regressions against baseline `ea648ec` when investigating “what worked before.”

---

## 18. AI SESSION HANDOFF PROTOCOL

Every future AI/Cursor/ChatGPT session must:

1. Read **`PROJECT_CONTEXT.md`** first (then `CLAUDE.md` for hard rules).
2. Run **`git status`** (short).
3. Inspect recent relevant **`git log`**.
4. Confirm current **HEAD** hash + message.
5. Identify last **verified committed milestone** vs **uncommitted working-tree progress**.
6. Continue from that state — **never restart full project discovery** unless this file is missing/contradictory or the user requests a refresh.
7. After durable milestones or architecture decisions: **update this file** (and leave app code commits to explicit user order).
8. If asked to “start over,” refuse rediscovery theater; use this context + Git instead.

---

## 19. QUICK REFERENCE

| Path | Controls |
|------|----------|
| `CLAUDE.md` / `AGENTS.md` | Hard project rules for agents |
| `PROJECT_CONTEXT.md` | This canonical memory |
| `PROJECT_SUMMARY.md` | 2026-09-20 Phase 4A snapshot (partially stale) |
| `pubspec.yaml` | Version, deps, assets |
| `lib/core/app_config.dart` | Feature flags + public Supabase config |
| `lib/main.dart` | App entry, home shell, nav, favorites, many admin UIs |
| `lib/home/` | Phase 1 home sections, colors, coming-soon page |
| `lib/doctors/` | Doctor UI, specialties, availability, notifications admin, stats |
| `lib/labs/` | Labs + packages + admin |
| `lib/radiology/` | Radiology centers + admin |
| `lib/pharmacies/` | Pharmacy directory + single «الباقات» draft editor + suggestion catalog |
| `lib/patient_health/` | Patient health file, follow-up card, Supabase Auth gate |
| `supabase/patient_health_file_schema.sql` | Patient RLS schema (applied 2026-10-04; do not re-run) |
| `supabase/patient_health_hardening.sql` | Account-delete + condition owner FK (review only, not applied) |
| `supabase/admin_write_policy_correction.sql` | Documents live `5uiklb_0` / `app_ui_icons_auth_write` admin-only (review only) |
| `supabase/functions/patient-account/` | Storage API account deletion |
| `lib/physio/` | Local physio directory |
| `lib/supplies/` | Local supplies directory |
| `lib/ads/` | Campaigns + home slot + eligibility/refresh |
| `lib/search/smart_search_page.dart` | Smart Search / brain UI executor |
| `lib/search/smart_search_service.dart` | Local/Supabase search helper |
| `lib/search/*_name_matcher.dart` | Fuzzy Arabic entity matching |
| `lib/voice/intent/smart_brain_planner.dart` | Smart Brain hub |
| `lib/voice/intent/intent_resolver.dart` | Rule-based intents |
| `lib/voice/intent/ghadeer_scope_gate.dart` | Platform scope lock |
| `lib/voice/intent/platform_grounding.dart` | Anti-hallucination grounding |
| `lib/voice/intent/unified_entity_discovery.dart` | Cross-type name discovery (M5) |
| `lib/voice/intent/result_set_refiner.dart` | In-list filters (M3) |
| `lib/voice/intent/confidence_policy.dart` | Execute vs confirm bands |
| `lib/voice/conversation_context.dart` | Session memory authority |
| `lib/voice/result_context.dart` | Typed result lists / ordinals |
| `lib/voice/*speech*`, `text_to_speech_service.dart` | STT/TTS |
| `lib/unified_brain/`, `lib/nlu/`, `lib/ai/` | Clinical/NLU/AI (mostly gated) |
| `lib/clinical_knowledge/`, `lib/health/`, `lib/companion/` | Preserved clinical stack |
| `lib/widgets/entity_*` | Contact, social, PIN, speak, slot icons |
| `lib/services/` | Stats, dynamic message, icons, PIN, admin session, profile |
| `supabase/*.sql` | Manual schemas/seeds |
| `supabase/functions/ai-assistant/` | Edge AI function |
| `supabase/functions/doctor-card-access/` | Owner access for doctors, labs, and pharmacies |
| `supabase/doctor_card_access_schema.sql` | Credential + attempt tables (apply manually) |
| `test/` | Flat regression suite |
| `test/fixtures/` | Corpora / golden JSON |
| `netlify.toml` | Web SPA deploy |
| `assets/` | Branding, lab/radiology/package defaults |

---

*End of PROJECT_CONTEXT.md. Update after the next agreed milestone or durable decision. Do not treat uncommitted working-tree labels as Git milestones until committed.*
