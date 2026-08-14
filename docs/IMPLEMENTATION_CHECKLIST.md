# Labaan implementation checklist

Last reviewed: 2026-08-09

This is the working delivery checklist across the Flutter player app and the
`labaan-backend` Supabase project. Checked items are usable against the hosted
development environment, not merely drawn as screens.

## P0 — playable paid-tournament loop

- [x] Firebase Google and phone authentication
- [x] Firebase UID → Supabase profile mapping
- [x] First-run username, region, and games setup
- [x] Hosted tournament browse/detail data
- [x] Transactional registration reservation
- [x] Mock PayMongo payment adapter for GCash, Maya, and card states
- [x] Payment event ledger and registration status mirroring
- [x] Replace mock adapter with PayMongo Checkout/Payment Intent API
- [x] Integrate the Flutter payment-method flow with PayMongo Checkout,
      an in-app WebView (with native-wallet/browser fallback), success/cancel
      app links, and webhook-authoritative status refresh
- [ ] Configure activated PayMongo channels (including online banking/QR Ph
      where approved for the merchant account)
- [ ] Verify PayMongo webhook signatures and replay protection
- [ ] Add real CAPTCHA/App Check token verification
- [x] Provision private match-screenshot Storage bucket and participant-only
      upload policies
- [x] Implement participant result submission with private screenshot evidence
      and a 30-minute moderator queue item
- [x] Implement opponent/moderator result verification with private evidence
      review and same-team/self-verification guards
- [x] Implement structured match disputes, participant notifications, and
      priority-1 moderator queue creation
- [x] Implement deterministic single/double-elimination tournament locking,
      bye handling, and automatic winner/loser bracket progression

## P1 — competition consequences

- [x] Idempotent rank recalculation after verified results, using paid
      tournament registrations and active rank thresholds
- [x] Idempotent evaluation of all seven achievement badges with award
      notifications after verified match/tournament results
- [x] Idempotent prize disbursement workflow with winning-captain payout
      validation, immutable event history, notifications, and dev adapter
- [x] Minute-by-minute queue SLA escalation with organizer routing, audit
      history, moderator/organizer notifications, and safe batching
- [x] Database-backed profile match record, completed payout earnings, and
      recent tournament placement/payout aggregates
- [x] Firebase Cloud Messaging token registration, preference-aware durable
      delivery queue, bounded retries, foreground presentation, and safe
      notification deep links

## P1 — teams

- [x] Team reads, creation data layer, and leaving a team
- [x] Team invitation persistence and authenticated command endpoint
- [x] Accept/decline invitation actions
- [x] Invite-by-username and player-search recruit actions
- [x] Team editing and captain controls

## P2 — remaining player experience

- [x] Editable account and notification settings
- [x] Google/phone account linking
- [x] GCash/Maya payout destination settings
- [x] Wallet and transaction history
- [x] Account deletion and retention workflow
- [x] Avatar upload/picker
- [x] Tournament sharing and deep links
- [x] Browse text search control
- [x] Host organizer-onboarding and Support self-service destinations
- [ ] Facebook authentication — deferred pending product/provider setup

## P3 — production readiness

- [ ] Replace draft privacy policy and terms with counsel-reviewed documents
- [ ] Final app icon and launch screen
- [x] Manual Google sign-in smoke test on iOS and Android devices
- [x] Upload an APNs authentication key to Firebase for iOS delivery
- [x] Verify foreground, background, and notification-tap delivery on a
      physical iPhone (device token registration succeeds after disabling
      NextDNS; Firebase's development slot now uses sandbox key `7Q4KA53S2U`,
      smoke tests were marked `sent` on the first worker attempt, foreground
      presentation works, and a background notification tap opens
      `/notifications` on the release-mode Dev build)
- [x] Configure `FCM_PROJECT_ID` / `FCM_SERVICE_ACCOUNT_JSON` in Supabase Edge
      secrets
- [x] Schedule and verify the service-authenticated `push-deliver` worker every
      minute using pg_cron, pg_net, and Vault
- [x] Bundle Chakra Petch and IBM Plex fonts locally, register their OFL
      licenses, and add visually reviewed Host/Support golden tests
- [x] Enforce a repository-owned 59% line-coverage floor in CI
- [ ] Separate organizer/moderator/admin web application

## Wallet economy migration

- [x] Preserve and publish the pre-wallet Flutter and backend checkpoints
- [x] Create dedicated `codex/wallet-economy` branches in both repositories
- [x] Define the append-only, double-entry `entry_credit` / `reward_point`
      ledger with stable internal codes, per-player and system accounts,
      idempotent posting, nonnegative player balances, RLS, and explicit grants
- [x] Add pgTAP coverage, regenerate database types, and document ledger
      invariants and posting rules
- [x] Seed spendable development balances, expose cursor-paginated Wallet v2
      reads, and replace the Flutter cash-flow wallet with dual balances and
      safe ledger activity
- [x] Replace per-registration payment for Wallet v2 tournaments with atomic
      Credit-funded entry/refund, balance-aware Flutter registration UI, and
      explicit insufficient-balance handling while preserving legacy PayMongo
- [x] Snapshot formula-based Victory Point reward rules, block entry until the
      rule is published, lock the capped final pool from confirmed competitors
      with the bracket transaction, and expose the formula in Flutter
- [x] Require Wallet tournaments to publish a minimum team count and explicit
      postpone/cancel policy; start underfilled brackets with deterministic
      byes or atomically issue exact Credit refunds when cancellation wins
- [x] Snapshot exact eligible team identities and rosters at bracket lock,
      freeze active paid rosters, and allocate the locked Victory Point pool to
      verified placement teams exactly once with deterministic tie and rounding
      rules; player wallet grants remain the next reward slice
- [x] Split verified team allocations equally across locked rosters, reject
      cross-team eligibility overlap, post exact balanced Victory Point grants
      once per player, and expose those rewards in Wallet activity
- [x] Bypass cash disbursement for Wallet tournaments, send one idempotent
      Wallet-linked Victory Point notification per positive grant, and show
      separate Victory Point earnings/reward history on player profiles while
      preserving legacy peso payout records
- [x] Add immutable server-controlled Credit-pack revisions with explicit
      PayMongo/App Store platform mappings, active-only client reads, no client
      pricing writes, development seed offers, and typed Flutter catalog access
- [x] Separate Credit top-up orders from legacy registration payments with
      immutable pack snapshots, constrained lifecycle/reconciliation fields,
      and a globally deduplicated purpose-aware provider-event receipt
- [x] Create PayMongo v2 Credit top-up checkouts from server-priced packs with
      exact order/session retry reuse, provider idempotency, URL allow-listing,
      daily purchase limits, and uncertainty reconciliation safeguards
- [x] Route signed PayMongo legacy and Hosted Checkout v2 events by explicit
      financial purpose through a global replay receipt before purpose-specific
      handling
- [x] Settle verified PayMongo paid top-ups atomically into exactly one balanced
      Credit grant; exact retries and same-payment sibling events reuse the
      original wallet transaction, while mismatched economics or payment IDs
      cannot issue value
- [x] Apply PayMongo failure, expiry, and refund lifecycle events atomically;
      full refunds post one compensating Credit reversal, while duplicate,
      partial, and spent-balance cases enter review and freeze Credit spending
- [x] Add server-priced PayMongo Credit top-ups for direct Android and web,
      with iOS-hidden entry points, in-app/native-wallet checkout fallback,
      same-tab web checkout, safe app links, and authoritative wallet refresh
- [x] Add a super-admin-only PayMongo top-up reconciliation view with provider,
      ledger, audit, mismatch, stale-order, and manual-review signals
- [x] Define provisional immutable streamer sponsor packages and create
      tournament-bound sponsor order/allocation/provider-event schemas
- [x] Add retry-safe organizer PayMongo sponsor checkout commands and Edge
      Function with ownership, draft-state, cap, URL, and idempotency checks
- [x] Route signed sponsor payments through the global provider receipt and
      settle exactly one immutable tournament allocation with no wallet credit
- [ ] Add Apple IAP purchase and server verification for iOS Credits
- [ ] Add tournament Victory Point rewards and Shop spending
