-- Labaan — indexes + triggers + realtime publication.
--
-- Indexes support the queries in lib/core/data/repos.dart. Triggers enforce
-- spec §9.3 invariants (append-only payments, rank never computed live).

------------------------------------------------------------------------------
-- Indexes
------------------------------------------------------------------------------

-- Browse marketplace: cursor pagination over (game, tier, status, created_at)
-- per spec §9.3. Descending created_at + id keeps the seek stable.
create index tournaments_browse_idx
  on tournaments (game, tier, status, created_at desc, id desc);

-- Home feed / trending — hot open tournaments by lock time.
create index tournaments_open_locking_idx
  on tournaments (locks_at asc)
  where status in ('open', 'filling_up');

-- Live tournaments — small hot set.
create index tournaments_live_idx on tournaments (status)
  where status = 'live';

-- Player's own registrations grouped by state.
create index registrations_user_state_idx
  on registrations (user_id, payment_status, paid_at desc nulls last);

-- Match lookup per tournament for bracket rendering.
create index matches_tournament_idx
  on matches (tournament_id, round, bracket_side);

-- Moderator queue — priority sorted by deadline (spec §3.1 "sorted by
-- urgency across all their assigned tournaments").
create index moderator_queue_open_idx
  on moderator_queue_items (moderator_id, deadline_at asc nulls last)
  where resolved_at is null;

-- Leaderboard reads by rank / win count.
create index user_ranks_leaderboard_idx
  on user_ranks (total_wins desc, rank_updated_at desc);

-- Notifications feed newest first.
create index notifications_user_created_idx
  on notifications (user_id, created_at desc);

-- Team-member lookups both directions.
create index team_members_user_idx on team_members (user_id);

-- Payment idempotency — already unique, but explicit index for lookups.
-- (Automatic from unique constraint.)

------------------------------------------------------------------------------
-- updated_at auto-set
------------------------------------------------------------------------------

create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger users_set_updated_at
  before update on users
  for each row execute function set_updated_at();

create trigger teams_set_updated_at
  before update on teams
  for each row execute function set_updated_at();

create trigger tournaments_set_updated_at
  before update on tournaments
  for each row execute function set_updated_at();

------------------------------------------------------------------------------
-- Payments + disbursements are append-only (spec §9.3)
------------------------------------------------------------------------------

create or replace function forbid_mutation() returns trigger as $$
begin
  raise exception 'payments/disbursements are append-only';
end;
$$ language plpgsql;

create trigger payments_no_update
  before update on payments
  for each row execute function forbid_mutation();

create trigger payments_no_delete
  before delete on payments
  for each row execute function forbid_mutation();

create trigger disbursements_no_update
  before update on disbursements
  for each row execute function forbid_mutation();

create trigger disbursements_no_delete
  before delete on disbursements
  for each row execute function forbid_mutation();

------------------------------------------------------------------------------
-- Fee/rank config supersession — flipping active superseded_at
------------------------------------------------------------------------------

create or replace function supersede_prior_fee_config() returns trigger as $$
begin
  if new.is_active then
    update fee_configs
       set is_active = false, superseded_at = now()
     where tier_name = new.tier_name
       and is_active = true
       and id <> new.id;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger fee_configs_supersede
  after insert on fee_configs
  for each row execute function supersede_prior_fee_config();

create or replace function supersede_prior_rank_config() returns trigger as $$
begin
  if new.is_active then
    update rank_configs
       set is_active = false, superseded_at = now()
     where rank_level = new.rank_level
       and is_active = true
       and id <> new.id;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger rank_configs_supersede
  after insert on rank_configs
  for each row execute function supersede_prior_rank_config();

------------------------------------------------------------------------------
-- Tournament slot counter — keep registered_teams in sync
------------------------------------------------------------------------------

create or replace function bump_registered_teams() returns trigger as $$
begin
  if tg_op = 'INSERT' and new.payment_status = 'paid' then
    update tournaments
       set registered_teams = registered_teams + 1
     where id = new.tournament_id;
  elsif tg_op = 'UPDATE'
       and old.payment_status <> 'paid'
       and new.payment_status = 'paid' then
    update tournaments
       set registered_teams = registered_teams + 1
     where id = new.tournament_id;
  elsif tg_op = 'UPDATE'
       and old.payment_status = 'paid'
       and new.payment_status = 'refunded' then
    update tournaments
       set registered_teams = greatest(registered_teams - 1, 0)
     where id = new.tournament_id;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger registrations_bump_slots
  after insert or update on registrations
  for each row execute function bump_registered_teams();

------------------------------------------------------------------------------
-- Filling-up threshold — auto-transition Open → Filling up under 20% left
------------------------------------------------------------------------------

create or replace function auto_filling_up() returns trigger as $$
begin
  if new.status = 'open'
     and new.registered_teams::float / new.max_teams >= 0.8 then
    new.status = 'filling_up';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger tournaments_auto_filling_up
  before update on tournaments
  for each row execute function auto_filling_up();

------------------------------------------------------------------------------
-- Realtime — per-tournament channels (spec §9.3: strictly scoped, no fan-out)
------------------------------------------------------------------------------

alter publication supabase_realtime add table matches;
alter publication supabase_realtime add table tournaments;
alter publication supabase_realtime add table notifications;
