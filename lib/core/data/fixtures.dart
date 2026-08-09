import '../domain/badges.dart';
import '../domain/ranks.dart';
import '../domain/roles.dart';
import '../domain/tournament_status.dart';
import '../domain/tournament_tier.dart';
import 'models.dart';
import 'repos.dart';

/// Deterministic seed data used by every MockRepository. Reference timepoint
/// is a compile-time constant so the fixtures don't drift between runs.
class LbFixtures {
  LbFixtures._();

  /// Reference "now" — mock repos anchor countdown timers against this so
  /// UI shows meaningful times without wall-clock jitter in dev.
  static final DateTime now = DateTime(2026, 7, 26, 20, 14);

  // ── Users ───────────────────────────────────────────────────────────────

  static final LbUser me = LbUser(
    id: 'u_me',
    username: '@tonton26',
    email: 'tonton@labaan.ph',
    phone: '+639171234567',
    region: 'Manila',
    createdAt: now.subtract(const Duration(days: 240)),
  );

  static final _sagemaster = LbUser(
    id: 'u_sage',
    username: '@sagemaster',
    email: 'sage@labaan.ph',
    region: 'Cavite',
    createdAt: now.subtract(const Duration(days: 180)),
  );

  static final _thewarden = LbUser(
    id: 'u_warden',
    username: '@thewarden',
    email: 'warden@labaan.ph',
    region: 'Manila',
    createdAt: now.subtract(const Duration(days: 420)),
  );

  static final _midlaner = LbUser(
    id: 'u_mid',
    username: '@midlaner',
    email: 'mid@labaan.ph',
    region: 'Cebu',
    createdAt: now.subtract(const Duration(days: 320)),
  );

  static final _jettqueen = LbUser(
    id: 'u_jett',
    username: '@jettqueen',
    email: 'jett@labaan.ph',
    region: 'Manila',
    createdAt: now.subtract(const Duration(days: 90)),
  );

  static final _sovaMain = LbUser(
    id: 'u_sova',
    username: '@sova_main',
    email: 'sova@labaan.ph',
    region: 'Manila',
    createdAt: now.subtract(const Duration(days: 60)),
  );

  static final _viperlord = LbUser(
    id: 'u_viper',
    username: '@viperlord',
    email: 'viper@labaan.ph',
    region: 'Manila',
    createdAt: now.subtract(const Duration(days: 45)),
  );

  static List<LbUser> get allUsers => [
    me,
    _sagemaster,
    _thewarden,
    _midlaner,
    _jettqueen,
    _sovaMain,
    _viperlord,
  ];

  // ── Ranks ───────────────────────────────────────────────────────────────

  static LbUserRank rankFor(String userId, int wins) => LbUserRank(
    userId: userId,
    totalWins: wins,
    rank: Rank.forWins(wins),
    rankUpdatedAt: now.subtract(const Duration(hours: 3)),
  );

  static Map<String, LbUserRank> get ranks => {
    me.id: rankFor(me.id, 36),
    _sagemaster.id: rankFor(_sagemaster.id, 42),
    _thewarden.id: rankFor(_thewarden.id, 214),
    _midlaner.id: rankFor(_midlaner.id, 178),
    _jettqueen.id: rankFor(_jettqueen.id, 24),
    _sovaMain.id: rankFor(_sovaMain.id, 19),
    _viperlord.id: rankFor(_viperlord.id, 8),
  };

  // ── Badges ──────────────────────────────────────────────────────────────

  static List<AchievementBadge> get myBadges => const [
    AchievementBadge.firstBlood,
    AchievementBadge.hatTrick,
    AchievementBadge.eliteSlayer,
    AchievementBadge.bigGameHunter,
    AchievementBadge.veteran,
  ];

  // ── Team ────────────────────────────────────────────────────────────────

  static final LbTeam teamMnl = LbTeam(
    id: 't_mnl',
    name: 'Team MNL',
    tag: 'MNL',
    captainUserId: me.id,
    memberIds: [
      me.id,
      _sagemaster.id,
      _jettqueen.id,
      _sovaMain.id,
      _viperlord.id,
    ],
    createdAt: now.subtract(const Duration(days: 120)),
  );

  static final LbTeam teamCebuKings = LbTeam(
    id: 't_cbu',
    name: 'Cebu Kings',
    tag: 'CBU',
    captainUserId: _midlaner.id,
    memberIds: [_midlaner.id, _thewarden.id],
    createdAt: now.subtract(const Duration(days: 200)),
  );

  static final LbTeam teamDavaoGg = LbTeam(
    id: 't_dvo',
    name: 'Davao GG',
    tag: 'DVO',
    captainUserId: 'u_dvo_cap',
    memberIds: const ['u_dvo_cap', 'u_dvo_2', 'u_dvo_3'],
    createdAt: now.subtract(const Duration(days: 60)),
  );

  static List<LbTeam> get allTeams => [teamMnl, teamCebuKings, teamDavaoGg];

  // ── Tournaments ─────────────────────────────────────────────────────────

  static final LbTournament liveManilaClash = LbTournament(
    id: 't_manila_clash_42',
    title: 'Manila Clash Weekly #42',
    game: 'MLBB',
    format: BracketFormat.doubleElimination,
    tier: TournamentTier.standard,
    maxTeams: 16,
    registeredTeams: 16,
    entryFeePhp: TournamentTier.standard.entryFeePhp,
    commissionRate: TournamentTier.standard.commissionRate,
    prizePoolPhp: 1200,
    status: TournamentStatus.live,
    organizerId: 'org_mnl_league',
    moderatorIds: const ['u_mod_juan'],
    startsAt: now.subtract(const Duration(hours: 1)),
    createdAt: now.subtract(const Duration(days: 4)),
  );

  static final LbTournament manilaAscentS3 = LbTournament(
    id: 't_ascent_s3',
    title: 'Manila Ascent Cup S3',
    game: 'VALORANT',
    format: BracketFormat.doubleElimination,
    tier: TournamentTier.elite,
    maxTeams: 16,
    registeredTeams: 14,
    entryFeePhp: TournamentTier.elite.entryFeePhp,
    commissionRate: TournamentTier.elite.commissionRate,
    prizePoolPhp: 42000,
    status: TournamentStatus.fillingUp,
    organizerId: 'org_ascent',
    startsAt: now.add(const Duration(hours: 6)),
    locksAt: now.add(const Duration(hours: 2, minutes: 14, seconds: 36)),
    createdAt: now.subtract(const Duration(days: 2)),
    gabPermitNumber: 'GAB-2026-A-042',
  );

  static final LbTournament sundayNight = LbTournament(
    id: 't_sunday_night',
    title: 'Sunday Night Showdown',
    game: 'TEKKEN 8',
    format: BracketFormat.singleElimination,
    tier: TournamentTier.community,
    maxTeams: 32,
    registeredTeams: 18,
    entryFeePhp: TournamentTier.community.entryFeePhp,
    commissionRate: TournamentTier.community.commissionRate,
    prizePoolPhp: 800,
    status: TournamentStatus.open,
    organizerId: 'org_grinders',
    startsAt: now.add(const Duration(days: 1, hours: 6)),
    locksAt: now.add(const Duration(days: 1, hours: 6)),
    createdAt: now.subtract(const Duration(days: 3)),
  );

  static final LbTournament caviteOpen = LbTournament(
    id: 't_cavite_open',
    title: 'Cavite Open Qualifier',
    game: 'VALORANT',
    format: BracketFormat.doubleElimination,
    tier: TournamentTier.premium,
    maxTeams: 16,
    registeredTeams: 6,
    entryFeePhp: 0,
    commissionRate: 0,
    prizePoolPhp: 0,
    status: TournamentStatus.open,
    organizerId: 'org_cavite',
    startsAt: now.add(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 1)),
    economyMode: TournamentEconomy.walletV2,
    entryCreditCost: 250,
  );

  static final LbTournament qcGrind08 = LbTournament(
    id: 't_qc_08',
    title: 'QC Grind Series #08',
    game: 'MLBB',
    format: BracketFormat.singleElimination,
    tier: TournamentTier.community,
    maxTeams: 64,
    registeredTeams: 32,
    entryFeePhp: TournamentTier.community.entryFeePhp,
    commissionRate: TournamentTier.community.commissionRate,
    prizePoolPhp: 2500,
    status: TournamentStatus.open,
    organizerId: 'org_qc_grind',
    startsAt: now.add(const Duration(hours: 12)),
    createdAt: now.subtract(const Duration(hours: 20)),
  );

  static final LbTournament qcGrind07Completed = LbTournament(
    id: 't_qc_07',
    title: 'QC Grind Series #07',
    game: 'MLBB',
    format: BracketFormat.singleElimination,
    tier: TournamentTier.community,
    maxTeams: 64,
    registeredTeams: 64,
    entryFeePhp: TournamentTier.community.entryFeePhp,
    commissionRate: TournamentTier.community.commissionRate,
    prizePoolPhp: 5250,
    status: TournamentStatus.completed,
    organizerId: 'org_qc_grind',
    startsAt: now.subtract(const Duration(days: 5)),
    createdAt: now.subtract(const Duration(days: 12)),
  );

  static final LbTournament ascentS2Completed = LbTournament(
    id: 't_ascent_s2',
    title: 'Manila Ascent Cup S2',
    game: 'VALORANT',
    format: BracketFormat.doubleElimination,
    tier: TournamentTier.elite,
    maxTeams: 16,
    registeredTeams: 16,
    entryFeePhp: TournamentTier.elite.entryFeePhp,
    commissionRate: TournamentTier.elite.commissionRate,
    prizePoolPhp: 40000,
    status: TournamentStatus.completed,
    organizerId: 'org_ascent',
    startsAt: now.subtract(const Duration(days: 30)),
    createdAt: now.subtract(const Duration(days: 37)),
  );

  static List<LbTournament> get allTournaments => [
    liveManilaClash,
    manilaAscentS3,
    sundayNight,
    caviteOpen,
    qcGrind08,
    qcGrind07Completed,
    ascentS2Completed,
  ];

  // ── Notifications ───────────────────────────────────────────────────────

  static List<LbNotification> get myNotifications => [
    LbNotification(
      id: 'n_match_ready',
      userId: me.id,
      kind: NotifKind.matchReady,
      title: 'Match ready',
      body: 'Manila Clash #42 — quarterfinal starts in 5 min.',
      createdAt: now.subtract(const Duration(minutes: 2)),
      deepLink: '/bracket/${liveManilaClash.id}',
    ),
    LbNotification(
      id: 'n_rank_up',
      userId: me.id,
      kind: NotifKind.rankUp,
      title: 'Rank up — Champion!',
      body: 'You reached Rank 4. 14 wins to Legend.',
      createdAt: now.subtract(const Duration(minutes: 18)),
    ),
    LbNotification(
      id: 'n_team_invite',
      userId: me.id,
      kind: NotifKind.teamInvite,
      title: 'Team invite',
      body: 'Cebu Kings invited you to join as a player.',
      createdAt: now.subtract(const Duration(hours: 1)),
      payload: {
        'invitation_id': 'a1000000-0000-0000-0000-000000000001',
        'team_id': teamCebuKings.id,
      },
    ),
    LbNotification(
      id: 'n_dispute',
      userId: me.id,
      kind: NotifKind.disputeOpened,
      title: 'Dispute opened',
      body: 'Davao GG disputed your Manila Clash #42 QF score. Respond in 15m.',
      createdAt: now.subtract(const Duration(minutes: 4)),
      deepLink: '/dispute/m_u3',
      payload: {'match_id': 'm_u3'},
    ),
    LbNotification(
      id: 'n_badge',
      userId: me.id,
      kind: NotifKind.badgeEarned,
      title: 'Badge earned — Hat Trick',
      body: '3 tournament wins in a row. Nice streak.',
      createdAt: now.subtract(const Duration(days: 1)),
      readAt: now.subtract(const Duration(hours: 20)),
    ),
    LbNotification(
      id: 'n_verified',
      userId: me.id,
      kind: NotifKind.resultVerified,
      title: 'Result verified',
      body: 'Your QC Grind #07 final score was confirmed.',
      createdAt: now.subtract(const Duration(days: 2)),
      readAt: now.subtract(const Duration(days: 1, hours: 22)),
    ),
    LbNotification(
      id: 'n_starting_soon',
      userId: me.id,
      kind: NotifKind.startingSoon,
      title: 'Starting soon',
      body: 'Cavite Open Qualifier locks in 2 hours.',
      createdAt: now.subtract(const Duration(days: 2)),
      readAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  // ── Player search fixtures ──────────────────────────────────────────────

  static List<LbPlayerSearchResult> get freeAgents => [
    LbPlayerSearchResult(
      user: _sagemaster,
      rank: ranks[_sagemaster.id]!,
      games: const ['VALORANT', 'MLBB'],
      isFreeAgent: true,
    ),
    LbPlayerSearchResult(
      user: _jettqueen,
      rank: ranks[_jettqueen.id]!,
      games: const ['VALORANT'],
      isFreeAgent: true,
    ),
    LbPlayerSearchResult(
      user: _midlaner,
      rank: ranks[_midlaner.id]!,
      games: const ['MLBB'],
      isFreeAgent: false,
    ),
  ];

  // ── Audit / roles ───────────────────────────────────────────────────────

  static LbUser get superAdmin => LbUser(
    id: 'u_super_admin',
    username: '@ops',
    email: 'ops@labaan.ph',
    createdAt: now.subtract(const Duration(days: 500)),
    role: UserRole.superAdmin,
  );
}
