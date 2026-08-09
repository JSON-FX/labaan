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
- [ ] Seed spendable development balances and expose Wallet v2 reads
- [ ] Replace per-registration payment with atomic Credit-funded entry/refund
- [ ] Add PayMongo Credit top-ups and Apple IAP verification
- [ ] Add tournament Victory Point rewards and Shop spending
