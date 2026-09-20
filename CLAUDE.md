# CLAUDE.md — Ghadeer Clinic (عيادة الغدير)

Permanent project reference. Read this before working. It is the single source of
truth for project rules; other tools reach it through `AGENTS.md` (a link to this file).

## Project

Flutter app for a clinic directory: doctors, laboratories, radiology, ads, and a
voice/text assistant ("Smart Brain"). The UI is Arabic (RTL, Iraqi dialect).

- Stack: Flutter 3 / Dart (`sdk: ^3.13.2`), Supabase (`supabase_flutter`), Netlify for the web build.
- Targets: mobile first; web, macOS and the other Flutter platforms also exist.
- GitHub remote: `origin` → `github.com/mohammedalmusawy/algadeer`, branch `main`.

## Baseline

- **`main` at commit `ea648ec`** ("Phase 3D Step 4 - follow-up regression fixes", 2026-09-20)
  is the current starting point and the reference for "what worked before".
- Compare against it with `git diff ea648ec`. Do not rewrite or move it.
- Work is organised in named phases (`Phase 2G`, `Phase 3D Step 4`, ...). Regression
  tests are named after the phase that introduced them (e.g. `*_phase3d_step4_test.dart`).

## Hard rules (need an explicit order from the user, every time)

Never do any of the following unless the user explicitly orders that specific action.
Approval for one commit, push or deletion does not extend to the next.

- `git commit`, `git push`, `git reset --hard` (also `git clean`, force-push, deleting branches or tags).
- Deleting files or directories.
- Editing `.env` / `.env.*`, keys, tokens or any secret. Never print secrets in output.
- Putting a `service_role` key or any AI/API secret in client code. The Supabase URL and
  publishable key in `lib/core/app_config.dart` are the only client-side values; keep it that way.

"Read only", "plan only" or "review only" means change nothing.

## Working method

1. Read the relevant code and tests first; report or plan before editing when the change is not trivial.
2. Make small, targeted changes. No unrequested refactors, renames, formatting sweeps or dependency changes.
3. Fix bugs with a regression test in `test/`, following the existing naming style.
4. Leave changes uncommitted for the user to review unless they order a commit.

## Verification

Both must pass before a task is called done. Report the real result, including failures
and anything you did not run.

```
flutter analyze
flutter test
```

- Single test: `flutter test test/<name>_test.dart`.
- Web release build: `flutter build web --release` (deployed from `build/web`, see `netlify.toml`).
- Run the tests that cover the area you touched even when the full suite is slow (see the list below).

## Do not break (unless the task explicitly targets it)

Do not change the behaviour of these areas as a side effect of another task:

- **Smart Brain** — `lib/voice/` (`intent/`, `conversation_context.dart`, `guided_conversation/`,
  `clarification/`, `conduct/`), `lib/unified_brain/`, `lib/nlu/`, `lib/clinical_knowledge/`
  (`packs/`), `lib/companion/`, `lib/health/`, `lib/memory/`, `lib/follow_up/`, `lib/search/conversation/`.
  Conversation behaviour is tuned by many phase regression tests; a small change in one layer
  can shift another. Read the layer above and below before editing.
- **Voice / TTS / mic** — `lib/voice/text_to_speech_service.dart`, `speech_recognition_service.dart`,
  `voice_input_service.dart`, `voice_response_controller.dart`, `startup_*greeting*`, `macos_arabic_tts_channel.dart`.
- **Supabase** — `lib/core/app_config.dart`, the services that call Supabase, and `supabase/`
  (SQL schemas and `functions/ai-assistant`). Do not run or edit SQL against the live project;
  schema changes are written as files and applied by the user.
- **Existing features and behaviour** — doctors, labs, radiology, ads, admin pages, notifications, app stats.
- **Medical safety** — the assistant must not diagnose or prescribe. Keep the red-flag /
  safety logic (`lib/health/safety/`, clinical packs) intact.

Tests to run for these areas: `smart_brain_v1_release_gate_test.dart`, `smart_brain_pipeline_test.dart`,
`smart_brain_phase2_full_integration_test.dart`, the `*_phase*_test.dart` files near what you changed,
`tts_interruption_hotfix_test.dart`, `voice_settings_test.dart`, `startup_greeting_test.dart`,
`mic_lifecycle_greeting_regression_test.dart`.

## UI: Mobile First, keep Responsive

- **Mobile first is the reference.** Design and check for phone width first, then widen.
- Preserve the current responsive behaviour (`lib/utils/responsive.dart`, home layout, bottom navigation).
  No fixed widths/heights that overflow on small screens; the app must stay RTL-correct.
- Related tests: `responsive_home_layout_test.dart`, `bottom_nav_body_height_test.dart`,
  `doctor_profile_name_layout_test.dart`, `smart_brain_conversation_ui_test.dart`.

## Project structure

```
lib/main.dart            app entry, home, admin entry points (very large: ~3.7k lines)
lib/core/                app_config.dart (Supabase URL / dart-define values)
lib/doctors/  labs/  radiology/  ads/     feature areas (pages, services, admin/)
lib/search/              smart search (smart_search_page.dart, smart_search_service.dart)
lib/services/  models/  widgets/  utils/  home/  settings/  onboarding/  branding/
lib/voice/               assistant orchestration, intent/ (smart_brain_planner.dart ~6.5k lines), speech, TTS
lib/unified_brain/  nlu/                 conversation understanding
lib/clinical_knowledge/  health/  wellness/  wellbeing_planner/  daily_context/
lib/companion/  memory/  follow_up/      personal companion, memory, follow-ups
supabase/                SQL schemas and functions/ai-assistant
test/                    ~96 test files, flat, named by feature or phase
assets/                  branding, labs defaults, radiology, packages
netlify.toml             Flutter web SPA deploy settings (publish build/web)
```

Very large files (`smart_brain_planner.dart`, `main.dart`, `smart_search_page.dart`,
`conversation_context.dart`): read only the parts you need and edit narrowly.

## Conventions

- Match surrounding code: naming, comment density and idiom. Comments in this codebase are often Arabic.
- Lints: `flutter_lints` via `analysis_options.yaml`; do not add `ignore` comments to hide new warnings.
- New user-facing text is Arabic and must read naturally in the Iraqi context.
- Commit messages (only when the user orders a commit) follow the existing style: `Phase <X> Step <N> - <short description>`.

## Other tools

`AGENTS.md` links here so Cursor, Codex and similar tools read the same rules. Do not
copy this content into other files; edit `CLAUDE.md` only.
