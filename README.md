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
flutter test              # 58 tests, unit + widget
flutter analyze           # should be clean
flutter run               # opens the app on your default device
```

The app automatically selects the real repositories when both Supabase
values are present. Copy the example without committing the resulting key
file:

```bash
cp config/backend.example.json config/backend.json
# Fill in the project's anon/publishable key, then:
flutter run --dart-define-from-file=config/backend.json
```

Without those defines, [`Lb.init()`](lib/core/data/supabase_client.dart) is a
no-op and the app runs entirely off in-memory fixtures.

For OAuth, add `com.labaan.labaan://login-callback` to the Supabase
Authentication **Additional Redirect URLs**. iOS and Android are already
registered to receive that callback.

During UI testing, **Continue with phone** signs into the development-only
seed account `@tonton26` and opens `/home` without showing an OTP. With
Supabase configured this is a genuine authenticated session, so the app reads
the seeded database through RLS; in mock mode it uses the matching fixture
identity. Set `BYPASS_PHONE_AUTH` to `false` to exercise real phone OTP.
Never deploy `supabase/seed.sql` or enable the bypass in production.

To run the app against the seeded local backend on an iOS simulator:

```bash
cd ../labaan-backend
npm run db:start
npm run db:reset

cd ../labaan
flutter run --dart-define-from-file=config/local_backend.json
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
│ (default; fixture-│ (real backend when   │
│ backed; instant)  │ credentials present) │
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
   `0019_mobile_profile_fields.sql`.
3. Enable the desired Auth providers and add the OAuth callback URL above.
4. Fill in `config/backend.json` and run with
   `--dart-define-from-file=config/backend.json`.

Table reads, Realtime, profile updates, team creation, and authentication
are connected. The backend's privileged registration, payment, result, and
dispute Edge Functions currently return `501 not_implemented`; those flows
will become live when their backend bodies land. Team invitations also have
no backend command yet.

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
```

### Not yet covered

- **Golden tests** — need Chakra Petch / IBM Plex bundled locally instead of
  fetched by `google_fonts` at runtime. Kept out of `test/` until that's
  wired.
- **Integration tests** against a real Supabase dev DB.
- **Coverage baseline** — CI uploads `coverage/lcov.info` but there's no
  threshold yet.

## CI

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs
`dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test
--coverage` on every push and PR to `main`.

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
