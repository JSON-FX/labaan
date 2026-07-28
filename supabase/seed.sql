-- Labaan — dev seed data. Mirrors lib/core/data/fixtures.dart so the mocked
-- and real backends look identical during development.
--
-- Run AFTER the three migration files. Assumes RLS is enabled — writes here
-- run as service_role which bypasses policies.

------------------------------------------------------------------------------
-- Users (auth.users rows must exist first — normally Supabase Auth creates
-- them; for local seeding we'll insert directly if the seed is applied fresh)
------------------------------------------------------------------------------

-- Insert dummy auth.users rows if they don't exist.  For a real staging
-- environment, sign these accounts up through Supabase Auth first, then just
-- run the `users` insert below to link profile rows.

insert into auth.users (id, email, raw_user_meta_data)
values
  ('11111111-1111-1111-1111-111111111111', 'tonton@labaan.ph', '{}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'sage@labaan.ph',   '{}'::jsonb),
  ('33333333-3333-3333-3333-333333333333', 'warden@labaan.ph', '{}'::jsonb),
  ('44444444-4444-4444-4444-444444444444', 'mid@labaan.ph',    '{}'::jsonb),
  ('55555555-5555-5555-5555-555555555555', 'jett@labaan.ph',   '{}'::jsonb),
  ('66666666-6666-6666-6666-666666666666', 'sova@labaan.ph',   '{}'::jsonb),
  ('77777777-7777-7777-7777-777777777777', 'viper@labaan.ph',  '{}'::jsonb),
  ('99999999-9999-9999-9999-999999999999', 'ops@labaan.ph',    '{}'::jsonb)
on conflict (id) do nothing;

------------------------------------------------------------------------------
-- Users (profiles)
------------------------------------------------------------------------------

insert into users
  (id, username, email, phone, region, role, has_completed_setup, games, created_at)
values
  ('11111111-1111-1111-1111-111111111111',
   '@tonton26', 'tonton@labaan.ph', '+639171234567', 'Manila', 'player', true,
   array['MLBB','VALORANT'], now() - interval '240 days'),
  ('22222222-2222-2222-2222-222222222222',
   '@sagemaster', 'sage@labaan.ph', null, 'Cavite', 'player', true,
   array['VALORANT','MLBB'], now() - interval '180 days'),
  ('33333333-3333-3333-3333-333333333333',
   '@thewarden', 'warden@labaan.ph', null, 'Manila', 'player', true,
   array['MLBB','VALORANT'], now() - interval '420 days'),
  ('44444444-4444-4444-4444-444444444444',
   '@midlaner', 'mid@labaan.ph', null, 'Cebu', 'player', true,
   array['MLBB'], now() - interval '320 days'),
  ('55555555-5555-5555-5555-555555555555',
   '@jettqueen', 'jett@labaan.ph', null, 'Manila', 'player', true,
   array['VALORANT'], now() - interval '90 days'),
  ('66666666-6666-6666-6666-666666666666',
   '@sova_main', 'sova@labaan.ph', null, 'Manila', 'player', true,
   array['VALORANT'], now() - interval '60 days'),
  ('77777777-7777-7777-7777-777777777777',
   '@viperlord', 'viper@labaan.ph', null, 'Manila', 'player', true,
   array['VALORANT'], now() - interval '45 days'),
  ('99999999-9999-9999-9999-999999999999',
   '@ops', 'ops@labaan.ph', null, 'Manila', 'super_admin', true,
   array[]::text[], now() - interval '500 days')
on conflict (id) do nothing;

------------------------------------------------------------------------------
-- Ranks — match fixtures exactly
------------------------------------------------------------------------------

insert into user_ranks (user_id, total_wins, current_rank, rank_updated_at) values
  ('11111111-1111-1111-1111-111111111111', 36,  'champion', now() - interval '3 hours'),
  ('22222222-2222-2222-2222-222222222222', 42,  'champion', now() - interval '3 hours'),
  ('33333333-3333-3333-3333-333333333333', 214, 'immortal', now() - interval '3 hours'),
  ('44444444-4444-4444-4444-444444444444', 178, 'mythic',   now() - interval '3 hours'),
  ('55555555-5555-5555-5555-555555555555', 24,  'elite',    now() - interval '3 hours'),
  ('66666666-6666-6666-6666-666666666666', 19,  'elite',    now() - interval '3 hours'),
  ('77777777-7777-7777-7777-777777777777', 8,   'warrior',  now() - interval '3 hours')
on conflict (user_id) do nothing;

------------------------------------------------------------------------------
-- Badges for @tonton26
------------------------------------------------------------------------------

insert into user_badges (user_id, badge) values
  ('11111111-1111-1111-1111-111111111111', 'first_blood'),
  ('11111111-1111-1111-1111-111111111111', 'hat_trick'),
  ('11111111-1111-1111-1111-111111111111', 'elite_slayer'),
  ('11111111-1111-1111-1111-111111111111', 'big_game_hunter'),
  ('11111111-1111-1111-1111-111111111111', 'veteran')
on conflict do nothing;

------------------------------------------------------------------------------
-- Teams + members
------------------------------------------------------------------------------

insert into teams (id, name, tag, captain_user_id, created_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Team MNL',   'MNL',
    '11111111-1111-1111-1111-111111111111', now() - interval '120 days'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Cebu Kings', 'CBU',
    '44444444-4444-4444-4444-444444444444', now() - interval '200 days'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Davao GG',   'DVO',
    '11111111-1111-1111-1111-111111111111', now() - interval '60 days')
on conflict (id) do nothing;

insert into team_members (team_id, user_id, role_in_team) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'CAPTAIN · IGL'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'SENTINEL'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555', 'DUELIST'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '66666666-6666-6666-6666-666666666666', 'INITIATOR'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '77777777-7777-7777-7777-777777777777', 'CONTROLLER'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444', 'CAPTAIN'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', null)
on conflict do nothing;

------------------------------------------------------------------------------
-- Fee configs — matches lib/core/domain/tournament_tier.dart defaults
------------------------------------------------------------------------------

insert into fee_configs (tier_name, entry_fee_php, commission_rate, created_by) values
  ('community', 50,  0.080, '99999999-9999-9999-9999-999999999999'),
  ('standard',  100, 0.100, '99999999-9999-9999-9999-999999999999'),
  ('premium',   250, 0.150, '99999999-9999-9999-9999-999999999999'),
  ('elite',     500, 0.150, '99999999-9999-9999-9999-999999999999');

------------------------------------------------------------------------------
-- Rank configs — spec §4.1 thresholds
------------------------------------------------------------------------------

insert into rank_configs (rank_level, rank_name, min_wins, badge_color, created_by) values
  ('recruit',  'Recruit',  0,   'Bronze',           '99999999-9999-9999-9999-999999999999'),
  ('warrior',  'Warrior',  5,   'Iron / Steel',     '99999999-9999-9999-9999-999999999999'),
  ('elite',    'Elite',    15,  'Silver',           '99999999-9999-9999-9999-999999999999'),
  ('champion', 'Champion', 30,  'Gold',             '99999999-9999-9999-9999-999999999999'),
  ('legend',   'Legend',   50,  'Platinum',         '99999999-9999-9999-9999-999999999999'),
  ('mythic',   'Mythic',   100, 'Diamond',          '99999999-9999-9999-9999-999999999999'),
  ('immortal', 'Immortal', 200, 'Red / Black crest','99999999-9999-9999-9999-999999999999');

------------------------------------------------------------------------------
-- Tournaments
------------------------------------------------------------------------------

insert into tournaments
  (id, title, game, format, tier, max_teams, registered_teams,
   entry_fee_php, commission_rate, prize_pool_php, status, organizer_id,
   moderator_ids, starts_at, locks_at, created_at, gab_permit_number)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddd01',
   'Manila Clash Weekly #42', 'MLBB', 'double_elimination', 'standard',
   16, 16, 100, 0.10, 1200, 'live',
   '99999999-9999-9999-9999-999999999999',
   array[]::uuid[],
   now() - interval '1 hour', null, now() - interval '4 days', null),
  ('dddddddd-dddd-dddd-dddd-dddddddddd02',
   'Manila Ascent Cup S3', 'VALORANT', 'double_elimination', 'elite',
   16, 14, 500, 0.15, 42000, 'filling_up',
   '99999999-9999-9999-9999-999999999999',
   array[]::uuid[],
   now() + interval '6 hours', now() + interval '2 hours 14 minutes',
   now() - interval '2 days', 'GAB-2026-A-042'),
  ('dddddddd-dddd-dddd-dddd-dddddddddd03',
   'Sunday Night Showdown', 'TEKKEN 8', 'single_elimination', 'community',
   32, 18, 50, 0.08, 800, 'open',
   '99999999-9999-9999-9999-999999999999',
   array[]::uuid[],
   now() + interval '1 day 6 hours', now() + interval '1 day 6 hours',
   now() - interval '3 days', null),
  ('dddddddd-dddd-dddd-dddd-dddddddddd04',
   'Cavite Open Qualifier', 'VALORANT', 'double_elimination', 'premium',
   16, 6, 250, 0.15, 3000, 'open',
   '99999999-9999-9999-9999-999999999999',
   array[]::uuid[],
   now() + interval '2 days', null, now() - interval '1 day', null)
on conflict (id) do nothing;

------------------------------------------------------------------------------
-- Notifications for @tonton26
------------------------------------------------------------------------------

insert into notifications (user_id, kind, title, body, deep_link, created_at) values
  ('11111111-1111-1111-1111-111111111111', 'match_ready', 'Match ready',
   'Manila Clash #42 — quarterfinal starts in 5 min.',
   '/bracket/dddddddd-dddd-dddd-dddd-dddddddddd01', now() - interval '2 minutes'),
  ('11111111-1111-1111-1111-111111111111', 'rank_up', 'Rank up — Champion!',
   'You reached Rank 4. 14 wins to Legend.', null, now() - interval '18 minutes'),
  ('11111111-1111-1111-1111-111111111111', 'team_invite', 'Team invite',
   'Cebu Kings invited you to join as a player.', null, now() - interval '1 hour'),
  ('11111111-1111-1111-1111-111111111111', 'dispute_opened', 'Dispute opened',
   'Davao GG disputed your Manila Clash #42 QF score. Respond in 15m.',
   '/dispute/m_u3', now() - interval '4 minutes'),
  ('11111111-1111-1111-1111-111111111111', 'badge_earned', 'Badge earned — Hat Trick',
   '3 tournament wins in a row. Nice streak.', null, now() - interval '1 day');
