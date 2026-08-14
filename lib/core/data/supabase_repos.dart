import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/badges.dart';
import '../domain/ranks.dart';
import '../domain/roles.dart';
import '../domain/tournament_status.dart';
import '../domain/tournament_tier.dart';
import 'models.dart';
import 'repos.dart';

/// Supabase adapters for the schema owned by the sibling
/// `labaan-backend` project. Reads use PostgREST, live data uses Realtime,
/// and privileged writes use the backend's Edge Functions.

extension _EnumSnakeExt on Enum {
  String get snake => name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}

T _enumFromSnake<T extends Enum>(List<T> values, String value) {
  return values.firstWhere(
    (e) => e.snake == value || e.name == value,
    orElse: () => throw StateError('Unknown enum value "$value" for $T'),
  );
}

int _centavosToPhp(Object? value) => ((value as num? ?? 0) / 100).round();

String get _clientPlatform => kIsWeb
    ? 'web'
    : defaultTargetPlatform == TargetPlatform.android
    ? 'android_direct'
    : 'ios';

TournamentTier _tierFromName(Object? value) {
  final name = value?.toString().toLowerCase();
  return TournamentTier.values.firstWhere(
    (tier) => tier.name == name || tier.displayName.toLowerCase() == name,
    orElse: () => throw StateError('Unknown tournament tier "$value"'),
  );
}

Rank _rankFromRowValue(Map<String, dynamic> row) {
  final level = (row['current_rank'] as num?)?.toInt();
  if (level != null && level >= 1 && level <= Rank.values.length) {
    return Rank.values[level - 1];
  }
  final name = row['rank_name']?.toString().toLowerCase();
  return Rank.values.firstWhere(
    (rank) => rank.name == name,
    orElse: () => Rank.recruit,
  );
}

Map<String, dynamic> _map(Object? value) =>
    (value as Map).cast<String, dynamic>();

LbUser _userFromProfile(
  Map<String, dynamic> row, {
  String email = '',
  String? phone,
  UserRole role = UserRole.player,
}) {
  return LbUser(
    id: row['id'] as String,
    username: row['username'] as String,
    email: email,
    phone: phone,
    region: row['region'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    role: role,
    games: ((row['games'] as List?) ?? const []).cast<String>(),
    hasCompletedSetup: (row['has_completed_setup'] as bool?) ?? false,
    isBanned: (row['is_banned'] as bool?) ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

LbUserRank _rankFromRow(Map<String, dynamic> row) => LbUserRank(
  userId: row['user_id'] as String,
  totalWins: (row['total_wins'] as num?)?.toInt() ?? 0,
  rank: _rankFromRowValue(row),
  rankUpdatedAt: DateTime.parse(row['rank_updated_at'] as String),
);

LbTeam _teamFromRow(Map<String, dynamic> row, {List<String>? memberIds}) {
  return LbTeam(
    id: row['id'] as String,
    name: row['name'] as String,
    tag: row['tag'] as String? ?? '',
    logoUrl: row['logo_url'] as String?,
    captainUserId: row['captain_user_id'] as String,
    memberIds: memberIds ?? const [],
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

int _registrationCount(Map<String, dynamic> row) {
  final stored = row['registered_teams'];
  if (stored is num) return stored.toInt();
  final registrations = row['registrations'];
  if (registrations is! List || registrations.isEmpty) return 0;
  return (_map(registrations.first)['count'] as num?)?.toInt() ?? 0;
}

List<String> _relatedUserIds(Map<String, dynamic> row, String key) {
  final values = row[key];
  if (values is! List) return const [];
  return [
    for (final item in values)
      if (_map(item)['user_id'] case final String id) id,
  ];
}

List<LbSponsorAttribution> _sponsorAttributions(Map<String, dynamic> row) {
  final values = row['tournament_sponsor_allocations'];
  if (values is! List) return const [];
  return [
    for (final item in values)
      if (_map(item)['attribution_name'] case final String name)
        LbSponsorAttribution(
          name: name,
          rewardPoints:
              (_map(item)['reward_point_amount'] as num?)?.toInt() ?? 0,
          fundingSource: _enumFromSnake(
            RewardFundingSource.values,
            _map(item)['funding_source'] as String? ?? 'organizer_sponsor',
          ),
        ),
  ];
}

LbTournament _tournamentFromRow(Map<String, dynamic> row) {
  final createdAt = DateTime.parse(row['created_at'] as String);
  return LbTournament(
    id: row['id'] as String,
    title: row['title'] as String,
    game: row['game'] as String,
    format: _enumFromSnake(BracketFormat.values, row['format'] as String),
    tier: _tierFromName(row['tier_name']),
    maxTeams: (row['max_teams'] as num).toInt(),
    registeredTeams: _registrationCount(row),
    entryFeePhp: _centavosToPhp(row['entry_fee']),
    commissionRate: (row['commission_rate'] as num).toDouble(),
    prizePoolPhp: _centavosToPhp(row['prize_pool']),
    economyMode: _enumFromSnake(
      TournamentEconomy.values,
      row['economy_mode'] as String? ?? 'legacy_cash',
    ),
    entryCreditCost: (row['entry_credit_cost'] as num?)?.toInt(),
    rewardCompetitorBasis: row['reward_competitor_basis'] == null
        ? null
        : _enumFromSnake(
            RewardCompetitorBasis.values,
            row['reward_competitor_basis'] as String,
          ),
    rewardPointsPerCompetitor: (row['reward_points_per_competitor'] as num?)
        ?.toInt(),
    rewardPoolCap: (row['reward_pool_cap'] as num?)?.toInt(),
    rewardPoolTotalCap: (row['reward_pool_total_cap'] as num?)?.toInt(),
    rewardFirstPlaceBps: (row['reward_first_place_bps'] as num?)?.toInt(),
    rewardSecondPlaceBps: (row['reward_second_place_bps'] as num?)?.toInt(),
    rewardThirdPlaceBps: (row['reward_third_place_bps'] as num?)?.toInt(),
    rewardCompetitorCount: (row['reward_competitor_count'] as num?)?.toInt(),
    entryScaledRewardPool: (row['entry_scaled_reward_pool'] as num?)?.toInt(),
    organizerSponsoredRewardPool:
        (row['organizer_sponsored_reward_pool'] as num?)?.toInt(),
    platformRewardPool: (row['platform_reward_pool'] as num?)?.toInt(),
    brandSponsoredRewardPool: (row['brand_sponsored_reward_pool'] as num?)
        ?.toInt(),
    finalRewardPool: (row['final_reward_pool'] as num?)?.toInt(),
    rewardPoolLockedAt: row['reward_pool_locked_at'] == null
        ? null
        : DateTime.parse(row['reward_pool_locked_at'] as String),
    sponsorAttributions: _sponsorAttributions(row),
    minimumTeams: (row['minimum_teams'] as num?)?.toInt(),
    belowMinimumAction: row['below_minimum_action'] == null
        ? null
        : _enumFromSnake(
            BelowMinimumAction.values,
            row['below_minimum_action'] as String,
          ),
    registrationCloseOutcome: row['registration_close_outcome'] == null
        ? null
        : _enumFromSnake(
            RegistrationCloseOutcome.values,
            row['registration_close_outcome'] as String,
          ),
    registrationCloseCompetitorCount:
        (row['registration_close_competitor_count'] as num?)?.toInt(),
    registrationClosedAt: row['registration_closed_at'] == null
        ? null
        : DateTime.parse(row['registration_closed_at'] as String),
    status: _enumFromSnake(TournamentStatus.values, row['status'] as String),
    organizerId: row['organizer_id'] as String,
    moderatorIds: _relatedUserIds(row, 'tournament_moderators'),
    spectatorIds: _relatedUserIds(row, 'tournament_spectators'),
    gabPermitNumber: row['gab_permit_number'] as String?,
    startsAt: row['starts_at'] == null
        ? createdAt
        : DateTime.parse(row['starts_at'] as String),
    locksAt: row['registration_locks_at'] == null
        ? null
        : DateTime.parse(row['registration_locks_at'] as String),
    createdAt: createdAt,
  );
}

LbMatch _matchFromRow(Map<String, dynamic> row, {BracketSide? side}) {
  return LbMatch(
    id: row['id'] as String,
    tournamentId: row['tournament_id'] as String,
    round: (row['round'] as num).toInt(),
    position: (row['position'] as num?)?.toInt() ?? 1,
    bracketSide:
        side ??
        (row['bracket_side'] == null
            ? BracketSide.upper
            : _enumFromSnake(
                BracketSide.values,
                row['bracket_side'] as String,
              )),
    teamAId: row['team_a_id'] as String? ?? '',
    teamBId: row['team_b_id'] as String? ?? '',
    winnerId: row['winner_id'] as String?,
    scoreA: (row['score_a'] as num?)?.toInt() ?? 0,
    scoreB: (row['score_b'] as num?)?.toInt() ?? 0,
    status: _enumFromSnake(
      LbMatchStatus.values,
      row['status'] as String? ?? 'pending',
    ),
    submittedByUserId: row['submitted_by'] as String?,
    submittedTeamId: row['submitted_team_id'] as String?,
    screenshotUrl: row['screenshot_url'] as String?,
    verifiedByModeratorId: row['verified_by'] as String?,
    verifiedAt: row['verified_at'] == null
        ? null
        : DateTime.parse(row['verified_at'] as String),
  );
}

NotifKind _notificationKind(Object? value) {
  final raw = value?.toString() ?? '';
  if (const {
    'payout_received',
    'payout_setup_required',
    'prize_paid',
    'prize_processing',
  }.contains(raw)) {
    return NotifKind.payoutReceived;
  }
  return NotifKind.values.firstWhere(
    (kind) => kind.snake == raw || kind.name == raw,
    orElse: () => NotifKind.startingSoon,
  );
}

LbNotification _notificationFromRow(Map<String, dynamic> row) {
  final data = ((row['data'] as Map?) ?? const {}).cast<String, Object?>();
  return LbNotification(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    kind: _notificationKind(row['type']),
    title: row['title'] as String,
    body: row['body'] as String? ?? '',
    deepLink: data['deep_link'] as String?,
    payload: data,
    readAt: row['read_at'] == null
        ? null
        : DateTime.parse(row['read_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

LbRegistration _registrationFromRow(Map<String, dynamic> row) {
  return LbRegistration(
    id: row['id'] as String,
    tournamentId: row['tournament_id'] as String,
    userId: row['user_id'] as String,
    teamId: row['team_id'] as String?,
    paymentStatus: _enumFromSnake(
      RegistrationPaymentStatus.values,
      row['payment_status'] as String,
    ),
    paidAt: row['paid_at'] == null
        ? null
        : DateTime.parse(row['paid_at'] as String),
    amountPhp: _centavosToPhp(row['amount']),
    commissionCollectedPhp: _centavosToPhp(row['commission_collected']),
    paymongoRef: row['paymongo_ref'] as String?,
    economyMode: _enumFromSnake(
      TournamentEconomy.values,
      row['economy_mode'] as String? ?? 'legacy_cash',
    ),
    entryCreditAmount: (row['entry_credit_amount'] as num?)?.toInt(),
    cancelledAt: row['cancelled_at'] == null
        ? null
        : DateTime.parse(row['cancelled_at'] as String),
  );
}

Map<String, dynamic> _functionData(FunctionResponse response) {
  if (response.status < 200 || response.status >= 300) {
    final body = response.data;
    final code = body is Map ? body['error'] ?? body['message'] : null;
    final detail = code == null ? '' : ': $code';
    throw StateError('Backend function failed (${response.status})$detail');
  }
  final body = response.data;
  if (body is Map && body['data'] is Map) return _map(body['data']);
  if (body is Map) return body.cast<String, dynamic>();
  throw StateError('Backend function returned an invalid response');
}

const _tournamentSelect =
    '*, tournament_moderators(user_id), '
    'tournament_spectators(user_id), '
    'tournament_sponsor_allocations('
    'funding_source,reward_point_amount,attribution_name)';

class SupabaseTournamentsRepo implements TournamentsRepo {
  SupabaseTournamentsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbHomeFeed> homeFeed({required String userId}) async {
    final responses = await Future.wait([
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .eq('status', 'live')
          .limit(1),
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .inFilter('status', ['open', 'filling_up'])
          .order('registration_locks_at', nullsFirst: false)
          .limit(3),
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .inFilter('status', ['open', 'filling_up'])
          .order('created_at', ascending: false)
          .limit(3),
    ]);
    final live = responses[0];
    return LbHomeFeed(
      liveMatchReady: live.isEmpty ? null : _tournamentFromRow(live.first),
      featured: [for (final row in responses[1]) _tournamentFromRow(row)],
      trending: [for (final row in responses[2]) _tournamentFromRow(row)],
    );
  }

  @override
  Future<LbTournamentPage> browse({
    String? cursor,
    String? gameFilter,
    TournamentTier? tierFilter,
    String? organizerId,
    String? searchQuery,
    int limit = 20,
  }) async {
    dynamic query = _client
        .from('tournaments')
        .select(_tournamentSelect)
        .inFilter('status', ['open', 'filling_up', 'live']);
    if (gameFilter != null && gameFilter != 'All games') {
      query = query.eq('game', gameFilter);
    }
    if (tierFilter != null) {
      query = query.eq('tier_name', tierFilter.displayName);
    }
    if (organizerId != null) {
      query = query.eq('organizer_id', organizerId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }
    if (cursor != null) {
      final parts = cursor.split('|');
      if (parts.length == 2) {
        query = query.or(
          'created_at.lt.${parts[0]},'
          'and(created_at.eq.${parts[0]},id.lt.${parts[1]})',
        );
      }
    }
    final List<dynamic> rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return LbTournamentPage(
      items: [for (final row in rows) _tournamentFromRow(row)],
      nextCursor: rows.length == limit
          ? '${rows.last['created_at']}|${rows.last['id']}'
          : null,
    );
  }

  @override
  Future<LbTournament> byId(String tournamentId) async {
    final row = await _client
        .from('tournaments')
        .select(_tournamentSelect)
        .eq('id', tournamentId)
        .single();
    return _tournamentFromRow(row);
  }

  @override
  Stream<LbTournament> watch(String tournamentId) {
    return _client
        .from('tournaments')
        .stream(primaryKey: ['id'])
        .eq('id', tournamentId)
        .where((rows) => rows.isNotEmpty)
        .map((rows) => _tournamentFromRow(rows.first));
  }
}

class SupabaseMyTournamentsRepo implements MyTournamentsRepo {
  SupabaseMyTournamentsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbMyTournaments> forUser(String userId) async {
    final responses = await Future.wait<dynamic>([
      _client
          .from('registrations')
          .select('*, tournaments!inner($_tournamentSelect)')
          .eq('user_id', userId)
          .eq('payment_status', 'paid'),
      _client.from('team_members').select('team_id').eq('user_id', userId),
      _client
          .from('tournament_reward_grants')
          .select('amount, placement, tournaments!inner($_tournamentSelect)')
          .eq('user_id', userId),
    ]);
    final rows = responses[0] as List<dynamic>;
    final rewardRows = responses[2] as List<dynamic>;
    final rewardByTournament = <String, Map<String, dynamic>>{
      for (final row in rewardRows)
        _map(row['tournaments'])['id'] as String: _map(row),
    };
    final teamIds = {
      for (final row in responses[1] as List<dynamic>) row['team_id'] as String,
    };
    final liveTournamentIds = <String>[
      for (final row in rows)
        if (_map(row['tournaments'])['status'] == 'live')
          _map(row['tournaments'])['id'] as String,
    ];
    final matchRows = liveTournamentIds.isEmpty || teamIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('matches')
              .select()
              .inFilter('tournament_id', liveTournamentIds)
              .inFilter('status', [
                'ready',
                'awaiting_result',
                'awaiting_verification',
              ]);
    final now = DateTime.now();
    final live = <LbLiveEntry>[];
    final upcoming = <LbUpcomingEntry>[];
    final completed = <LbCompletedTournament>[];
    final completedIds = <String>{};
    for (final row in rows) {
      final tournament = _tournamentFromRow(_map(row['tournaments']));
      switch (tournament.status) {
        case TournamentStatus.live:
          Map<String, dynamic>? currentMatch;
          for (final candidate in matchRows) {
            if (candidate['tournament_id'] == tournament.id &&
                (teamIds.contains(candidate['team_a_id']) ||
                    teamIds.contains(candidate['team_b_id']))) {
              currentMatch = _map(candidate);
              break;
            }
          }
          final matchStatus = currentMatch?['status'] as String?;
          final submittedTeamId = currentMatch?['submitted_team_id'] as String?;
          final opponentTeamIds = currentMatch == null
              ? const <String>{}
              : {
                  if (currentMatch['team_a_id'] != submittedTeamId)
                    currentMatch['team_a_id'] as String,
                  if (currentMatch['team_b_id'] != submittedTeamId)
                    currentMatch['team_b_id'] as String,
                };
          final matchAction = switch (matchStatus) {
            'ready' || 'awaiting_result' => LbMatchAction.submitResult,
            'awaiting_verification'
                when currentMatch?['submitted_by'] == userId ||
                    (submittedTeamId != null &&
                        teamIds.contains(submittedTeamId) &&
                        teamIds.intersection(opponentTeamIds).isEmpty) =>
              LbMatchAction.awaitingVerification,
            'awaiting_verification'
                when teamIds.intersection(opponentTeamIds).isNotEmpty =>
              LbMatchAction.verifyResult,
            _ => LbMatchAction.none,
          };
          live.add(
            LbLiveEntry(
              tournament: tournament,
              matchReady:
                  matchAction == LbMatchAction.submitResult ||
                  matchAction == LbMatchAction.verifyResult,
              currentBracketNode: currentMatch == null
                  ? 'NO MATCH READY'
                  : 'ROUND ${currentMatch['round']}',
              currentMatchId: currentMatch?['id'] as String?,
              matchAction: matchAction,
            ),
          );
        case TournamentStatus.open:
        case TournamentStatus.fillingUp:
        case TournamentStatus.locked:
          upcoming.add(
            LbUpcomingEntry(
              tournament: tournament,
              locksIn: tournament.locksAt?.difference(now) ?? Duration.zero,
            ),
          );
        case TournamentStatus.completed:
          final reward = rewardByTournament[tournament.id];
          completed.add(
            LbCompletedTournament(
              tournament: tournament,
              finalPlace: (reward?['placement'] as num?)?.toInt() ?? 0,
              payoutPhp: 0,
              rewardPoints: (reward?['amount'] as num?)?.toInt() ?? 0,
            ),
          );
          completedIds.add(tournament.id);
        case TournamentStatus.draft:
        case TournamentStatus.cancelled:
          break;
      }
    }
    for (final row in rewardRows) {
      final tournament = _tournamentFromRow(_map(row['tournaments']));
      if (tournament.status != TournamentStatus.completed ||
          !completedIds.add(tournament.id)) {
        continue;
      }
      completed.add(
        LbCompletedTournament(
          tournament: tournament,
          finalPlace: (row['placement'] as num?)?.toInt() ?? 0,
          payoutPhp: 0,
          rewardPoints: (row['amount'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    completed.sort(
      (a, b) => b.tournament.startsAt.compareTo(a.tournament.startsAt),
    );
    return LbMyTournaments(
      live: live,
      upcoming: upcoming,
      completed: completed,
    );
  }

  @override
  Stream<LbMyTournaments> watchForUser(String userId) async* {
    yield await forUser(userId);
    await for (final _
        in _client
            .from('registrations')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)) {
      yield await forUser(userId);
    }
  }
}

class SupabaseBracketRepo implements BracketRepo {
  SupabaseBracketRepo(this._client);
  final SupabaseClient _client;

  @override
  Stream<LbBracket> watch(String tournamentId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .asyncMap((rows) async {
          final nullable = rows
              .where((row) => row['bracket_side'] == null)
              .toList();
          Map<String, dynamic>? finalRow;
          if (nullable.isNotEmpty) {
            nullable.sort((a, b) {
              final round = (b['round'] as num).compareTo(a['round'] as num);
              if (round != 0) return round;
              return (b['position'] as num).compareTo(a['position'] as num);
            });
            finalRow = nullable.first;
          }
          final matches = [
            for (final row in rows)
              _matchFromRow(
                row,
                side: identical(row, finalRow) ? BracketSide.grandFinal : null,
              ),
          ];
          final teamIds = {
            for (final match in matches) ...[
              if (match.teamAId.isNotEmpty) match.teamAId,
              if (match.teamBId.isNotEmpty) match.teamBId,
            ],
          };
          final teamRows = teamIds.isEmpty
              ? const <dynamic>[]
              : await _client
                    .from('teams')
                    .select()
                    .inFilter('id', teamIds.toList());
          final teams = {
            for (final row in teamRows)
              row['id'] as String: _teamFromRow(_map(row)),
          };
          int compareMatches(LbMatch a, LbMatch b) {
            final round = a.round.compareTo(b.round);
            return round != 0 ? round : a.position.compareTo(b.position);
          }

          return LbBracket(
            tournamentId: tournamentId,
            upper: [
              for (final match in matches)
                if (match.bracketSide == BracketSide.upper) match,
            ]..sort(compareMatches),
            lower: [
              for (final match in matches)
                if (match.bracketSide == BracketSide.lower) match,
            ]..sort(compareMatches),
            grandFinal: matches
                .where((match) => match.bracketSide == BracketSide.grandFinal)
                .firstOrNull,
            teams: teams,
          );
        });
  }
}

class SupabaseRegistrationRepo implements RegistrationRepo {
  SupabaseRegistrationRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<CreditRegistrationResult> enterWithCredits({
    required String tournamentId,
    required String userId,
    String? teamId,
    required String idempotencyKey,
  }) async {
    final data = await _invokeCreditCommand(
      'registration-enter-with-credits',
      idempotencyKey: idempotencyKey,
      body: {
        'tournamentId': tournamentId,
        'teamId': teamId,
        'platform': _clientPlatform,
        'idempotencyKey': idempotencyKey,
      },
    );
    return _creditRegistrationResult(data);
  }

  @override
  Future<CreditRegistrationResult> cancelCreditRegistration({
    required String registrationId,
    required String userId,
    required String idempotencyKey,
  }) async {
    final data = await _invokeCreditCommand(
      'registration-cancel',
      idempotencyKey: idempotencyKey,
      body: {
        'registrationId': registrationId,
        'idempotencyKey': idempotencyKey,
      },
    );
    return _creditRegistrationResult(data);
  }

  Future<Map<String, dynamic>> _invokeCreditCommand(
    String functionName, {
    required String idempotencyKey,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        headers: {'Idempotency-Key': idempotencyKey},
        body: body,
      );
      if (response.status < 200 || response.status >= 300) {
        throw _registrationFailure(response.data);
      }
      return _functionData(response);
    } on FunctionException catch (error) {
      throw _registrationFailure(error.details);
    }
  }

  LbRegistrationFailure _registrationFailure(Object? details) {
    if (details case final Map envelope) {
      final rawError = envelope['error'];
      if (rawError case final Map error) {
        return LbRegistrationFailure(
          error['code'] as String? ?? 'registration_failed',
          error['message'] as String? ?? 'Could not update registration.',
        );
      }
    }
    return const LbRegistrationFailure(
      'registration_failed',
      'Could not update registration. Please try again.',
    );
  }

  CreditRegistrationResult _creditRegistrationResult(
    Map<String, dynamic> data,
  ) => CreditRegistrationResult(
    registration: _registrationFromRow(_map(data['registration'])),
    entryCreditBalance: (data['entryCreditBalance'] as num).toInt(),
    entryCreditCost:
        ((data['entryCreditCost'] ?? data['refundedCredits']) as num).toInt(),
    walletTransactionId: data['walletTransactionId'] as String?,
    existing: data['existing'] as bool? ?? false,
  );

  @override
  Future<RegistrationCheckout> register({
    required String tournamentId,
    required String userId,
    String? teamId,
    required PayMethod method,
    required String captchaToken,
  }) async {
    final reservationResponse = await _client.functions.invoke(
      'registration-reserve',
      body: {'tournamentId': tournamentId, 'teamId': ?teamId},
    );
    final reservation = _registrationFromRow(
      _functionData(reservationResponse),
    );
    if (reservation.paymentStatus == RegistrationPaymentStatus.paid) {
      return RegistrationCheckout(registration: reservation);
    }

    final returnQuery = {
      'registrationId': reservation.id,
      'tournamentId': reservation.tournamentId,
    };
    final successUrl = Uri(
      scheme: 'labaan',
      host: 'payment',
      path: '/success',
      queryParameters: returnQuery,
    );
    final cancelUrl = Uri(
      scheme: 'labaan',
      host: 'payment',
      path: '/cancel',
      queryParameters: returnQuery,
    );

    final idempotencyKey =
        '$userId:$tournamentId:${DateTime.now().microsecondsSinceEpoch}';
    final paymentResponse = await _client.functions.invoke(
      'payments-create-intent',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'registrationId': reservation.id,
        'method': method.name,
        'idempotencyKey': idempotencyKey,
        'successUrl': successUrl.toString(),
        'cancelUrl': cancelUrl.toString(),
      },
    );
    final paymentData = _functionData(paymentResponse);
    final checkoutUrlValue = paymentData['checkoutUrl'];
    Uri? checkoutUrl;
    if (checkoutUrlValue != null) {
      checkoutUrl = Uri.tryParse(checkoutUrlValue.toString());
      if (checkoutUrl == null ||
          checkoutUrl.scheme != 'https' ||
          checkoutUrl.host.isEmpty) {
        throw StateError('Backend returned an invalid checkout URL');
      }
    }
    return RegistrationCheckout(
      registration: _registrationFromRow(_map(paymentData['registration'])),
      checkoutUrl: checkoutUrl,
    );
  }

  @override
  Stream<RegistrationPaymentStatus> watchPayment(String registrationId) {
    return _client
        .from('registrations')
        .stream(primaryKey: ['id'])
        .eq('id', registrationId)
        .where((rows) => rows.isNotEmpty)
        .map(
          (rows) => _enumFromSnake(
            RegistrationPaymentStatus.values,
            rows.first['payment_status'] as String,
          ),
        );
  }
}

class SupabaseResultsRepo implements ResultsRepo {
  SupabaseResultsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbMatch> byId(String matchId) async {
    final row = await _client
        .from('matches')
        .select()
        .eq('id', matchId)
        .single();
    return _matchFromRow(row);
  }

  @override
  Future<String> uploadScreenshot({
    required String userId,
    required String matchId,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final path =
        '$userId/$matchId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final bucket = _client.storage.from('match-screenshots');
    final signed = await _client.storage
        .from('match-screenshots')
        .createSignedUploadUrl(path);
    await bucket.uploadBinaryToSignedUrl(
      path,
      signed.token,
      bytes,
      FileOptions(contentType: contentType),
    );
    return path;
  }

  @override
  Future<void> submit({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String screenshotPath,
  }) async {
    final response = await _client.functions.invoke(
      'match-submit-result',
      body: {
        'matchId': matchId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'screenshotPath': screenshotPath,
      },
    );
    _functionData(response);
  }

  @override
  Future<String?> screenshotPreviewUrl(String screenshotPath) {
    return _client.storage
        .from('match-screenshots')
        .createSignedUrl(screenshotPath, 600);
  }

  @override
  Future<void> verify({required String matchId}) async {
    final response = await _client.functions.invoke(
      'match-verify-result',
      body: {'matchId': matchId},
    );
    _functionData(response);
  }

  @override
  Future<void> openDispute({
    required String matchId,
    required String reason,
    required String detail,
  }) async {
    final response = await _client.functions.invoke(
      'match-dispute',
      body: {'matchId': matchId, 'reason': reason, 'detail': detail},
    );
    _functionData(response);
  }
}

class SupabaseProfileRepo implements ProfileRepo {
  SupabaseProfileRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbPlayerProfile> byId(String userId) async {
    final responses = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', userId).single(),
      _client.from('user_rank').select().eq('user_id', userId).maybeSingle(),
      _client.from('user_badges').select().eq('user_id', userId),
      _client.from('team_members').select('team_id').eq('user_id', userId),
      _client.rpc(
        'get_player_profile_aggregates',
        params: {'p_user_id': userId},
      ),
    ]);
    final profile = responses[0] as Map<String, dynamic>;
    final rankRow = responses[1] as Map<String, dynamic>?;
    final badges = responses[2] as List<dynamic>;
    final memberships = responses[3] as List<dynamic>;
    final aggregates = _map(responses[4]);
    final authUser = firebase.FirebaseAuth.instance.currentUser;
    final isCurrentUser = authUser?.uid == profile['firebase_uid'];
    final rank = rankRow == null
        ? LbUserRank(
            userId: userId,
            totalWins: 0,
            rank: Rank.recruit,
            rankUpdatedAt: DateTime.now(),
          )
        : _rankFromRow(rankRow);
    final losses = (rankRow?['total_losses'] as num?)?.toInt() ?? 0;
    return LbPlayerProfile(
      user: _userFromProfile(
        profile,
        email: isCurrentUser ? authUser?.email ?? '' : '',
        phone: isCurrentUser ? authUser?.phoneNumber : null,
      ),
      rank: rank,
      badges: [
        for (final row in badges)
          _enumFromSnake(AchievementBadge.values, row['badge_key'] as String),
      ],
      gamesPlayed: ((profile['games'] as List?) ?? const []).cast<String>(),
      totalMatches: (aggregates['totalMatches'] as num?)?.toInt() ?? 0,
      totalWins: (aggregates['totalWins'] as num?)?.toInt() ?? rank.totalWins,
      totalLosses: (aggregates['totalLosses'] as num?)?.toInt() ?? losses,
      totalPayoutPhp: _centavosToPhp(aggregates['totalPayoutCentavos']),
      totalRewardPoints:
          (aggregates['totalRewardPoints'] as num?)?.toInt() ?? 0,
      teamIds: [for (final row in memberships) row['team_id'] as String],
      recentTournaments: [
        for (final value
            in (aggregates['recentTournaments'] as List?) ?? const [])
          if (value is Map)
            LbCompletedTournament(
              tournament: _tournamentFromRow(_map(value['tournament'])),
              finalPlace: (value['finalPlace'] as num?)?.toInt() ?? 2,
              payoutPhp: _centavosToPhp(value['payoutCentavos']),
              rewardPoints: (value['rewardPoints'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
  }

  @override
  Future<LbPlayerProfile> byUsername(String username) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();
    return byId(row['id'] as String);
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = '$userId/avatar';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    final baseUrl = _client.storage.from('avatars').getPublicUrl(path);
    final avatarUrl = '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
    return avatarUrl;
  }

  @override
  Future<void> updateIdentity({
    required String userId,
    required String username,
    required String region,
    required List<String> games,
  }) => _client
      .from('profiles')
      .update({'username': username, 'region': region, 'games': games})
      .eq('id', userId);
}

class SupabaseSettingsRepo implements SettingsRepo {
  SupabaseSettingsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbNotificationPreferences> notificationPreferences(
    String userId,
  ) async {
    final row = await _client
        .from('user_notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return LbNotificationPreferences.defaults();
    final defaults = LbNotificationPreferences.defaults();
    return LbNotificationPreferences(
      push: _preferenceMap(row['push_preferences'], defaults.push),
      email: _preferenceMap(row['email_preferences'], defaults.email),
    );
  }

  Map<NotifKind, bool> _preferenceMap(
    dynamic value,
    Map<NotifKind, bool> defaults,
  ) {
    final json = (value as Map?)?.cast<String, dynamic>() ?? const {};
    return {
      for (final kind in NotifKind.values)
        kind: (json[kind.name] as bool?) ?? defaults[kind]!,
    };
  }

  Map<String, bool> _preferenceJson(Map<NotifKind, bool> values) => {
    for (final entry in values.entries) entry.key.name: entry.value,
  };

  @override
  Future<void> saveNotificationPreferences(
    String userId,
    LbNotificationPreferences preferences,
  ) => _client.from('user_notification_preferences').upsert({
    'user_id': userId,
    'push_preferences': _preferenceJson(preferences.push),
    'email_preferences': _preferenceJson(preferences.email),
  });

  @override
  Future<LbPayoutAccount?> payoutAccount(String userId) async {
    final row = await _client
        .from('payout_accounts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return LbPayoutAccount(
      provider: row['provider'] as String,
      accountName: row['account_name'] as String,
      mobileNumber: row['mobile_number'] as String,
    );
  }

  @override
  Future<void> savePayoutAccount(String userId, LbPayoutAccount account) =>
      _client.from('payout_accounts').upsert({
        'user_id': userId,
        'provider': account.provider,
        'account_name': account.accountName.trim(),
        'mobile_number': account.mobileNumber,
      });

  @override
  Future<void> deletePayoutAccount(String userId) =>
      _client.from('payout_accounts').delete().eq('user_id', userId);

  @override
  Future<LbAccountDeletionRequest?> accountDeletionRequest(
    String userId,
  ) async {
    final row = await _client
        .from('account_deletion_requests')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : _accountDeletionFromRow(row);
  }

  @override
  Future<LbAccountDeletionRequest> requestAccountDeletion() async {
    final response = await _client.functions.invoke(
      'account-deletion',
      body: {'action': 'request', 'confirmation': 'DELETE'},
    );
    return _accountDeletionFromRow(_functionData(response));
  }

  @override
  Future<LbAccountDeletionRequest> cancelAccountDeletion() async {
    final response = await _client.functions.invoke(
      'account-deletion',
      body: {'action': 'cancel'},
    );
    return _accountDeletionFromRow(_functionData(response));
  }

  LbAccountDeletionRequest _accountDeletionFromRow(Map<String, dynamic> row) {
    final status = switch (row['status']) {
      'under_review' => LbAccountDeletionStatus.underReview,
      'processing' => LbAccountDeletionStatus.processing,
      'cancelled' => LbAccountDeletionStatus.cancelled,
      'completed' => LbAccountDeletionStatus.completed,
      _ => LbAccountDeletionStatus.pending,
    };
    DateTime? optionalDate(String key) =>
        row[key] == null ? null : DateTime.parse(row[key] as String);
    return LbAccountDeletionRequest(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      status: status,
      requestedAt: DateTime.parse(row['requested_at'] as String),
      scheduledFor: DateTime.parse(row['scheduled_for'] as String),
      cancelledAt: optionalDate('cancelled_at'),
      completedAt: optionalDate('completed_at'),
      retentionUntil: optionalDate('retention_until'),
      reviewReason: row['review_reason'] as String?,
    );
  }
}

class SupabaseEconomyFeatureFlagsRepo implements EconomyFeatureFlagsRepo {
  SupabaseEconomyFeatureFlagsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbEconomyFeatures> forPlatform({
    required String environment,
    required LbClientPlatform platform,
  }) async {
    final rows = await _client
        .from('economy_feature_flags')
        .select('feature_key, is_enabled, public_message')
        .eq('environment', environment)
        .eq('platform', platform.snake);
    final enabled = <LbEconomyFeature, bool>{};
    final messages = <LbEconomyFeature, String>{};
    for (final value in rows) {
      final row = _map(value);
      final feature = _enumFromSnake(
        LbEconomyFeature.values,
        row['feature_key'] as String,
      );
      enabled[feature] = row['is_enabled'] as bool? ?? false;
      messages[feature] =
          row['public_message'] as String? ??
          'This feature is temporarily unavailable.';
    }
    return LbEconomyFeatures(enabled, messages);
  }
}

class SupabaseAdminEconomyRepo implements AdminEconomyRepo {
  SupabaseAdminEconomyRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbAdminEconomyDashboard> dashboard() async {
    final summaryRow = await _client
        .from('admin_economy_business_summary')
        .select()
        .maybeSingle();
    Future<List<Map<String, dynamic>>> actionRows(
      String view,
      String columns,
    ) async => [
      for (final value
          in await _client
              .from(view)
              .select(columns)
              .eq('requires_action', true)
              .limit(250))
        _map(value),
    ];

    final topupRows = await actionRows(
      'topup_reconciliation_audit',
      'topup_order_id, user_id, order_status, reconciliation_state, '
          'expected_credit_amount, updated_at',
    );
    final sponsorRows = await actionRows(
      'admin_sponsor_reconciliation_audit',
      'sponsor_order_id, tournament_id, organizer_id, order_status, '
          'reconciliation_state, expected_reward_points, updated_at',
    );
    final rewardRows = await actionRows(
      'admin_tournament_reward_reconciliation_audit',
      'tournament_id, tournament_status, reconciliation_state, '
          'final_reward_pool, reward_pool_locked_at',
    );
    final shopRows = await actionRows(
      'admin_shop_reconciliation_audit',
      'shop_order_id, user_id, order_status, reconciliation_state, '
          'total_reward_points, updated_at',
    );
    final riskRows = await _client
        .from('economy_risk_cases')
        .select(
          'id, user_id, signal_type, severity, status, occurrence_count, '
          'reference_type, reference_id, last_detected_at',
        )
        .inFilter('status', ['open', 'reviewing'])
        .order('last_detected_at', ascending: false)
        .limit(100);
    final summary = <String, num>{};
    if (summaryRow != null) {
      for (final entry in summaryRow.entries) {
        if (entry.value is num) summary[entry.key] = entry.value as num;
      }
    }
    return LbAdminEconomyDashboard(
      summary: summary,
      actionCounts: {
        'topups': topupRows.length,
        'sponsors': sponsorRows.length,
        'rewards': rewardRows.length,
        'shop': shopRows.length,
      },
      actionItems: [
        for (final row in topupRows)
          _actionItem(
            category: 'topup',
            row: row,
            idKey: 'topup_order_id',
            statusKey: 'order_status',
            amountKey: 'expected_credit_amount',
          ),
        for (final row in sponsorRows)
          _actionItem(
            category: 'sponsor',
            row: row,
            idKey: 'sponsor_order_id',
            statusKey: 'order_status',
            userKey: 'organizer_id',
            amountKey: 'expected_reward_points',
          ),
        for (final row in rewardRows)
          _actionItem(
            category: 'reward',
            row: row,
            idKey: 'tournament_id',
            statusKey: 'tournament_status',
            amountKey: 'final_reward_pool',
            updatedKey: 'reward_pool_locked_at',
          ),
        for (final row in shopRows)
          _actionItem(
            category: 'shop',
            row: row,
            idKey: 'shop_order_id',
            statusKey: 'order_status',
            amountKey: 'total_reward_points',
          ),
      ],
      riskCases: [
        for (final value in riskRows)
          LbEconomyRiskCase(
            id: value['id'] as String,
            userId: value['user_id'] as String?,
            signalType: value['signal_type'] as String,
            severity: value['severity'] as String,
            status: value['status'] as String,
            occurrenceCount: (value['occurrence_count'] as num).toInt(),
            referenceType: value['reference_type'] as String?,
            referenceId: value['reference_id'] as String?,
            lastDetectedAt: DateTime.parse(value['last_detected_at'] as String),
          ),
      ],
    );
  }

  LbEconomyActionItem _actionItem({
    required String category,
    required Map<String, dynamic> row,
    required String idKey,
    required String statusKey,
    required String amountKey,
    String userKey = 'user_id',
    String updatedKey = 'updated_at',
  }) => LbEconomyActionItem(
    category: category,
    id: row[idKey] as String,
    state: row['reconciliation_state'] as String,
    status: row[statusKey] as String,
    updatedAt: row[updatedKey] == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.parse(row[updatedKey] as String),
    userId: row[userKey] as String?,
    tournamentId: category == 'reward'
        ? row[idKey] as String
        : row['tournament_id'] as String?,
    amount: (row[amountKey] as num?)?.toInt(),
  );

  @override
  Future<void> resolveRiskCase({
    required String caseId,
    required bool dismissed,
    required String reason,
  }) async {
    final response = await _client.functions.invoke(
      'admin-risk-case-resolve',
      body: {
        'caseId': caseId,
        'resolution': dismissed ? 'dismissed' : 'resolved',
        'reason': reason,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Risk case resolution failed');
    }
  }

  @override
  Future<void> adjustWallet({
    required String targetUserId,
    required LbWalletCurrency currency,
    required bool grant,
    required int amount,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'admin-wallet-adjustment',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'targetUserId': targetUserId,
        'currencyCode': currency.snake,
        'direction': grant ? 'grant' : 'deduct',
        'amount': amount,
        'reasonCode': 'player_support',
        'reason': reason,
        'idempotencyKey': idempotencyKey,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Wallet adjustment failed');
    }
  }
}

class SupabaseWalletRepo implements WalletRepo {
  SupabaseWalletRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbWallet> currentWallet({
    int limit = 50,
    LbWalletCursor? before,
  }) async {
    final value = await _client.rpc(
      'get_my_wallet',
      params: {
        'p_limit': limit,
        'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_entry_id': before?.entryId,
      },
    );
    final json = _map(value);
    final version = (json['version'] as num?)?.toInt();
    if (version != 2) {
      throw FormatException('Unsupported wallet response version: $version');
    }
    return LbWallet(
      version: version!,
      balances: [
        for (final value in (json['balances'] as List?) ?? const [])
          if (value is Map)
            _walletBalanceFromJson(value.cast<String, dynamic>()),
      ],
      transactions: [
        for (final value in (json['transactions'] as List?) ?? const [])
          if (value is Map)
            _walletTransactionFromJson(value.cast<String, dynamic>()),
      ],
      nextCursor: switch (json['nextCursor']) {
        final Map value => LbWalletCursor(
          createdAt: DateTime.parse(value['createdAt'] as String),
          entryId: value['entryId'] as String,
        ),
        _ => null,
      },
    );
  }

  @override
  Future<List<LbCreditPack>> activeCreditPacks({
    required CreditPackProvider provider,
    required CreditPackPlatform platform,
  }) async {
    final rows = await _client
        .from('credit_pack_config')
        .select()
        .eq('status', 'active')
        .eq('provider', provider.snake)
        .eq('platform', platform.snake)
        .order('sort_order')
        .order('credit_amount');
    return [for (final row in rows) _creditPackFromRow(row)];
  }

  @override
  Future<LbTopupCheckout> createPaymongoTopup({
    required LbCreditPack pack,
    required PayMethod method,
    required CreditPackPlatform platform,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  }) async {
    final response = await _client.functions.invoke(
      'topups-create-checkout',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'packId': pack.id,
        'method': method.name,
        'platform': platform.snake,
        'idempotencyKey': idempotencyKey,
        'successUrl': successUrl.toString(),
        'cancelUrl': cancelUrl.toString(),
      },
    );
    final data = _functionData(response);
    final order = _map(data['order']);
    final checkoutUrl = Uri.tryParse(data['checkoutUrl']?.toString() ?? '');
    if (checkoutUrl == null ||
        checkoutUrl.scheme != 'https' ||
        checkoutUrl.host != 'checkout.paymongo.com') {
      throw const FormatException('Backend returned an invalid checkout URL');
    }
    return LbTopupCheckout(
      orderId: order['id'] as String,
      checkoutUrl: checkoutUrl,
      creditAmount: (order['credit_amount'] as num).toInt(),
      priceCentavos: (order['price_centavos'] as num).toInt(),
    );
  }

  LbCreditPack _creditPackFromRow(Map<String, dynamic> row) => LbCreditPack(
    id: row['id'] as String,
    packCode: row['pack_code'] as String,
    revision: (row['revision'] as num).toInt(),
    provider: _enumFromSnake(
      CreditPackProvider.values,
      row['provider'] as String,
    ),
    platform: _enumFromSnake(
      CreditPackPlatform.values,
      row['platform'] as String,
    ),
    providerProductId: row['provider_product_id'] as String?,
    creditAmount: (row['credit_amount'] as num).toInt(),
    priceCentavos: (row['price_centavos'] as num).toInt(),
    currencyCode: row['currency_code'] as String,
    maxPurchasesPerDay: (row['max_purchases_per_day'] as num).toInt(),
    sortOrder: (row['sort_order'] as num).toInt(),
  );

  LbWalletBalance _walletBalanceFromJson(Map<String, dynamic> json) =>
      LbWalletBalance(
        currency: _walletCurrency(json['currencyCode'] as String),
        displayName: json['displayName'] as String,
        symbol: json['symbol'] as String,
        balance: (json['balance'] as num).toInt(),
      );

  LbWalletTransaction _walletTransactionFromJson(Map<String, dynamic> json) {
    final kind = switch (json['transactionType'] as String) {
      'topup' => LbWalletTransactionKind.topup,
      'entry_fee' => LbWalletTransactionKind.entryFee,
      'entry_refund' => LbWalletTransactionKind.entryRefund,
      'provider_reversal' => LbWalletTransactionKind.providerReversal,
      'reward_allocation' => LbWalletTransactionKind.rewardAllocation,
      'reward_grant' => LbWalletTransactionKind.rewardGrant,
      'shop_purchase' => LbWalletTransactionKind.shopPurchase,
      'shop_refund' => LbWalletTransactionKind.shopRefund,
      'admin_adjustment' => LbWalletTransactionKind.adminAdjustment,
      final value => throw FormatException(
        'Unsupported wallet transaction type: $value',
      ),
    };
    return LbWalletTransaction(
      entryId: json['entryId'] as String,
      id: json['id'] as String,
      kind: kind,
      currency: _walletCurrency(json['currencyCode'] as String),
      amount: (json['amount'] as num).toInt(),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
    );
  }

  LbWalletCurrency _walletCurrency(String code) => switch (code) {
    'entry_credit' => LbWalletCurrency.entryCredit,
    'reward_point' => LbWalletCurrency.rewardPoint,
    _ => throw FormatException('Unsupported wallet currency: $code'),
  };
}

class SupabaseHostSponsorRepo implements HostSponsorRepo {
  SupabaseHostSponsorRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<String> createTournamentDraft(LbWalletTournamentDraft draft) async {
    final response = await _client.functions.invoke(
      'organizer-tournament-create',
      body: {
        'title': draft.title,
        'game': draft.game,
        'format': draft.format,
        'entryCreditCost': draft.entryCreditCost,
        'maxTeams': draft.maxTeams,
        'minimumTeams': draft.minimumTeams,
        'belowMinimumAction': draft.belowMinimumAction,
        'rewardPointsPerCompetitor': draft.rewardPointsPerCompetitor,
        'rewardPoolCap': draft.rewardPoolCap,
        'firstPlaceBps': draft.firstPlaceBps,
        'secondPlaceBps': draft.secondPlaceBps,
        'thirdPlaceBps': draft.thirdPlaceBps,
      },
    );
    final data = _functionData(response);
    return data['id'] as String;
  }

  @override
  Future<LbHostSponsorPortal> portalForOrganizer(String organizerId) async {
    final responses = await Future.wait<dynamic>([
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .eq('organizer_id', organizerId)
          .eq('economy_mode', 'wallet_v2')
          .eq('status', 'draft')
          .order('created_at', ascending: false),
      _client
          .from('sponsor_package_config')
          .select()
          .eq('status', 'active')
          .order('sort_order')
          .order('reward_point_amount'),
    ]);
    return LbHostSponsorPortal(
      tournaments: [
        for (final row in responses[0] as List<dynamic>)
          _tournamentFromRow(_map(row)),
      ],
      packages: [
        for (final row in responses[1] as List<dynamic>)
          _packageFromRow(_map(row)),
      ],
    );
  }

  @override
  Future<LbSponsorCheckout> createCheckout({
    required String tournamentId,
    required LbSponsorPackage package,
    required PayMethod method,
    required bool showAttribution,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  }) async {
    final response = await _client.functions.invoke(
      'organizer-sponsor-checkout',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'tournamentId': tournamentId,
        'packageId': package.id,
        'method': method.name,
        'showAttribution': showAttribution,
        'idempotencyKey': idempotencyKey,
        'successUrl': successUrl.toString(),
        'cancelUrl': cancelUrl.toString(),
      },
    );
    final data = _functionData(response);
    final order = _map(data['order']);
    final checkoutUrl = Uri.tryParse(data['checkoutUrl']?.toString() ?? '');
    if (checkoutUrl == null ||
        checkoutUrl.scheme != 'https' ||
        checkoutUrl.host != 'checkout.paymongo.com') {
      throw const FormatException('Backend returned an invalid checkout URL');
    }
    return LbSponsorCheckout(
      orderId: order['id'] as String,
      checkoutUrl: checkoutUrl,
      rewardPointAmount: (order['reward_point_amount'] as num).toInt(),
      priceCentavos: (order['price_centavos'] as num).toInt(),
    );
  }

  LbSponsorPackage _packageFromRow(Map<String, dynamic> row) =>
      LbSponsorPackage(
        id: row['id'] as String,
        packageCode: row['package_code'] as String,
        displayName: row['display_name'] as String,
        description: row['description'] as String,
        rewardPointAmount: (row['reward_point_amount'] as num).toInt(),
        priceCentavos: (row['price_centavos'] as num).toInt(),
        perTournamentPurchaseLimit:
            (row['per_tournament_purchase_limit'] as num).toInt(),
        tournamentSponsorCap: (row['tournament_sponsor_cap'] as num).toInt(),
      );
}

class SupabaseShopRepo implements ShopRepo {
  SupabaseShopRepo(this._client);

  final SupabaseClient _client;

  static const _orderSelect = '*, shop_order_items(*, shop_fulfillments(*))';

  @override
  Future<List<LbShopProduct>> catalog(ShopPlatform platform) async {
    final rows = await _client
        .from('shop_products')
        .select()
        .eq('status', 'active')
        .contains('platform_visibility', [platform.snake])
        .order('sort_order')
        .order('price_reward_points');
    return [for (final row in rows) _productFromRow(_map(row))];
  }

  @override
  Future<List<LbShopOrder>> orders() async {
    final rows = await _client
        .from('shop_orders')
        .select(_orderSelect)
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final row in rows) _orderFromRow(_map(row))];
  }

  @override
  Future<LbShopPurchaseResult> purchase({
    required LbShopProduct product,
    required ShopPlatform platform,
    required int quantity,
    required String idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'shop-order-create',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'productId': product.id,
        'quantity': quantity,
        'platform': platform.snake,
        'idempotencyKey': idempotencyKey,
      },
    );
    final data = _functionData(response);
    return LbShopPurchaseResult(
      order: _orderFromParts(
        _map(data['order']),
        _map(data['item']),
        _map(data['fulfillment']),
      ),
      rewardPointBalance: (data['rewardPointBalance'] as num).toInt(),
      existing: data['existing'] as bool? ?? false,
    );
  }

  @override
  Future<LbShopPurchaseResult> cancel({
    required String orderId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      'shop-order-cancel',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'orderId': orderId,
        'reason': reason,
        'idempotencyKey': idempotencyKey,
      },
    );
    final data = _functionData(response);
    final row = await _client
        .from('shop_orders')
        .select(_orderSelect)
        .eq('id', orderId)
        .single();
    return LbShopPurchaseResult(
      order: _orderFromRow(_map(row)),
      rewardPointBalance: (data['rewardPointBalance'] as num).toInt(),
      existing: data['existing'] as bool? ?? false,
    );
  }

  LbShopProduct _productFromRow(Map<String, dynamic> row) {
    final rawPlatforms = row['platform_visibility'] as List? ?? const [];
    final rawImageUrl = row['image_url'] as String?;
    return LbShopProduct(
      id: row['id'] as String,
      productCode: row['product_code'] as String,
      revision: (row['revision'] as num).toInt(),
      displayName: row['display_name'] as String,
      description: row['description'] as String,
      category: row['category'] as String,
      fulfillmentType: row['fulfillment_type'] as String,
      priceRewardPoints: (row['price_reward_points'] as num).toInt(),
      platformVisibility: {
        for (final value in rawPlatforms)
          _enumFromSnake(ShopPlatform.values, value as String),
      },
      perUserLimit: (row['per_user_limit'] as num?)?.toInt(),
      imageUrl: rawImageUrl == null ? null : Uri.tryParse(rawImageUrl),
    );
  }

  LbShopOrder _orderFromRow(Map<String, dynamic> row) {
    final items = row['shop_order_items'] as List? ?? const [];
    final item = items.isEmpty ? <String, dynamic>{} : _map(items.first);
    final fulfillments = item['shop_fulfillments'] as List? ?? const [];
    final fulfillment = fulfillments.isEmpty
        ? <String, dynamic>{}
        : _map(fulfillments.first);
    return _orderFromParts(row, item, fulfillment);
  }

  LbShopOrder _orderFromParts(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
    Map<String, dynamic> fulfillment,
  ) => LbShopOrder(
    id: order['id'] as String,
    status: _enumFromSnake(ShopOrderStatus.values, order['status'] as String),
    totalRewardPoints: (order['total_reward_points'] as num).toInt(),
    productName: item['product_name'] as String? ?? 'Shop item',
    quantity: (item['quantity'] as num?)?.toInt() ?? 1,
    customerStatus:
        fulfillment['customer_status'] as String? ?? 'Preparing your item',
    createdAt: DateTime.parse(order['created_at'] as String),
    fulfilledAt: order['fulfilled_at'] == null
        ? null
        : DateTime.parse(order['fulfilled_at'] as String),
    refundedAt: order['refunded_at'] == null
        ? null
        : DateTime.parse(order['refunded_at'] as String),
  );
}

class SupabaseTeamsRepo implements TeamsRepo {
  SupabaseTeamsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbTeam> byId(String teamId) async {
    final responses = await Future.wait<dynamic>([
      _client.from('teams').select().eq('id', teamId).single(),
      _client.from('team_members').select('user_id').eq('team_id', teamId),
    ]);
    return _teamFromRow(
      responses[0] as Map<String, dynamic>,
      memberIds: [
        for (final row in responses[1] as List<dynamic>)
          row['user_id'] as String,
      ],
    );
  }

  @override
  Future<List<LbTeam>> forUser(String userId) async {
    final rows = await _client
        .from('team_members')
        .select('teams(*)')
        .eq('user_id', userId);
    return [
      for (final row in rows)
        if (row['teams'] != null) _teamFromRow(_map(row['teams'])),
    ];
  }

  @override
  Future<LbTeam> createTeam({
    required String name,
    required String tag,
    required String captainUserId,
  }) async {
    final row = await _client
        .from('teams')
        .insert({'name': name, 'tag': tag, 'captain_user_id': captainUserId})
        .select()
        .single();
    await _client.from('team_members').insert({
      'team_id': row['id'],
      'user_id': captainUserId,
      'role': 'captain',
    });
    return _teamFromRow(row, memberIds: [captainUserId]);
  }

  @override
  Future<void> invite({required String teamId, required String userId}) async {
    final response = await _client.functions.invoke(
      'team-invite',
      body: {'teamId': teamId, 'userId': userId},
    );
    _functionData(response);
  }

  @override
  Future<void> inviteByUsername({
    required String teamId,
    required String username,
  }) async {
    final response = await _client.functions.invoke(
      'team-invite',
      body: {'teamId': teamId, 'username': username.trim()},
    );
    _functionData(response);
  }

  @override
  Future<void> updateTeam({
    required String teamId,
    required String name,
    required String tag,
  }) async {
    final response = await _client.functions.invoke(
      'team-manage',
      body: {
        'teamId': teamId,
        'action': 'update',
        'name': name.trim(),
        'tag': tag.trim(),
      },
    );
    _functionData(response);
  }

  @override
  Future<void> removeMember({
    required String teamId,
    required String userId,
  }) async {
    final response = await _client.functions.invoke(
      'team-manage',
      body: {'teamId': teamId, 'action': 'remove_member', 'userId': userId},
    );
    _functionData(response);
  }

  @override
  Future<void> transferCaptain({
    required String teamId,
    required String userId,
  }) async {
    final response = await _client.functions.invoke(
      'team-manage',
      body: {'teamId': teamId, 'action': 'transfer_captain', 'userId': userId},
    );
    _functionData(response);
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }

  @override
  Future<void> declineInvite(String inviteId) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }

  @override
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    final response = await _client.functions.invoke(
      'team-manage',
      body: {'teamId': teamId, 'action': 'leave'},
    );
    _functionData(response);
  }
}

class SupabasePlayersRepo implements PlayersRepo {
  SupabasePlayersRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbPlayerSearchPage> search({
    String? game,
    String? username,
    Rank? minRank,
    String? region,
    bool freeAgentsOnly = false,
    String? cursor,
    int limit = 20,
  }) async {
    dynamic query = _client.from('profiles').select('*, user_rank(*)');
    final usernameTerm = username
        ?.trim()
        .replaceFirst(RegExp(r'^@'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (usernameTerm != null && usernameTerm.isNotEmpty) {
      query = query.ilike('username', '%$usernameTerm%');
    }
    if (game != null && game != 'All games') {
      query = query.contains('games', [game]);
    }
    if (region != null) query = query.eq('region', region);
    if (cursor != null) query = query.lt('id', cursor);
    final List<dynamic> rows = await query
        .order('id', ascending: false)
        .limit(limit);
    final ids = [for (final row in rows) row['id'] as String];
    final memberIds = <String>{};
    if (ids.isNotEmpty) {
      final memberships = await _client
          .from('team_members')
          .select('user_id')
          .inFilter('user_id', ids);
      memberIds.addAll([
        for (final row in memberships) row['user_id'] as String,
      ]);
    }
    final items = <LbPlayerSearchResult>[];
    for (final row in rows) {
      final user = _userFromProfile(row);
      final nested = row['user_rank'];
      final rankRow = nested is List
          ? (nested.isEmpty ? null : _map(nested.first))
          : (nested == null ? null : _map(nested));
      final rank = rankRow == null
          ? LbUserRank(
              userId: user.id,
              totalWins: 0,
              rank: Rank.recruit,
              rankUpdatedAt: DateTime.now(),
            )
          : _rankFromRow(rankRow);
      final isFreeAgent = !memberIds.contains(user.id);
      if (minRank != null && rank.rank.level < minRank.level) continue;
      if (freeAgentsOnly && !isFreeAgent) continue;
      items.add(
        LbPlayerSearchResult(
          user: user,
          rank: rank,
          games: user.games,
          isFreeAgent: isFreeAgent,
        ),
      );
    }
    return LbPlayerSearchPage(
      items: items,
      nextCursor: rows.length == limit ? rows.last['id'] as String : null,
    );
  }
}

class SupabaseLeaderboardRepo implements LeaderboardRepo {
  SupabaseLeaderboardRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<List<LbLeaderboardPlayer>> topPlayers({
    String? game,
    int limit = 20,
  }) async {
    dynamic query = _client.from('user_rank').select('*, profiles!inner(*)');
    if (game != null && game != 'All games') {
      query = query.contains('profiles.games', [game]);
    }
    final List<dynamic> rows = await query
        .order('total_wins', ascending: false)
        .limit(limit);
    return [
      for (var index = 0; index < rows.length; index++)
        LbLeaderboardPlayer(
          position: index + 1,
          user: _userFromProfile(_map(rows[index]['profiles'])),
          rank: _rankFromRow(rows[index]),
        ),
    ];
  }

  @override
  Future<List<LbLeaderboardTeam>> topTeams({
    String? game,
    int limit = 20,
  }) async {
    dynamic query = _client
        .from('matches')
        .select('winner_id, tournaments!inner(game)')
        .eq('status', 'completed')
        .not('winner_id', 'is', null);
    if (game != null && game != 'All games') {
      query = query.eq('tournaments.game', game);
    }
    final List<dynamic> winners = await query;
    final wins = <String, int>{};
    for (final row in winners) {
      final id = row['winner_id'] as String;
      wins[id] = (wins[id] ?? 0) + 1;
    }
    final orderedIds = wins.keys.toList()
      ..sort((a, b) => wins[b]!.compareTo(wins[a]!));
    final selectedIds = orderedIds.take(limit).toList();
    if (selectedIds.isEmpty) return const [];
    final teams = await _client
        .from('teams')
        .select()
        .inFilter('id', selectedIds);
    final byId = {
      for (final row in teams) row['id'] as String: _teamFromRow(row),
    };
    return [
      for (var index = 0; index < selectedIds.length; index++)
        if (byId[selectedIds[index]] case final LbTeam team)
          LbLeaderboardTeam(
            position: index + 1,
            team: team,
            wins: wins[selectedIds[index]]!,
          ),
    ];
  }

  @override
  Future<int?> playerPosition({required String userId, String? game}) async {
    final players = await topPlayers(game: game, limit: 1000);
    for (final player in players) {
      if (player.user.id == userId) return player.position;
    }
    return null;
  }
}

class SupabaseNotificationsRepo implements NotificationsRepo {
  SupabaseNotificationsRepo(this._client);
  final SupabaseClient _client;

  @override
  Stream<List<LbNotification>> watchForUser(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => [for (final row in rows) _notificationFromRow(row)]);
  }

  @override
  Future<void> markAllRead(String userId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('user_id', userId)
      .filter('read_at', 'is', null);

  @override
  Future<void> markRead(String notificationId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('id', notificationId);

  @override
  Future<void> respondToTeamInvite({
    required String invitationId,
    required bool accept,
  }) async {
    final response = await _client.functions.invoke(
      'team-invite-respond',
      body: {'invitationId': invitationId, 'accept': accept},
    );
    _functionData(response);
  }
}
