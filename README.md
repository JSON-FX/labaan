# Labaan

**Fight. Win. Rise.** — a Philippine e-sports tournament marketplace. Players
join bracketed tournaments across MLBB, Valorant, COD Mobile, PUBG, and
Tekken 8, pay individual entry fees, climb a 7-tier rank, and cash out prize
money via GCash / Maya / card.

This repo is the **player mobile app** (Flutter, iOS + Android). The admin
dashboard is a separate Next.js repo (spec §7.2).

Canonical spec: `Labaan_Project_Overview-v-1-3.pdf` (June 2026 v1.3,
Confidential). All screens and data models trace back to sections in that
document.

## Getting started

```bash
# Prereqs: Flutter stable, Xcode (for iOS), Android Studio (for Android).

flutter pub get
flutter test              # unit + widget tests
flutter analyze           # should be clean
flutter run --flavor dev  # iOS development/testing target
```

iOS has two shared schemes:

| Scheme | Bundle ID | Purpose |
|---|---|---|
| `dev` | `com.labaan.labaan-dev` | Simulator, device development, and integration tests |
| `prod` | `com.labaan.labaan` | Production runs and archives |

The Dev scheme uses its own registered Firebase iOS app and displays as
**Labaan Dev**, so it can coexist with production. Use `--flavor dev` for all
iOS development and testing; production must be selected explicitly with
`--flavor prod`.

Normal app launches use the hosted development Supabase project. Its
publishable client key is intentionally part of the app configuration;
database access is enforced by Row-Level Security.

To point the app at a different Supabase project, copy the example without
committing the resulting config file:

```bash
cp config/backend.example.json config/backend.json
# Fill in the other project's URL and anon/publishable key, then:
flutter run --flavor dev --dart-define-from-file=config/backend.json
```

In-memory fixtures are limited to automated tests or an explicit mock launch:

```bash
flutter run --flavor dev --dart-define=USE_MOCK_BACKEND=true
```

Firebase project `labaan-f3fa6` owns mobile authentication. Google and phone
sign-in use Firebase Auth; the resulting Firebase ID token is passed to
Supabase's third-party Auth integration. Supabase maps the Firebase UID to a
generated `profiles.id` UUID, so existing app tables and routes keep using
short database IDs.

**Google** and **Phone** are enabled under Firebase Console → Authentication,
and the SMS region policy allows the Philippines. For Android, the project's
debug SHA-1 and SHA-256 certificates are registered. The iOS Google client ID
and reversed-client URL scheme are included in the checked-in configuration.

There is no phone-auth bypass. **Continue with phone** always opens the OTP
screen and uses Firebase's real verification flow. Use Firebase test phone
numbers during development to avoid sending SMS.

Firebase Messaging registers each signed-in app installation with Supabase,
refreshes rotated tokens, unregisters before sign-out, shows foreground
updates, and opens allow-listed in-app routes from notification taps. The APNs
authentication key is uploaded in Firebase Console. The hosted backend already
has its Firebase service-account secrets and runs the trusted `push-deliver`
worker every minute. The development APNs slot uses the sandbox credential, and
physical-device smoke tests were accepted by FCM and marked `sent`. Foreground
presentation, background delivery, and tap routing to `/notifications` are
verified on the release-mode Dev build. Use release/profile mode when testing
cold notification launches on a physical iPhone; a detached debug build can
appear frozen when iOS relaunches it without Flutter tooling.

To run the app against the seeded local backend on an iOS simulator:

```bash
cd ../labaan-backend
npm run db:start
npm run db:reset

cd ../labaan
flutter run --flavor dev \
  --dart-define-from-file=config/local_backend.json
```

`config/local_backend.json` is ignored by Git and uses Supabase's standard
local development key. For an Android emulator, change its URL to
`http://10.0.2.2:54321`.

## Project layout

```
lib/
├── main.dart               # bootstrap + ProviderScope
├── app.dart                # go_router + MaterialApp.router
├── core/
│   ├── theme/              # colors · typography · theme
│   ├── domain/             # spec-locked enums: ranks · badges · tiers · roles · status
│   ├── data/               # models · repos (interfaces) · mock_repos · supabase_repos · fixtures · providers
│   └── widgets/            # SlantButton · RankHex · LbCard · GameArt · SectionLabel · ...
└── features/
    ├── identity/           # onboarding · setup · profile
    ├── registration/       # register · payment result
    ├── home/               # home feed
    ├── browse/             # marketplace browse
    ├── compete/            # my tournaments · result submission · dispute
    ├── tournament/         # tournament detail · bracket view
    ├── team/               # team management · player search
    ├── leaderboard/        # season leaderboard (players + teams)
    ├── system/             # notifications · notification prefs · settings · rank-up
    └── shell/              # bottom-tab shell (Home · Browse · Compete · Ranks · Profile)

supabase/                    # legacy mobile-era schema; do not deploy

test/
├── unit/                   # domain math (ranks, tier fees, formatPeso, models)
└── widget/                 # per-screen smoke + interaction tests

docs/adr/                   # architecture decision records
```

## Dependency direction

```
Screens (ConsumerWidgets)
    ↓ ref.watch
Riverpod providers (lib/core/data/providers.dart)
    ↓
Repository interfaces (lib/core/data/repos.dart)
    ↓
┌───────────────────┬──────────────────────┐
│ MockRepository    │ SupabaseRepository   │
│ (tests / explicit │ (default for normal  │
│ mock mode)        │ app launches)        │
└───────────────────┴──────────────────────┘
```

Every screen depends on a **repository interface**, never on Supabase
directly. [providers.dart](lib/core/data/providers.dart) selects mock or
Supabase implementations from the runtime configuration; no source edit is
needed.

## Backend connection

The authoritative database and Edge Functions live in the sibling
`../labaan-backend` project. Its schema uses `profiles`, normalized join
tables, integer centavos, and RLS; the Dart adapters translate those shapes
into the app's UI models.

1. In `../labaan-backend`, start/reset Supabase or push its migrations to
   project `xmbfzcgejpzvgrfvvfyi`.
2. Apply all backend migrations, including
   `0022_firebase_identity_bridge.sql`.
3. In Supabase Authentication → Third-Party Auth, register Firebase project
   `labaan-f3fa6`.
4. Enable Google and Phone providers in Firebase Authentication.
5. Run the app normally. Use `config/backend.json` only to override the
   checked-in hosted development configuration.

Table reads, Realtime, profile updates, team creation, Firebase
authentication, registration reservation, and the development PayMongo mock
are connected. Captain-issued team invitations now persist through the
authenticated `team-invite` command and create one recipient notification.
Invitees can accept or decline inline; acceptance adds roster membership
atomically, and both outcomes persist their resolved notification state.
Captains can edit team identity, remove members, or transfer captaincy;
members can leave outside locked/live tournaments through the authenticated
`team-manage` command.
Players can also schedule permanent account deletion from Settings. A
30-day cancellation window precedes service-authenticated Firebase identity
removal and PII pseudonymization; captain/payout conflicts pause for review,
while retained financial and tournament records expire under the documented
five-year policy.
The Profile header includes a gallery avatar picker backed by the public
Supabase `avatars` bucket. Uploads are limited to JPEG, PNG, or WebP at 2 MiB,
and Storage policies restrict replacement to the signed-in player's object.
Tournament detail pages share `labaan://tournament/<id>` through the native
share sheet. iOS and Android register the `labaan` custom scheme, and the app
normalizes valid cold-start or foreground links into `/tournament/<id>` while
rejecting malformed, unrelated, or query-injected URLs.
Browse title search is debounced and runs against the hosted tournament query,
composing with game filters and cursor ordering. A trigram GIN index backs the
case-insensitive substring match instead of filtering only the visible page.
The Home Host and Support actions now open dedicated player-app destinations.
Host explains the separate organizer-app boundary, links to the official GAB
registry, and carries organizer context into Support. Support connects players
to existing account, payout, notification, competition, privacy, and terms
flows; direct support cases and organizer provisioning remain future web-app
work.

## Key spec facts baked in

- **7-rank ladder** (spec §4.1) — Recruit / Warrior / Elite / Champion /
  Legend / Mythic / Immortal, cumulative-wins thresholds live in
  [ranks.dart](lib/core/domain/ranks.dart).
- **4 tournament tiers** (spec §6.3) — Community ₱50 / 8%, Standard
  ₱100 / 10%, Premium ₱250 / 15%, Elite ₱500 / 15%. See
  [tournament_tier.dart](lib/core/domain/tournament_tier.dart).
- **7 achievement badges** (spec §4.4) — First Blood, Hat Trick,
  Elite Slayer, Community Champion, Big Game Hunter, Veteran, Untouchable.
- **5 user roles** (spec §3) — this app only serves the Player role. Super
  Admin / Tournament Organizer / Moderator surfaces live in the Next.js
  admin dashboard.
- **Moderator SLAs** (spec §3.1) — 15m disputes / 30m result verification /
  45m no-show / before-lock tournament review.

## Architecture decisions

Every load-bearing decision has an ADR under [docs/adr/](docs/adr/):

- [001 — Riverpod for state management](docs/adr/001-riverpod.md)
- [002 — Mock-first repositories](docs/adr/002-mock-first-repos.md)
- [003 — Flutter over React Native](docs/adr/003-flutter-over-react-native.md)
- [004 — Supabase + PayMongo + Upstash stack](docs/adr/004-supabase-stack.md)

## Testing

```bash
flutter test                            # everything
flutter test test/unit                  # domain math only
flutter test test/widget                # per-screen
flutter test test/widget/home_feed_test.dart   # one file
flutter test --coverage
dart run tool/check_coverage.dart       # requires at least 59% line coverage
```

Chakra Petch, IBM Plex Sans, and IBM Plex Mono are bundled under
`assets/fonts/`, so widget rendering is offline and deterministic. The Host and
Support destinations have visually reviewed baselines in `test/goldens/`;
refresh them intentionally with
`flutter test test/widget/golden_screens_test.dart --update-goldens`.

The real Firebase phone → Supabase profile bridge also has an opt-in simulator
test. Use a Firebase fictional phone number and code; never commit them:

```bash
flutter test integration_test/firebase_phone_auth_test.dart \
  -d <simulator-id> \
  --flavor dev \
  --dart-define=FIREBASE_TEST_PHONE=<e164-number> \
  --dart-define=FIREBASE_TEST_CODE=<six-digit-code>
```

### Not yet covered

- **Integration tests** against a real Supabase dev DB.

## CI

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs
formatting, analysis, `flutter test --coverage`, and the 59% coverage gate on
every push and PR to `main`.

## Legal / regulatory

Labaan is a **skill-based competition platform under GAB oversight**,
explicitly outside PAGCOR jurisdiction. Regulatory checklist (spec §12)
gates the following:

- SEC + BIR registration → before any revenue
- NPC registration + Privacy Policy → before user onboarding
- PayMongo merchant account → before payments go live
- GAB permit → before launch
- Prize-pool escrow legal review → before prize-pool feature
- Data Protection Officer designation → before launch

## License

Confidential. Do not distribute.
