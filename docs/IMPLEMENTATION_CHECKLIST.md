# Labaan implementation checklist

Last reviewed: 2026-07-30

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
- [ ] Replace mock adapter with PayMongo Checkout/Payment Intent API
- [ ] Configure activated PayMongo channels (including online banking/QR Ph
      where approved for the merchant account)
- [ ] Verify PayMongo webhook signatures and replay protection
- [ ] Add real CAPTCHA/App Check token verification
- [ ] Provision private match-screenshot Storage bucket and policies
- [ ] Implement result submission
- [ ] Implement opponent/moderator result verification
- [ ] Implement disputes and moderator queue creation
- [ ] Implement tournament locking and bracket progression

## P1 — competition consequences

- [ ] Rank recalculation after verified results
- [ ] Badge evaluation and award notifications
- [ ] Prize disbursement workflow
- [ ] Queue SLA escalation job
- [ ] Complete profile earnings and recent-tournament aggregates
- [ ] Firebase Cloud Messaging token registration and push delivery

## P1 — teams

- [x] Team reads, creation data layer, and leaving a team
- [ ] Team invitation persistence and command endpoint
- [ ] Accept/decline invitation actions
- [ ] Invite-by-username and player-search recruit actions
- [ ] Team editing and captain controls

## P2 — remaining player experience

- [x] Editable account and notification settings
- [x] Google/phone account linking
- [x] GCash/Maya payout destination settings
- [ ] Wallet and transaction history
- [ ] Account deletion and retention workflow
- [ ] Avatar upload/picker
- [ ] Tournament sharing and deep links
- [ ] Browse text search control
- [ ] Host and Support destinations
- [ ] Facebook authentication, if retained in product scope

## Production readiness

- [ ] Replace draft privacy policy and terms with counsel-reviewed documents
- [ ] Final app icon and launch screen
- [ ] Manual Google sign-in smoke test on iOS and Android devices
- [ ] Golden tests with bundled fonts
- [ ] Enforced test coverage threshold
- [ ] Separate organizer/moderator/admin web application

