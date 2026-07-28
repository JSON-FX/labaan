-- Labaan — initial schema (spec §10 Core Data Model)
--
-- Mirrors the Dart enums and immutable classes in lib/core/domain/ +
-- lib/core/data/models.dart. Column names match what the SupabaseFooRepo
-- fromRow() constructors expect.
--
-- Run order: 0001_init.sql → 0002_indexes_triggers.sql → 0003_rls.sql →
-- (optional) seed.sql.

------------------------------------------------------------------------------
-- Extensions
------------------------------------------------------------------------------

create extension if not exists "pgcrypto";        -- gen_random_uuid()
create extension if not exists "citext";          -- case-insensitive usernames

------------------------------------------------------------------------------
-- Enum types
------------------------------------------------------------------------------

create type user_role as enum (
  'super_admin', 'tournament_organizer', 'moderator', 'spectator', 'player'
);

create type rank_level as enum (
  'recruit', 'warrior', 'elite', 'champion', 'legend', 'mythic', 'immortal'
);

create type achievement_badge as enum (
  'first_blood', 'hat_trick', 'elite_slayer', 'community_champion',
  'big_game_hunter', 'veteran', 'untouchable'
);

create type tournament_tier as enum (
  'community', 'standard', 'premium', 'elite'
);

create type tournament_status as enum (
  'draft', 'open', 'filling_up', 'locked', 'live', 'completed', 'cancelled'
);

create type bracket_format as enum (
  'double_elimination', 'single_elimination', 'round_robin'
);

create type bracket_side as enum ('upper', 'lower', 'grand_final');

create type pay_method as enum ('gcash', 'maya', 'card');

create type payment_status as enum (
  'pending', 'succeeded', 'failed', 'refunded'
);

create type registration_payment_status as enum (
  'pending', 'paid', 'refunded', 'failed'
);

create type moderator_action as enum (
  'dispute_resolution', 'result_verification', 'no_show_warning',
  'tournament_review'
);

create type notif_kind as enum (
  'match_ready', 'starting_soon', 'rank_up', 'badge_earned',
  'team_invite', 'result_verified', 'dispute_opened', 'payout_received'
);

------------------------------------------------------------------------------
-- Users
------------------------------------------------------------------------------
-- Note: Supabase Auth owns auth.users. This is the profile row keyed by
-- auth.users.id — 1:1.

create table users (
  id                    uuid primary key references auth.users(id) on delete cascade,
  username              citext unique not null,
  email                 text not null,
  phone                 text,
  region                text,
  avatar_url            text,
  role                  user_role not null default 'player',
  games                 text[] not null default array[]::text[],
  has_completed_setup   boolean not null default false,
  is_banned             boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint username_shape check (username ~* '^@?[a-z0-9_]{3,30}$')
);

------------------------------------------------------------------------------
-- User rank — authoritative (spec §9.3: never compute live from matches)
------------------------------------------------------------------------------

create table user_ranks (
  user_id          uuid primary key references users(id) on delete cascade,
  total_wins       int not null default 0 check (total_wins >= 0),
  current_rank     rank_level not null default 'recruit',
  rank_updated_at  timestamptz not null default now()
);

create table user_badges (
  user_id     uuid not null references users(id) on delete cascade,
  badge       achievement_badge not null,
  earned_at   timestamptz not null default now(),
  primary key (user_id, badge)
);

------------------------------------------------------------------------------
-- Teams
------------------------------------------------------------------------------

create table teams (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  tag               text not null check (char_length(tag) between 2 and 5),
  logo_url          text,
  captain_user_id   uuid not null references users(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table team_members (
  team_id     uuid not null references teams(id) on delete cascade,
  user_id     uuid not null references users(id) on delete cascade,
  role_in_team text,
  joined_at   timestamptz not null default now(),
  primary key (team_id, user_id)
);

------------------------------------------------------------------------------
-- Fee + rank config (Super-Admin editable, append-only history)
------------------------------------------------------------------------------

create table fee_configs (
  id                uuid primary key default gen_random_uuid(),
  tier_name         tournament_tier not null,
  entry_fee_php     int not null check (entry_fee_php > 0),
  commission_rate   numeric(4,3) not null check (commission_rate between 0 and 1),
  is_active         boolean not null default true,
  created_by        uuid not null references users(id),
  created_at        timestamptz not null default now(),
  superseded_at     timestamptz
);

create table rank_configs (
  id           uuid primary key default gen_random_uuid(),
  rank_level   rank_level not null,
  rank_name    text not null,
  min_wins     int not null check (min_wins >= 0),
  badge_color  text not null,
  is_active    boolean not null default true,
  created_by   uuid not null references users(id),
  created_at   timestamptz not null default now(),
  superseded_at timestamptz
);

------------------------------------------------------------------------------
-- Tournaments
------------------------------------------------------------------------------

create table tournaments (
  id                    uuid primary key default gen_random_uuid(),
  title                 text not null,
  game                  text not null,
  format                bracket_format not null,
  tier                  tournament_tier not null,
  max_teams             int not null check (max_teams > 0),
  registered_teams      int not null default 0 check (registered_teams >= 0),
  entry_fee_php         int not null check (entry_fee_php > 0),
  commission_rate       numeric(4,3) not null,
  prize_pool_php        int not null default 0 check (prize_pool_php >= 0),
  status                tournament_status not null default 'draft',
  organizer_id          uuid not null references users(id),
  moderator_ids         uuid[] not null default array[]::uuid[],
  spectator_ids         uuid[] not null default array[]::uuid[],
  gab_permit_number     text,
  starts_at             timestamptz not null,
  locks_at              timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint slots_ok check (registered_teams <= max_teams)
);

------------------------------------------------------------------------------
-- Registration + Match
------------------------------------------------------------------------------

create table registrations (
  id                          uuid primary key default gen_random_uuid(),
  tournament_id               uuid not null references tournaments(id) on delete cascade,
  user_id                     uuid not null references users(id),
  team_id                     uuid references teams(id),
  payment_status              registration_payment_status not null default 'pending',
  paid_at                     timestamptz,
  amount_php                  int not null,
  commission_collected_php    int not null,
  paymongo_ref                text,
  created_at                  timestamptz not null default now(),
  unique (tournament_id, user_id)
);

create table matches (
  id                       uuid primary key default gen_random_uuid(),
  tournament_id            uuid not null references tournaments(id) on delete cascade,
  round                    int not null check (round >= 1),
  bracket_side             bracket_side not null,
  team_a_id                uuid references teams(id),
  team_b_id                uuid references teams(id),
  winner_id                uuid references teams(id),
  score_a                  int not null default 0,
  score_b                  int not null default 0,
  screenshot_url           text,
  verified_by_moderator_id uuid references users(id),
  verified_at              timestamptz,
  created_at               timestamptz not null default now()
);

------------------------------------------------------------------------------
-- Payments (append-only — spec §9.3)
------------------------------------------------------------------------------

create table payments (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id),
  tournament_id     uuid not null references tournaments(id),
  amount_php        int not null,
  commission_php    int not null,
  net_prize_php     int not null,
  method            pay_method not null,
  status            payment_status not null default 'pending',
  paymongo_ref      text not null,
  idempotency_key   text unique not null,
  created_at        timestamptz not null default now()
);

create table disbursements (
  id                uuid primary key default gen_random_uuid(),
  tournament_id     uuid not null references tournaments(id),
  winning_team_id   uuid not null references teams(id),
  amount_php        int not null,
  method            pay_method not null,
  status            payment_status not null default 'pending',
  attempts          int not null default 0,
  processed_at      timestamptz,
  created_at        timestamptz not null default now()
);

------------------------------------------------------------------------------
-- Moderator queue
------------------------------------------------------------------------------

create table moderator_queue_items (
  id             uuid primary key default gen_random_uuid(),
  moderator_id   uuid not null references users(id),
  tournament_id  uuid not null references tournaments(id) on delete cascade,
  match_id       uuid references matches(id) on delete cascade,
  action         moderator_action not null,
  created_at     timestamptz not null default now(),
  deadline_at    timestamptz,
  resolved_at    timestamptz,
  escalated_to   uuid references users(id)
);

------------------------------------------------------------------------------
-- Notifications + prefs
------------------------------------------------------------------------------

create table notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  kind         notif_kind not null,
  title        text not null,
  body         text not null,
  deep_link    text,
  payload      jsonb not null default '{}'::jsonb,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);

create table user_notification_prefs (
  user_id     uuid not null references users(id) on delete cascade,
  kind        notif_kind not null,
  push        boolean not null default true,
  email       boolean not null default false,
  primary key (user_id, kind)
);

------------------------------------------------------------------------------
-- Audit log
------------------------------------------------------------------------------

create table audit_logs (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid not null references users(id),
  actor_role   user_role not null,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid not null,
  old_value    jsonb,
  new_value    jsonb,
  created_at   timestamptz not null default now()
);
