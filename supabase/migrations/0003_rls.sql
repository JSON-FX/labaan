-- Labaan — Row-Level Security (spec §11).
--
-- Enforced at the database level so a bug in the API can't bypass it.
-- Roles use the `user_role` enum, which we mirror into JWT claims via a
-- Supabase Auth hook (see supabase/functions/on_signup.sql — not in repo yet).

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

create or replace function auth_user_id() returns uuid
  language sql stable as $$ select auth.uid() $$;

create or replace function auth_role() returns user_role
  language sql stable as $$
    select coalesce(
      (select role from users where id = auth.uid()),
      'player'::user_role
    );
$$;

create or replace function is_super_admin() returns boolean
  language sql stable as $$ select auth_role() = 'super_admin' $$;

create or replace function is_organizer_of(t uuid) returns boolean
  language sql stable as $$
    select exists (
      select 1 from tournaments
       where id = t and organizer_id = auth.uid()
    );
$$;

create or replace function is_moderator_of(t uuid) returns boolean
  language sql stable as $$
    select exists (
      select 1 from tournaments
       where id = t and auth.uid() = any(moderator_ids)
    );
$$;

create or replace function is_spectator_of(t uuid) returns boolean
  language sql stable as $$
    select exists (
      select 1 from tournaments
       where id = t and auth.uid() = any(spectator_ids)
    );
$$;

------------------------------------------------------------------------------
-- Enable RLS on every table
------------------------------------------------------------------------------

alter table users                    enable row level security;
alter table user_ranks               enable row level security;
alter table user_badges              enable row level security;
alter table teams                    enable row level security;
alter table team_members             enable row level security;
alter table fee_configs              enable row level security;
alter table rank_configs             enable row level security;
alter table tournaments              enable row level security;
alter table registrations            enable row level security;
alter table matches                  enable row level security;
alter table payments                 enable row level security;
alter table disbursements            enable row level security;
alter table moderator_queue_items    enable row level security;
alter table notifications            enable row level security;
alter table user_notification_prefs  enable row level security;
alter table audit_logs               enable row level security;

------------------------------------------------------------------------------
-- users — public profile is readable by anyone; you can only edit yourself
------------------------------------------------------------------------------

create policy users_read_public on users for select using (true);

create policy users_update_self on users for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy users_super_admin_all on users for all
  using (is_super_admin()) with check (is_super_admin());

------------------------------------------------------------------------------
-- user_ranks / user_badges — public read, only the rank job (via
-- service_role) writes them
------------------------------------------------------------------------------

create policy user_ranks_read_public on user_ranks for select using (true);
create policy user_ranks_super_admin on user_ranks for all
  using (is_super_admin()) with check (is_super_admin());

create policy user_badges_read_public on user_badges for select using (true);
create policy user_badges_super_admin on user_badges for all
  using (is_super_admin()) with check (is_super_admin());

------------------------------------------------------------------------------
-- teams — public read, only captain edits, member removals limited
------------------------------------------------------------------------------

create policy teams_read_public on teams for select using (true);

create policy teams_captain_writes on teams for update
  using (captain_user_id = auth.uid())
  with check (captain_user_id = auth.uid());

create policy teams_captain_creates on teams for insert
  with check (captain_user_id = auth.uid());

create policy team_members_read_public on team_members for select using (true);

create policy team_members_self_join on team_members for insert
  with check (user_id = auth.uid()
              or exists (select 1 from teams t
                          where t.id = team_id
                            and t.captain_user_id = auth.uid()));

create policy team_members_self_leave on team_members for delete
  using (user_id = auth.uid()
         or exists (select 1 from teams t
                     where t.id = team_id
                       and t.captain_user_id = auth.uid()));

------------------------------------------------------------------------------
-- fee_configs / rank_configs — super-admin only writes, everyone reads
-- active
------------------------------------------------------------------------------

create policy fee_configs_read_active on fee_configs for select
  using (is_active or is_super_admin());

create policy fee_configs_super_admin_writes on fee_configs for all
  using (is_super_admin()) with check (is_super_admin());

create policy rank_configs_read_active on rank_configs for select
  using (is_active or is_super_admin());

create policy rank_configs_super_admin_writes on rank_configs for all
  using (is_super_admin()) with check (is_super_admin());

------------------------------------------------------------------------------
-- tournaments — public read (except drafts), organizer / super-admin write
------------------------------------------------------------------------------

create policy tournaments_read_public on tournaments for select
  using (status <> 'draft'
         or organizer_id = auth.uid()
         or is_super_admin());

create policy tournaments_organizer_writes on tournaments for update
  using (organizer_id = auth.uid() or is_super_admin())
  with check (organizer_id = auth.uid() or is_super_admin());

create policy tournaments_organizer_creates on tournaments for insert
  with check (auth_role() in ('tournament_organizer', 'super_admin')
              and organizer_id = auth.uid());

------------------------------------------------------------------------------
-- registrations — you own your rows; organizer of the tournament reads all
------------------------------------------------------------------------------

create policy registrations_read_self on registrations for select
  using (user_id = auth.uid()
         or is_organizer_of(tournament_id)
         or is_super_admin());

create policy registrations_insert_self on registrations for insert
  with check (user_id = auth.uid());

------------------------------------------------------------------------------
-- matches — public read (bracket is public); moderator writes results
------------------------------------------------------------------------------

create policy matches_read_public on matches for select using (true);

create policy matches_moderator_writes on matches for update
  using (is_moderator_of(tournament_id)
         or is_organizer_of(tournament_id)
         or is_super_admin())
  with check (is_moderator_of(tournament_id)
              or is_organizer_of(tournament_id)
              or is_super_admin());

------------------------------------------------------------------------------
-- payments / disbursements — self read; no direct writes (webhook via
-- service_role bypasses RLS anyway)
------------------------------------------------------------------------------

create policy payments_read_self on payments for select
  using (user_id = auth.uid() or is_super_admin());

create policy disbursements_read_involved on disbursements for select
  using (is_super_admin()
         or exists (select 1 from team_members tm
                     where tm.team_id = winning_team_id
                       and tm.user_id = auth.uid()));

------------------------------------------------------------------------------
-- moderator_queue_items — assigned moderator + organizer see + write
------------------------------------------------------------------------------

create policy moderator_queue_read on moderator_queue_items for select
  using (moderator_id = auth.uid()
         or is_organizer_of(tournament_id)
         or is_super_admin());

create policy moderator_queue_writes on moderator_queue_items for update
  using (moderator_id = auth.uid()
         or is_organizer_of(tournament_id)
         or is_super_admin())
  with check (moderator_id = auth.uid()
              or is_organizer_of(tournament_id)
              or is_super_admin());

------------------------------------------------------------------------------
-- notifications + prefs — you only see your own
------------------------------------------------------------------------------

create policy notifications_read_self on notifications for select
  using (user_id = auth.uid());

create policy notifications_update_self on notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy user_notification_prefs_self on user_notification_prefs for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

------------------------------------------------------------------------------
-- audit_logs — read-only, super-admin only. Writes come from triggers /
-- service_role.
------------------------------------------------------------------------------

create policy audit_logs_super_admin_reads on audit_logs for select
  using (is_super_admin());
