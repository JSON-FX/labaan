# Labaan — Handoff

**Last updated:** 2026-08-01
**State:** Player mobile app is fully navigable and uses the hosted sibling
`labaan-backend` Supabase project by default for normal app launches.
Firebase project `labaan-f3fa6` owns Google and phone
authentication, while Supabase maps Firebase UIDs to the profile UUIDs used
by application tables. The local backend has a complete, idempotent
development seed. Mock mode is restricted to automated tests or an explicit
`USE_MOCK_BACKEND=true` launch.
Only the real `paymongo-webhook` Edge Function remains a stub.

The first privileged slice is now implemented: registration reservation and
the PayMongo-shaped mock payment adapter are deployed to the hosted dev
project. GCash simulates success, Maya stays pending, and card simulates a
decline. Match participants can also upload evidence directly to the private
`match-screenshots` bucket and submit a non-tied result for moderator review;
the database creates a 30-minute verification queue item transactionally.
An opposing team member or assigned tournament moderator can review the
private evidence and confirm the result, which completes the match and
resolves that queue item atomically. Match participants can instead open a
structured dispute; that marks the match disputed, notifies the other
participants, and creates a priority-1 moderator item with a 15-minute SLA.
Organizers can now lock paid entrants into deterministic single- or
double-elimination brackets. Byes advance automatically, verified results
route winners and losers to the correct downstream slots, and the grand final
completes the tournament.
Every played match completion now snapshots its paid participants into an
idempotency ledger, adds one win or loss without replacing historical totals,
recomputes ranks from the active thresholds, and emits a rank-up notification
when a player crosses a tier. Automatic bracket byes do not affect ranks.
The same completion pipeline evaluates all seven configured achievement
badges. Tournament-only rules wait for a completed bracket, incomplete match
history cannot earn Untouchable, and unique badge awards make retries safe.
Tournament completion now also creates at most one prize disbursement for the
terminal bracket winner. The winning captain's saved GCash/Maya destination
selects the method; missing setup produces a retry-safe notification instead
of blocking completion. Hosted dev uses deterministic mock settlement until
real PayMongo payout credentials and APIs are activated.
Postgres now checks moderator SLAs every minute. Overdue pending work is
atomically marked escalated, raised to priority 1, routed to the tournament
organizer, written to the audit log, and announced to both organizer and
original moderator. `FOR UPDATE SKIP LOCKED` and status transitions make
scheduled and manual runs concurrency-safe and idempotent.
Player profiles now load career totals, completed captain payouts, and the five
most recent completed paid tournaments from a public aggregate RPC. Money stays
in centavos through Postgres and converts to pesos only in the Flutter adapter;
placement is derived from the terminal winner and recorded elimination order.
Captain-issued team invitations now persist in `team_invitations` through the
authenticated `team-invite` Edge Function. The locked command verifies current
captain ownership, rejects invalid targets, is idempotent for an existing
pending invite, and creates one push-backed recipient notification. The
Flutter `TeamsRepo.invite` adapter is connected. Migration
`0037_team_invitations.sql` is deployed to hosted dev.
The hosted `team-invite` function uses `verify_jwt = false` so Firebase
third-party bearer tokens reach the function, which validates them through
`current_user_id()` before any service-role write. Its live unauthenticated
probe returns the function's expected `401 unauthorized` response.
Migration `0038_team_invitation_responses.sql` adds recipient-only,
idempotent accept/decline. Acceptance adds one roster membership; decline does
not; expired invitations cannot join; all outcomes resolve the related
notification. The Flutter inline actions and resolved-state UI pass focused
widget tests. Hosted `team-invite-respond` is deployed with the same internally
validated `verify_jwt = false` gateway pattern, and its live unauthenticated
probe returns the expected `401 unauthorized` response.
Captains can now recruit through either a direct username dialog or a filtered
Player Search result. `team-invite` accepts exactly one target identifier,
resolves case-insensitive usernames server-side, and sends both paths through
the same captain-authorized, duplicate-safe invitation transaction. The
updated function is deployed, its unauthenticated probe still returns the
expected internal `401 unauthorized`, and focused widget/contract tests cover
the new actions.
Team identity editing, member removal, captain transfer, and member leave now
run through the deployed `team-manage` command and locked `manage_team` RPC.
The transaction keeps ownership and roster roles synchronized, requires a
captain to transfer before leaving, and blocks roster shrinkage during locked
or live tournaments. The `/team` shortcut now resolves the signed-in player's
hosted team instead of the old mock ID. Migration
`20260801061750_team_management_commands.sql` is deployed and verified with a
rollback-only hosted transaction.

The P2 wallet is now backed by `get_my_wallet(integer)` and a player-owned
financial ledger. The app shows completed prizes, paid entry fees, pending
prizes, net tournament cash flow, and filterable transaction history at
`/wallet`; it explicitly does not present these external charges/payouts as a
stored balance. Disbursements now persist an immutable `recipient_user_id`, so
captain transfers cannot move historical winnings to a different player.
Migration `20260801083525_wallet_transaction_history.sql` is deployed; a
rollback-only hosted player query returns the expected ₱650 entry fees, ₱184
prizes, and four ledger rows.
Account deletion now has exact `DELETE` confirmation, a cancellable 30-day
grace period, and review holds for captains or unsettled payouts. The daily
service worker permanently removes the Firebase identity and direct
operational PII, pseudonymizes the retained profile, and keeps a one-way
identity tombstone plus financial/tournament history for up to five years.
Migration `20260801123403_account_deletion_retention.sql` and both deletion
functions are deployed to hosted dev with internal Firebase/service-role
authentication. The hosted project has no due requests, so no real account
was deleted while verifying the schedule and authorization boundary.
Player profiles now include a gallery-backed avatar picker. JPEG, PNG, and
WebP images are resized by the picker, rejected above 2 MiB, uploaded to the
public `avatars` bucket at the stable `<profile UUID>/avatar` path, and saved
to `profiles.avatar_url` with a cache-busting version. Storage policies allow
the current Firebase/Supabase identity to replace only its own object.
Migration `20260801141848_avatar_storage.sql` is deployed to hosted dev, and a
missing-object probe confirmed the public bucket endpoint without writing
test data.
Tournament detail sharing now opens the native iOS/Android share sheet with a
validated `labaan://tournament/<id>` URL. `app_links` is initialized before
the first frame, accepts only the tournament scheme/host and a constrained ID,
normalizes cold-start and foreground events into the existing GoRouter route,
and ignores OAuth or malformed links. Both native targets compile, and an iOS
simulator smoke test opened the hosted Cavite Open Qualifier directly from its
custom-scheme URL.
Browse now has a real tournament-title search field with a 350 ms debounce,
immediate keyboard submission, clear action, and query-aware empty state. The
filter is passed to the hosted PostgREST query rather than applied to a loaded
page, and `20260801155157_tournament_title_search.sql` adds an
`extensions.pg_trgm` GIN index for case-insensitive substring matching. A
hosted read-only “cavite” query returned exactly Cavite Open Qualifier.
The Home Host and Support quick actions now open real destinations. Host keeps
organizer provisioning and operations in the planned separate web app while
showing onboarding requirements, organizer-specific help, and a safe link to
the official GAB registry. Support routes players to the live connected-account,
payout, notification, competition, privacy, and terms flows. No placeholder
email address or unpublished organizer portal is presented as operational.
Typography now uses bundled Chakra Petch, IBM Plex Sans, and IBM Plex Mono
assets instead of runtime `google_fonts` fetching. Their OFL texts are packaged
and registered with Flutter's license registry. Visually reviewed Host and
organizer-context Support baselines provide the first deterministic golden
regressions.
CI now enforces a repository-owned 59% line-coverage floor after
`flutter test --coverage`. The checked-in Dart parser rejects missing or
malformed LCOV data and reports exact covered/total counts; the current
baseline is 59.82% (3,751/6,270 lines).
The interactive Google account-selection and sign-in flow has been manually
smoke-tested successfully on both iOS and Android devices.
Signed-in installations now register and refresh FCM tokens with Supabase.
Notification inserts fan out through a preference-aware durable queue, and the
hosted `push-deliver` worker runs every minute using encrypted Vault-held
service credentials. Scheduled invocations are returning HTTP 200, and the
APNs authentication key is uploaded in Firebase. After disabling NextDNS, the
physical iPhone registered an active `ios`/`dev` FCM token with Supabase. The
first queued smoke-test send failed with `401:THIRD_PARTY_AUTH_ERROR` because
Firebase's development slot used production-only key `65X4TWLB37`. The slot
now uses the team's sandbox key `7Q4KA53S2U`; the production slot remains on
`65X4TWLB37`. A fresh physical-device smoke test was accepted by FCM and marked
`sent` on the first worker attempt, and its foreground banner was confirmed on
the iPhone. A second test on the release-mode Dev build confirmed background
delivery and that tapping the notification opens `/notifications`. The earlier
apparent cold-start freeze was the iOS debug build relaunching without Flutter
tooling attached, not a notification-routing failure.
See [`docs/IMPLEMENTATION_CHECKLIST.md`](docs/IMPLEMENTATION_CHECKLIST.md) for
the maintained cross-project backlog.

---

## TL;DR

`flutter run --flavor dev` on iOS → use Google or phone to authenticate
through the Dev Firebase app → the app creates or loads the mapped
Supabase profile and opens real data through RLS. The seed includes users,
teams, tournaments, registrations, matches, payments, notifications,
moderation, and a completed payout.

The hosted development Supabase URL and publishable client key are the normal
defaults. Use `config/backend.json` only to override them for another project.
Use `--dart-define=USE_MOCK_BACKEND=true` only when intentionally developing
against fixtures. No provider edits are needed.

iOS has shared `dev` and `prod` schemes. Dev uses
`com.labaan.labaan-dev`, displays as **Labaan Dev**, has Firebase app
`1:77063889783:ios:c5cf4601ed1cfd63ea3772`, and is the required scheme for
simulator/device testing. Prod keeps `com.labaan.labaan` and is selected
explicitly for production runs or archives.
There is no phone bypass: Continue with phone always opens the OTP screen and,
with backend credentials present, uses Firebase verification.

The sibling backend's local Supabase stack is seeded and can be rebuilt with
`npm run db:reset`. The hosted development project
`xmbfzcgejpzvgrfvvfyi` also has migrations through
`20260801061750_team_management_commands.sql` and the same synthetic seed. The
current command functions, scheduled queue escalation, and scheduled push
delivery are deployed.

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
- go_router + locally bundled Chakra Petch, IBM Plex Sans, and IBM Plex Mono.
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
    ├─ MockRepository (tests/explicit mode) ── mock_repos.dart + fixtures.dart
    └─ SupabaseRepository (normal app runs) ── supabase_repos.dart + Lb.client
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
| §11 · Pre-signed URL for screenshots | `SupabaseResultsRepo.uploadScreenshot` uploads directly to the private `match-screenshots` bucket |
| §12 · Legal / regulatory checklist | Documented in README + memory |

---

## Tests

```bash
flutter test                    # 105 passing
flutter analyze                 # clean
dart format --set-exit-if-changed lib test tool   # clean
dart run tool/check_coverage.dart             # 59.82% ≥ 59.0%
```

CI runs all three on every push / PR to `main`.

---

## Known limitations / not done

- **Facebook authentication** — explicitly deferred pending product-scope and
  provider-setup decisions.
- **App icons + splash** — user is designing these.
- **Broader integration coverage** — Firebase phone auth, settings, payout
  preferences, and mock GCash registration are covered against hosted dev;
  moderator dispute resolution and real PayMongo flows are not.
- **PayMongo account activation** — the backend now has the correct
  transactional reservation/payment boundary and a deterministic dev adapter,
  but real Checkout/Payment Intent calls from the Edge Function, activated
  channels, and signed webhook processing still require merchant credentials.
- **iOS APNs delivery** — the app registers and refreshes FCM tokens,
  unregisters before sign-out, presents foreground notifications, and routes
  safe notification deep links. Migration `0034_push_notifications.sql` and
  the deployed `push-deliver` worker provide a preference-aware durable queue,
  bounded retry, and invalid-token cleanup. Firebase Edge secrets and the
  one-minute Vault-backed schedule are active and returning HTTP 200. The APNs
  development credential now uses sandbox key `7Q4KA53S2U` for Team ID
  `KK7GP4272M`, while production remains on `65X4TWLB37`. Device registration
  succeeds, and a fresh smoke-test delivery was marked `sent` on the first
  worker attempt after the credential fix. Foreground presentation, background
  delivery, and notification-tap routing to `/notifications` are verified on a
  physical iPhone using the release-mode Dev build.
- **Organizer/support operations** — direct case submission and organizer
  applications remain part of the planned separate organizer/moderator/admin
  web app. The player app currently provides accurate onboarding and live
  self-service destinations without inventing a support address or portal.

---

## Next work — options

**A. Field polish before alpha:**
- Phone OTP verification screen (real sign-in end-to-end).
- Bundled fonts + golden test suite.
- Report/block user flow.

**B. Continue backend integration:**
- Replace the PayMongo mock adapter with real Checkout/Payment Intent calls.
- Verify signed PayMongo webhooks and idempotent event processing.
- Implement moderator dispute resolution in the separate admin application.

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

Current state: every MVP screen is built and consumes Riverpod providers.
Normal launches use Firebase Auth plus the hosted Supabase backend; widget
tests remain fixture-backed.

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

# Hosted development Supabase on the iOS Dev target:
flutter run --flavor dev

# Seeded local Supabase (iOS simulator):
cd /Users/richtonehangad/NodeProjects/labaan-backend
npm run db:start
npm run db:reset
cd /Users/richtonehangad/FlutterProjects/labaan
flutter run --flavor dev \
  --dart-define-from-file=config/local_backend.json

# Intentional fixture mode:
flutter run --flavor dev --dart-define=USE_MOCK_BACKEND=true

# Production iOS archive:
flutter build ipa --flavor prod --release

# Tests:
flutter test

# Format + analyze (mirrors CI):
dart format --set-exit-if-changed lib test
flutter analyze
```
