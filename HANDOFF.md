# Labaan — Handoff

**Last updated:** 2026-07-28
**State:** Player mobile app is fully navigable and now selects the sibling
`labaan-backend` Supabase project automatically when runtime credentials are
provided. The local backend has a complete, idempotent development seed and
the phone bypass authenticates its seeded player. Mock mode remains the
default when credentials are absent. Privileged backend Edge Functions are
still stubs.

---

## TL;DR

`flutter run --dart-define-from-file=config/local_backend.json` → tap
**CONTINUE WITH PHONE** → the app authenticates the seeded `@tonton26`
account and opens the real local data through Supabase/RLS. The seed includes
users, teams, tournaments, registrations, matches, payments, notifications,
moderation, and a completed payout.

To use Supabase: copy `config/backend.example.json` to the ignored
`config/backend.json`, add the anon/publishable key, and run with
`--dart-define-from-file=config/backend.json`. No provider edits are needed.
For UI testing, Continue with phone defaults to the authenticated seeded
`@tonton26` development account (or its mock equivalent); set
`BYPASS_PHONE_AUTH=false` to test real Supabase OTP.

The sibling backend's local Supabase stack is seeded and can be rebuilt with
`npm run db:reset`. The hosted development project
`xmbfzcgejpzvgrfvvfyi` also has migrations `0019`–`0021` and the same
synthetic seed, applied on 2026-07-28.

---

## Where things live

| Path | What |
|---|---|
| `lib/main.dart` | Bootstrap + `ProviderScope` + optional `Lb.init()` (Supabase) |
| `lib/app.dart` | Router: 17 GoRoutes + `StatefulShellRoute` for tabs |
| `lib/core/theme/` | Dark cyber-esports palette, Chakra Petch + IBM Plex typography, snackbar + page transitions |
| `lib/core/domain/` | Spec-locked enums — [ranks](lib/core/domain/ranks.dart), [badges](lib/core/domain/badges.dart), [tournament_tier](lib/core/domain/tournament_tier.dart), [tournament_status](lib/core/domain/tournament_status.dart), [roles](lib/core/domain/roles.dart) |
| `lib/core/widgets/` | Reusable primitives — [SlantButton](lib/core/widgets/slant_button.dart), [RankHex](lib/core/widgets/rank_hex.dart), [LbCard](lib/core/widgets/lb_card.dart), [GameArt](lib/core/widgets/game_art.dart), [SectionLabel](lib/core/widgets/section_label.dart), [LbChip](lib/core/widgets/lb_chip.dart), [LbSkeleton](lib/core/widgets/lb_skeleton.dart), [StatusPill](lib/core/widgets/status_pill.dart), [TeamAvatar](lib/core/widgets/team_avatar.dart) |
| `lib/core/data/` | Data layer — [models](lib/core/data/models.dart), [repos](lib/core/data/repos.dart) (interfaces), [mock_repos](lib/core/data/mock_repos.dart), [supabase_repos](lib/core/data/supabase_repos.dart), [fixtures](lib/core/data/fixtures.dart), [providers](lib/core/data/providers.dart), [supabase_client](lib/core/data/supabase_client.dart) |
| `lib/features/` | 20 screen files across identity / registration / home / browse / compete / tournament / team / leaderboard / system / shell |
| `supabase/migrations/` | `0001_init.sql`, `0002_indexes_triggers.sql`, `0003_rls.sql` — full DDL matching spec §10, indexes per §9.3, RLS per §11 |
| `supabase/seed.sql` | Dev seed mirroring `LbFixtures` |
| `test/unit/` | Domain math tests (39) |
| `test/widget/` | Per-screen tests (19) |
| `docs/adr/` | 4 architecture decision records |
| `.github/workflows/ci.yml` | dart format + flutter analyze + flutter test on push/PR |
| `README.md` | Public-facing overview |

**External references:**
- Spec PDF: `/Users/richtonehangad/Downloads/Labaan-design/uploads/Labaan_Project_Overview-v-1-3.pdf` (17 pages, v1.3, Confidential)
- Design HiFi HTMLs: DesignSync MCP project `8b4f5564-b56f-4435-a9ff-ca0058e7883f`
- Local design copies: `design-reference/*.html`
- Memory index: `~/.claude/projects/-Users-richtonehangad-FlutterProjects-labaan/memory/MEMORY.md`

---

## Completed work

### Phase 1 — Scaffold + design system (tasks 1–4)
- Flutter project scaffolded with `flutter create` (org `com.labaan`).
- go_router + google_fonts (Chakra Petch, IBM Plex Sans, IBM Plex Mono).
- Full color palette, type ramp, theme, and reusable widgets ported from HiFi.

### Phase 2 — Screens (tasks 5–10)
- 12 MVP screens per spec §7.1 built to visual fidelity of the HiFi mocks.
- Bottom-tab shell with animated lime-glow active state.
- Verified end-to-end on iPhone 17 sim.

### Phase 3 — Spec reconciliation (tasks 11–16)
- Full PDF ingested and 10 memory files created (rank ladder, tournament tiers, badges, roles, tech stack, MVP scope, critical decisions, legal, spec pointer).
- Domain-constants layer added; screens rewired to draw from single sources of truth.
- Corrected factual errors surfaced by the spec (badge names, rank-up win-count math).
- Stubbed the 5 previously-missing MVP screens as real scaffolds.
- Wired supabase_flutter client (no-op without credentials).
- Added CAPTCHA note + fee-model wiring to Registration.

### Phase 4 — Data layer (tasks 17–22)
- Added `flutter_riverpod` + `freezed_annotation` + `json_annotation` + `build_runner`.
- 12 immutable data models covering spec §10 entities.
- 10 abstract repository interfaces (`AuthRepo`, `TournamentsRepo`, `MyTournamentsRepo`, `BracketRepo`, `RegistrationRepo`, `ResultsRepo`, `ProfileRepo`, `TeamsRepo`, `PlayersRepo`, `LeaderboardRepo`, `NotificationsRepo`).
- Mock impls with realistic 320ms read / 520ms write latency.
- Riverpod providers wired end-to-end.
- All 12 screens refactored to consume providers (loading/empty/error/retry throughout).

### Phase 5 — Missing user flows (tasks 36–41)
- First-run identity setup (3-step wizard: username → region → games).
- Payment result screen with success / pending / failed variants.
- Settings + notification preferences.
- Dispute submission (15m SLA, 6 reason categories).
- Routing wired end-to-end (Onboarding → Setup on first-run, Registration → Payment Result, Profile cog → Settings, Notifications with dispute deep-links to Dispute).

### Phase 6 — Testing (tasks 42–44)
- 39 unit tests for domain math (Rank thresholds, tier fees, `formatPeso`, model derivations).
- 19 widget tests covering every load-bearing screen (loading/empty/error/action states, category rendering, gate logic).
- Fixed real layout bugs the tests caught (SectionLabel/SlantButton/OnboardingScreen/DisputeScreen overflow at 400pt viewport).

### Phase 7 — Supabase + polish + docs (tasks 45–52)
- Full SQL migrations: 12 enums, 16 tables, indexes per spec §9.3, append-only guards on payments, per-tournament realtime publication, auto-supersede on fee/rank config changes.
- Role-based RLS policies matching spec §11.
- Dev seed mirroring `LbFixtures` UUIDs 1:1.
- `SupabaseFooRepo` implementations for all 10 repo interfaces.
- Shimmer skeleton widget, page transitions, haptics on SlantButton + tab bar, semantics labels, dark-theme snackbar.
- GitHub Actions CI (format + analyze + test + coverage upload).
- README with architecture, dependency direction, backend swap procedure.
- 4 ADRs: Riverpod choice, mock-first repos, Flutter override, Supabase stack.

**Total:** 52 completed tasks, 78 source files, ~10k LOC.

---

## Architecture

```
Screens (ConsumerWidget / ConsumerStatefulWidget)
    │ ref.watch
    ▼
Riverpod providers  ── lib/core/data/providers.dart
    │
    ▼
Repository interfaces  ── lib/core/data/repos.dart
    │
    ├─ MockRepository (default)   ── mock_repos.dart + fixtures.dart
    └─ SupabaseRepository (later) ── supabase_repos.dart + Lb.client
```

**Every screen depends on a Dart interface, never on Supabase directly.**
Backend swap = 11 provider-binding lines.

---

## Spec facts locked into code

| Spec | In code |
|---|---|
| §3 · 5-role system | [`UserRole`](lib/core/domain/roles.dart) enum; mobile app is Player-only |
| §3.1 · Moderator SLAs (15/30/45/lock) | [`ModeratorAction`](lib/core/domain/roles.dart) enum |
| §4.1 · 7-rank ladder + win thresholds + badge colors | [`Rank`](lib/core/domain/ranks.dart) enum |
| §4.4 · 7 achievement badges + triggers | [`AchievementBadge`](lib/core/domain/badges.dart) enum |
| §5.1 · 3 bracket formats | [`BracketFormat`](lib/core/domain/tournament_status.dart) enum |
| §5.2 · Tournament lifecycle | [`TournamentStatus`](lib/core/domain/tournament_status.dart) enum |
| §6.3 · 4 tournament tiers + fees + commissions | [`TournamentTier`](lib/core/domain/tournament_tier.dart) enum |
| §9.3 · Cursor pagination | `SupabaseTournamentsRepo.browse` |
| §9.3 · Realtime scoped per tournament_id + autoDispose | `bracketProvider` (`StreamProvider.autoDispose.family`) |
| §9.3 · Append-only financial records | `forbid_mutation` trigger on payments/disbursements |
| §9.3 · Idempotency keys on PayMongo | `payments.idempotency_key` unique column |
| §9.3 · RLS at DB level | Full policies in `0003_rls.sql` |
| §11 · CAPTCHA on registration | `_CaptchaNote` on Registration screen |
| §11 · Pre-signed URL for screenshots | `SupabaseResultsRepo.requestScreenshotUploadUrl` |
| §12 · Legal / regulatory checklist | Documented in README + memory |

---

## Tests

```bash
flutter test                    # 58 passing (39 unit + 19 widget)
flutter analyze                 # clean
dart format --set-exit-if-changed lib test   # clean
```

CI runs all three on every push / PR to `main`.

---

## Known limitations / not done

- **App icons + splash** — user is designing these.
- **Golden tests** — need Chakra Petch / IBM Plex bundled locally instead of google_fonts fetching at runtime.
- **Integration tests** against a real Supabase dev DB — deferred until credentials.
- **Phone OTP verification screen** — `SupabaseAuthRepo.signInWithPhone` currently throws `UnimplementedError` at the second step (OTP code entry). Needs a small screen.
- **Real PayMongo checkout redirect** — Registration currently mocks the flow; real one needs a Next.js API route to create the payment intent.
- **FCM push wiring** — repo interfaces don't own push subscription; needs `firebase_messaging` init in `main.dart` when Firebase project exists.
- **Real Wallet + payment method management** — not built (was in the "post-MVP polish" list).
- **Coverage threshold** — CI uploads `lcov.info` but no enforced minimum yet.
- **Deep-link handler** for share URLs into the app (`labaan://tournament/xxx`).

---

## Next work — options

**A. Field polish before alpha:**
- Phone OTP verification screen (real sign-in end-to-end).
- Bundled fonts + golden test suite.
- Wallet screen (transaction history from `LbPayment` + `LbDisbursement`).
- Report/block user flow.

**B. Backend integration when it lands:**
- Provision Supabase project.
- Run 3 migrations + seed.
- Flip 11 provider bindings.
- Add integration tests against dev DB.
- Wire Next.js API routes for PayMongo webhook + `register_for_tournament` RPC.
- Wire FCM + `firebase_messaging`.

**C. Nice-to-have UX layer:**
- Custom slant page transitions (currently fade-through).
- Animated rank-up celebration with confetti.
- Match key-art (real asset bundle instead of `GameArt` gradient placeholder).
- Post-MVP screens the spec listed as "Post-MVP backlog" (§13.2): Round Robin format, manual seeding, rank decay, seasonal resets.

---

## Continuation prompt

Paste the block below into a fresh Claude Code session opened in
`/Users/richtonehangad/FlutterProjects/labaan/`.

```
I'm continuing work on Labaan, my Philippine e-sports tournament marketplace
Flutter app. Full context lives in HANDOFF.md at the repo root — read it
first for the state of the project, the architecture, spec facts locked
into code, and what's already been done across 52 tasks.

Also read these to load full context:
- HANDOFF.md
- README.md
- ~/.claude/projects/-Users-richtonehangad-FlutterProjects-labaan/memory/MEMORY.md
  (and each memory file it links to)
- The spec PDF at /Users/richtonehangad/Downloads/Labaan-design/uploads/Labaan_Project_Overview-v-1-3.pdf
  (needs pdftoppm — install via `HOMEBREW_NO_REQUIRE_TAP_TRUST=1 brew install poppler`)

Current state: `flutter test` passes 58/58, `flutter analyze` is clean,
every MVP screen is built and consumes Riverpod providers backed by mock
repos. Supabase SQL + swap-ready repos are ready but not activated.

Conventions to follow:
- Never invent rank names, badge names, or tier fees — draw from
  lib/core/domain/ enums which mirror the spec exactly.
- Every new screen is a ConsumerWidget/ConsumerStatefulWidget that watches
  a provider. Loading / empty / error / retry states are non-negotiable.
- Every new repo method goes on the abstract interface first (repos.dart),
  then MockRepository, then SupabaseRepository. Screens never touch
  Supabase directly.
- The mobile app is Player-only. Super Admin / Organizer / Moderator
  surfaces belong in the separate Next.js admin repo, not this one.
- Financial tables are append-only. If you need to reflect a state change,
  insert a new row and let a trigger flip the "current" flag.
- Flutter is the mobile stack (spec's React Native is overridden — see
  docs/adr/003).
- If you can't read a file the user references, stop and ask for a
  screenshot before proceeding. (Saved as a memory.)

Task list to pick from is in HANDOFF.md "Next work — options" — or ask me
what I want next.

Start by summarizing the current state back to me in ~5 bullets so I can
confirm you have the right picture, then wait for my direction.
```

---

## How to run right now

```bash
# From /Users/richtonehangad/FlutterProjects/labaan

# Mocks only (default):
flutter run

# Seeded local Supabase (iOS simulator):
cd /Users/richtonehangad/NodeProjects/labaan-backend
npm run db:start
npm run db:reset
cd /Users/richtonehangad/FlutterProjects/labaan
flutter run --dart-define-from-file=config/local_backend.json

# Real Supabase:
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...

# Tests:
flutter test

# Format + analyze (mirrors CI):
dart format --set-exit-if-changed lib test
flutter analyze
```
