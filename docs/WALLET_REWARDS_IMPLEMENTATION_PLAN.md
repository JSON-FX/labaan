# Wallet, tournament rewards, and Shop implementation plan

Status: In progress
Created: 2026-08-08
Applies to:

- Flutter player app: `/Users/richtonehangad/FlutterProjects/labaan`
- Supabase backend: `/Users/richtonehangad/NodeProjects/labaan-backend`

This is the living task tracker for replacing per-registration cash payments
and cash prizes with two non-cashable in-app currencies. Update this document
as decisions are made and check tasks only after their acceptance criteria pass.

The product name **Labaan** and both currency display names remain provisional.
Database codes, API values, and ledger types must therefore remain brand-neutral.

## 1. Working product decisions

- [x] Use two separate currencies with no conversion between them.
- [x] Purchased currency pays tournament entry fees.
- [x] Earned currency is awarded as tournament prizes and spent in the Shop.
- [x] Neither currency can be withdrawn, transferred, resold, or converted to
      pesos or another cash equivalent.
- [x] A player has one shared balance across supported platforms.
- [x] PayMongo can fund the purchased currency on the website and direct
      Android APK, subject to written merchant approval.
- [x] Apple IAP can fund the purchased currency on iOS, subject to App Review.
- [x] A tournament does not need to fill every bracket slot; it may start at a
      configured minimum and assign byes.
- [x] Tournament rewards may scale with confirmed entrants, but the complete
      formula or tier schedule must be published before registration opens.
- [x] Streamers do not receive or manually transfer prize currency.
- [x] Streamers sponsor a locked tournament reward allocation by paying Labaan
      through the separate Host web portal.
- [x] Labaan awards prize currency directly to verified winners.
- [x] The initial Shop excludes GCash vouchers, wallet vouchers, gift cards,
      cash equivalents, user-to-user resale, and randomized loot boxes.

### Provisional currency names

| Purpose | Recommended display name | Stable internal code | Purchasable | Earned | Spendable on |
|---|---|---|---:|---:|---|
| Tournament entry | Credits | `entry_credit` | Yes | Optional promotions only | Tournament entry and approved Labaan services |
| Tournament prize | Victory Points | `reward_point` | No | Yes | Shop |

Alternative display names can be adopted later without changing stored codes:

- Credits: Labaan Credits, Entry Credits, Play Credits
- Victory Points: Reward Points, Shop Points, Champion Points

Avoid `labaan_coin` in schemas, enums, API contracts, ledger types, and App
Store product identifiers because the brand and display terminology may change.

## 2. Non-negotiable economy rules

### Entry Credits

- [x] Credits never expire.
- [x] Credits cannot be withdrawn or transferred.
- [x] Credits cannot be converted into Victory Points.
- [x] Credits are credited only after an authoritative provider confirmation.
- [x] Tournament cancellation returns Credits through a compensating ledger
      transaction rather than editing the original debit.
- [x] Provider refunds and reversals remove the corresponding Credits through a
      new ledger transaction and create a review state if the balance is short.
- [ ] Promotional Credits, if introduced, are source-tagged and follow an
      explicit refund and expiration policy separate from purchased Credits.

### Victory Points

- [ ] Victory Points cannot be purchased into a player wallet.
- [ ] Victory Points cannot be withdrawn, transferred, or converted to Credits.
- [ ] Victory Points cannot buy cash equivalents.
- [ ] Victory Points are issued only by a verified tournament result,
      platform promotion, sponsor allocation, or audited admin adjustment.
- [ ] Shop refunds restore Victory Points through a compensating transaction.
- [x] Every tournament award is idempotent per tournament, placement, and user.

### Tournament rules

- [x] Every Wallet tournament declares a minimum and maximum team count.
- [x] Registration closing behavior is explicit: start, postpone, or cancel.
- [x] Underfilled elimination brackets assign byes using published seeding or a
      transparent randomized draw.
- [x] Reward rules are snapshotted before registration opens and cannot be
      changed after the first confirmed entrant without cancelling/reopening.
- [x] The final reward pool locks when registration closes.
- [ ] Paid entry fees do not directly create withdrawable money or cash prizes.
- [ ] Match results are determined by player skill and use the existing result,
      evidence, verification, dispute, and moderator workflows.

## 3. Tournament reward models

Each tournament chooses one or more approved funding modes.

### A. Entry-scaled reward

The prize amount is determined from confirmed entrants using a formula or tier
schedule published before registration opens.

Example formula:

```text
final_reward_pool = confirmed_entrants * reward_points_per_entrant
```

Example tier schedule:

| Confirmed entrants | Victory Point pool |
|---:|---:|
| 4-7 | 100 VP |
| 8-11 | 200 VP |
| 12-16 | 300 VP |

- [x] Choose formula-based rewards for the MVP; the per-competitor rate and cap
      remain approved tournament configuration rather than a hard-coded global
      conversion rate.
- [ ] Define minimum entrants, maximum entrants, reward caps, and rounding.
- [x] Calculate from confirmed entrants at registration lock, not reservations
      or pending top-ups.
- [x] For team tournaments, calculate from confirmed eligible teams unless the
      published rules explicitly use roster size.

### B. Organizer-sponsored boost

The streamer purchases a fixed reward allocation for one tournament:

```text
Streamer -> Host web portal -> PayMongo -> Labaan
                                      -> locked tournament reward allocation
                                      -> verified winners receive VP
```

- [ ] Define sponsor packages, pricing, limits, and cancellation terms.
- [ ] Accept sponsor payment only through the Host web portal.
- [ ] Create a pending sponsor order before opening PayMongo Checkout.
- [ ] Lock the allocation only after a signed PayMongo webhook confirms payment.
- [ ] Do not credit the streamer's personal Victory Point balance.
- [ ] Prevent the organizer from changing recipients or manually transferring
      the allocation after the tournament locks.
- [ ] On cancellation, refund the original payment method or issue restricted
      Host Credit according to the published policy.

### C. Platform or brand sponsorship

- [ ] Allow an audited admin workflow to allocate a promotional reward budget.
- [ ] Store sponsor identity, campaign reference, funding source, and cap.
- [ ] Keep promotional awards distinguishable in the ledger and reporting.

### Prize distribution

- [ ] Choose default placement percentages or fixed placement amounts.
- [x] Ensure integer rounding produces exactly the locked total; assign the
      division remainder to first place and roll an unavailable third-place
      bucket into first place.
- [x] Split each team allocation equally across its locked eligible roster;
      assign indivisible remainder units to the locked captain first, then
      remaining members by stable user ID.
- [ ] Define how disqualified, removed, substituted, or banned players affect
      eligibility.
- [ ] Display the locked total and distribution before the tournament starts.

## 4. Platform payment matrix

| Surface | Credit funding | Tournament entry | Shop | Host sponsorship |
|---|---|---:|---:|---:|
| iOS App Store app | Apple IAP | Yes | Digital-only MVP | No in-app purchase flow; use Host web portal independently |
| Direct Android APK | PayMongo, including approved GCash channel | Yes | Yes | Host web portal |
| Flutter web/PWA | PayMongo | Yes | Yes | Host web portal |
| Future Google Play build | Google Play Billing unless an applicable exception is approved | Yes | Policy-dependent | Host web portal |
| Host/admin web app | PayMongo sponsor checkout | Organizer tools | Catalog/admin only | Yes |

- [ ] Offer equivalent Credit packs through Apple IAP when externally funded
      Credits can be consumed on iOS.
- [ ] Do not advertise or link to PayMongo/GCash top-ups in the Philippine iOS
      app unless current App Store rules explicitly permit it.
- [ ] Make provider availability server-configurable and platform-aware.
- [ ] Keep one shared balance while retaining provider/source metadata for
      refunds, reconciliation, fraud review, and reporting.

## 5. Backend target architecture

### Ledger and wallet tables

Proposed brand-neutral entities:

- `wallet_currencies`
- `wallet_accounts`
- `wallet_transactions`
- `wallet_entries`
- `topup_orders`
- `tournament_reward_rules`
- `tournament_reward_allocations`
- `tournament_reward_grants`
- `organizer_sponsor_orders`

Proposed transaction types:

- `topup`
- `entry_fee`
- `entry_refund`
- `provider_reversal`
- `reward_allocation`
- `reward_grant`
- `shop_purchase`
- `shop_refund`
- `admin_adjustment`

Requirements:

- [x] Use integer units only; do not store wallet quantities as floating point.
- [x] Make ledger transactions and entries append-only.
- [x] Require entries in each ledger transaction to balance to zero.
- [ ] Use unique idempotency keys and unique provider transaction references.
- [x] Prevent normal operations from producing a negative player balance.
- [x] Lock affected wallet accounts during debits to prevent double-spending.
- [x] Do not expose direct balance or ledger mutation to clients.
- [x] Keep privileged functions out of exposed schemas when practical.
- [ ] Prefer `security invoker`; justify every `security definer`, set an empty
      search path, check the actor explicitly, and revoke default execution.
- [x] Enable RLS on every exposed table and add ownership-specific policies.
- [x] Add explicit Data API grants only where required; RLS and API exposure
      are separate controls.
- [x] Run Supabase database advisors before finalizing migrations.
- [x] Regenerate and reconcile database types, contracts, API docs, and tests.

### Read APIs

- [x] Replace the current cash-flow `get_my_wallet` response with Wallet v2.
- [ ] Add safe provider pending-state summaries when top-ups exist.
- [x] Return both balances and cursor-paginated settled activity.
- [x] Include currency and transaction type on every activity entry.
- [x] Never return webhook payloads, full provider details, or another user's
      financial activity.

### Command APIs

Proposed commands/Edge Functions:

- `topups-create-checkout`
- `iap-verify-transaction`
- `registration-enter-with-credits`
- `registration-cancel`
- `tournament-rewards-lock`
- `tournament-rewards-award`
- `organizer-sponsor-checkout`
- `shop-order-create`

- [ ] Define zod contracts and stable error codes before implementing clients.
- [ ] Require client-generated idempotency keys for every value-moving command.
- [ ] Keep provider redirects advisory; only signed webhooks/server verification
      may settle top-ups or sponsor payments.
- [ ] Rate-limit sensitive commands and add real CAPTCHA/App Check verification.

## 6. Migration from the current model

The current implementation ties PayMongo payments directly to registrations,
adds payment proceeds to a peso prize pool, performs external prize
disbursement, and presents a cash-flow wallet rather than stored balances.

- [x] Preserve all existing payment, payment-event, disbursement, registration,
      and payout records as immutable legacy history.
- [x] Do not rewrite old money values as Credits or Victory Points.
- [x] Add an explicit legacy/new economy marker to tournaments.
- [x] New-economy tournaments use Credit fees and reward rules.
- [ ] Existing tournaments finish under their original model or are cancelled
      and reconciled before migration.
- [x] Stop peso prize-pool accrual for new-economy tournaments.
- [x] Replace payout-account requirements with reward-wallet eligibility for
      new-economy tournaments.
- [ ] Update bracket, ranking, and badge queries to use confirmed registration
      state instead of assuming `payment_status = 'paid'` forever.
- [ ] Retire payout settings, peso earnings, and cash-prize language only after
      all legacy obligations are settled.
- [x] Keep old PayMongo registration checkout code behind a legacy path until
      migration is complete, then remove it in a dedicated cleanup change.

## 7. Phased delivery tracker

### Phase 0 - Decisions, approvals, and work isolation

- [x] Safely checkpoint the current dirty Flutter PayMongo branch.
- [x] Safely isolate the backend's current uncommitted shared-function changes.
- [x] Start wallet work on new `codex/` branches after those checkpoints.
- [ ] Finalize the open decisions in section 10.
- [x] Write product-draft player tournament rules and organizer sponsorship
      terms and expose them in the app; counsel review remains required.
- [ ] Request written PayMongo approval for player top-ups and organizer
      sponsorship payments under the complete non-cashable model.
- [ ] Confirm the iOS model and contest wording with App Review/legal counsel.

Exit criteria: current work is recoverable, product rules are internally
approved, and development may continue behind disabled feature flags without
depending on production provider approval.

### Phase 1 - Smallest vertical slice: seeded Credits to registration

- [x] Create wallet ledger migrations and pgTAP tests.
- [x] Seed development Credit and Victory Point accounts.
- [x] Implement authenticated wallet summary/history reads.
- [x] Implement atomic Credit-funded tournament registration.
- [x] Implement Credit refunds for cancellation.
- [x] Update generated backend types and contracts.
- [x] Update Flutter models and repositories.
- [x] Replace the payment-method registration UI with balance, cost, and
      post-entry balance.
- [x] Show insufficient-balance handling without a real top-up provider.
- [x] Update Flutter wallet UI to show both balances and ledger activity.

Exit criteria: a seeded development user can enter a tournament exactly once,
Credits cannot be double-spent, cancellation restores Credits, and the Flutter
wallet shows the authoritative results.

### Phase 2 - Reward calculation and Victory Point awards

- [x] Add immutable reward-rule snapshots to tournaments.
- [x] Support underfilled brackets with minimum counts and byes.
- [x] Calculate and lock the final reward pool at registration close.
- [x] Implement idempotent placement/team reward allocation from verified
      bracket topology and immutable team/roster snapshots.
- [x] Issue Victory Points only after verified tournament completion through
      balanced, immutable, idempotent per-player ledger grants.
- [x] Replace cash-payout notifications and profile aggregates while retaining
      explicit legacy payout fields and history.
- [x] Add reward-grant activity to Wallet v2 history and Flutter presentation.

Exit criteria: retrying completion cannot duplicate rewards, the awarded total
equals the locked pool, and every recipient is derived from the locked eligible
roster and verified result.

### Phase 3 - PayMongo Credit top-ups

- [x] Add immutable, server-controlled, provider/platform-aware Credit-pack
      configuration and typed Flutter catalog access. Development prices are
      placeholders; approved production pack sizes and prices remain open.
- [x] Add distinct top-up order and global purpose-aware provider-event
      schemas with immutable economic snapshots, unique idempotency/provider
      references, constrained lifecycles, RLS, and reconciliation fields.
- [x] Implement retry-safe top-up order creation and PayMongo v2 Checkout with
      server-owned economics, direct-platform validation, allow-listed return
      and hosted URLs, durable session reuse, daily limits, and a reconciliation
      cutoff before provider idempotency expires.
- [x] Route signed legacy and Hosted Checkout v2 webhook events through one
      global purpose-aware receipt, requiring top-up purpose/order/session and
      provider environment agreement before purpose-specific handling.
- [x] Credit only after the stored signed paid Payment matches the immutable
      order amount/currency; settle order, receipt, and one balanced Credit
      grant atomically with exact- and sibling-event idempotency.
- [x] Handle pending, failure, expiry, refund, compensating reversal, and
      duplicate capture; partial/underfunded reversals enter review and freeze
      purchased-Credit spending without falsifying ledger value.
- [x] Reuse the Flutter in-app checkout and native-wallet fallback on direct
      Android; add web checkout behavior.
- [x] Refresh the wallet after redirect without trusting redirect status.
- [x] Add a super-admin-only, payload-free reconciliation and audit view that
      compares top-up orders, provider processing, and ledger movements.

Exit criteria: one PayMongo test payment creates exactly one Credit grant even
under duplicate delivery, and refund/reversal behavior is proven.

### Phase 4 - Streamer sponsorship

- [x] Define provisional development sponsor packages, immutable revisions,
      per-package limits, a 1,000 VP tournament cap, eligibility, attribution,
      and refund-to-original-method policy pending provider/legal approval.
- [x] Create organizer sponsor-order, provider-event subject, and immutable
      tournament sponsor-allocation schemas with RLS and audit history.
- [x] Implement sponsor orders and PayMongo checkout on the Host web portal.
- [x] Settle signed PayMongo sponsor payments into exactly one immutable
      tournament-bound allocation without crediting the organizer wallet.
- [x] Combine entry-scaled, organizer, platform, and brand allocations without
      exceeding configured caps.
- [x] Implement cancellation refund/Host Credit rules (original-method refund
      for MVP; restricted Host Credit remains deferred).
- [x] Display sponsor attribution and final locked pool to players.

Exit criteria: a streamer can fund a fixed boost without receiving spendable
Victory Points, and only verified winners can receive the locked allocation.

### Phase 5 - Apple IAP (deferred from the current MVP)

The approved implementation direction currently has no Apple IAP. iOS can use
cross-platform balances earned or funded on supported direct platforms, while
top-up and Shop entry points remain hidden. Keep these tasks as a future option
only if the distribution and App Review strategy changes.

- [ ] Configure consumable Credit products in App Store Connect.
- [ ] Add Flutter IAP purchase and pending-state UI.
- [ ] Verify transactions server-side against the configured product mapping.
- [ ] Add App Store Server Notifications and replay protection.
- [ ] Handle refunds, revocations, family/account edge cases, and deficits.
- [ ] Sync balances across iOS, direct Android, and web accounts.
- [ ] Add contest rules in-app and App Review notes explaining both currencies.

Exit criteria: sandbox/TestFlight purchase, cross-platform spend, duplicate
verification, and refund/revocation tests pass.

### Phase 6 - Shop MVP

- [x] Define the provisional development catalog, exclusions, platform
      visibility, refund boundary, and fulfillment ownership gates.
- [x] Create product, inventory, order, order-item, fulfillment, secret, and
      entitlement models with immutable economic snapshots.
- [x] Implement atomic, idempotent Victory Point purchase and inventory
      reservation with server-owned pricing and per-user/platform checks.
- [x] Implement leased internal-entitlement fulfillment and atomic pre-delivery
      Shop cancellation with compensating Victory Point refunds.
- [x] Build direct Android/web Shop browse, product detail/confirmation,
      Victory Point checkout, order history/status, and eligible cancellation UI.
- [x] Enforce direct Android/web-only catalog visibility in server-owned offers;
      iOS has no Shop entry point.
- [ ] Obtain authorization for third-party game items, imagery, and codes.

Exit criteria: a Victory Point purchase cannot overspend or oversell inventory,
fulfillment is auditable, and refunding creates a compensating ledger entry.

### Phase 7 - Admin, rollout, and legacy retirement

- [ ] Build wallet, top-up, sponsor, reward, and Shop operational dashboards.
  - [x] Add a web-only super-admin foundation with business KPIs, searchable
        actionable reconciliation records, risk resolution, and audited wallet
        adjustments. Provider retry and fulfillment controls remain.
- [x] Require reasons and immutable audit entries for admin adjustments.
- [x] Add fraud, velocity, duplicate-account, refund-deficit, and abuse review.
- [x] Add economy reporting for issuance, spending, outstanding liability,
      redemption cost, and provider reconciliation.
  - [x] Add the super-admin reporting foundation for account integrity, provider
        and sponsor reconciliation, reward/Shop drift, currency liability, and
        daily wallet flows; redemption-cost inputs and operator UI remain.
- [x] Roll out behind environment and platform feature flags.
- [x] Preserve and pseudonymize Wallet, provider, sponsor, reward, Shop, and
      adjustment records during account deletion; pause unsettled work for
      review and freeze retained balances without rewriting the ledger.
- [ ] Complete local, hosted development, PayMongo test, StoreKit sandbox,
      TestFlight, and physical-device pilots.
- [x] Migrate organizer-facing new tournament drafts to the wallet economy;
      retain service-only legacy maintenance until obligations are settled.
- [ ] Settle all legacy cash-payment and payout obligations.
- [ ] Remove legacy UI and endpoints in a separately reviewed cleanup.
- [ ] Update `docs/IMPLEMENTATION_CHECKLIST.md` after every completed slice.

## 8. Verification checklist for every value-moving slice

- [ ] pgTAP tests cover ledger conservation, RLS/grants, authorization,
      idempotency, insufficient balance, concurrency, and compensating entries.
- [ ] Edge Function tests cover validation, auth, provider failure, replay, and
      stable response/error contracts.
- [ ] Contract tests and contract build pass.
- [ ] Full local database reset succeeds.
- [ ] Full database test suite passes.
- [ ] Edge Function test suite passes.
- [ ] Generated database types match migrations.
- [ ] Supabase advisors report no new errors.
- [ ] Flutter formatter and analyzer pass for affected files.
- [ ] Flutter unit and widget tests pass for affected flows.
- [ ] Relevant integration tests pass on the intended platform.
- [ ] Hosted behavior is verified without trusting client redirects.
- [ ] Documentation and this tracker are updated.

## 9. Required end-to-end scenarios

- [x] Seeded Credit balance -> tournament entry -> correct remaining balance.
- [x] Two simultaneous entry attempts -> only one successful debit/registration.
- [x] Underfilled bracket at or above minimum -> fair byes and successful start.
- [x] Below-minimum tournament -> cancellation and exact Credit refunds.
- [x] Entry-scaled pool -> final pool based only on confirmed entrants.
- [ ] Streamer sponsor payment -> locked allocation -> winner awards.
- [x] Duplicate tournament-completion event -> no duplicate Victory Points.
- [x] PayMongo payment -> duplicate webhooks -> one Credit grant.
- [ ] Android/web PayMongo top-up -> iOS login -> balance available -> entry.
- [ ] Apple sandbox top-up -> Android/web login -> balance available -> entry.
- [x] Provider refund after partial spend -> deterministic reversal/review state.
- [ ] Victory Point Shop order -> inventory reservation -> fulfillment.
- [ ] Shop cancellation/refund -> compensating Victory Point credit.
- [ ] Unauthorized client attempts direct balance/ledger changes -> denied.

## 10. Open product decisions

- [ ] Final display name and symbol for `entry_credit`.
- [ ] Final display name and symbol for `reward_point`.
- [ ] Credit pack sizes and platform pricing.
- [ ] Whether one Credit is presented as equivalent to one peso on PayMongo
      channels or deliberately uses package-only pricing.
- [ ] Default minimum participant/team counts for each bracket size.
- [ ] Whether entry fees are per player or per team for team tournaments.
- [ ] Entry-scaled reward formula or tier schedule.
- [ ] Default placement distribution and rounding rules.
- [ ] Team reward distribution and substitute eligibility.
- [ ] Streamer sponsor packages and cancellation/refund rules.
- [ ] Platform-funded and brand-funded promotional budget policy.
- [ ] Initial Shop catalog and fulfillment partners.
- [ ] Whether physical merchandise is included at MVP or deferred.
- [ ] Exact retention period for provider, ledger, sponsorship, and Shop records.
- [ ] Economy launch feature-flag and legacy-tournament cutoff strategy.

## 11. Current repository safety note

At the time this plan was created:

- Flutter is on `codex/paymongo-flutter-checkout` with substantial existing
  modified and untracked work.
- Backend is on `agent/player-backend-workflows` with existing uncommitted
  shared-function and lockfile changes.

Do not reset, overwrite, fold, or silently mix those changes into wallet work.
Complete Phase 0 isolation before implementing the first migration or Flutter
wallet change.

## 12. Decision log

| Date | Decision |
|---|---|
| 2026-08-08 | Adopt two non-cashable currencies: purchased entry currency and earned Shop currency. |
| 2026-08-08 | Use brand-neutral internal currency codes because the Labaan name may change. |
| 2026-08-08 | Allow tournaments to start underfilled at a configured minimum using byes. |
| 2026-08-08 | Publish a reward formula/tier before registration and lock the final pool at registration close. |
| 2026-08-08 | Streamers pay Labaan through the Host web portal for a locked sponsor allocation; Labaan awards winners directly. |
| 2026-08-08 | Start implementation with a seeded-Credit registration slice before adding payment providers or the Shop. |
