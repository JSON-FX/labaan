/// Tournament lifecycle from spec §5.2.
enum TournamentStatus {
  draft('Draft', 'Organizer filling in details. Not visible to players.'),
  open('Open', 'Accepting registrations. Players can pay and join.'),
  fillingUp('Filling up', 'Less than 20% of slots remaining.'),
  locked('Locked', 'Registration closed. Bracket generated. Starting soon.'),
  live('Live', 'Matches being played. Bracket updates in real time.'),
  completed(
    'Completed',
    'Winner declared. Prize pool disbursed. Ranks updated.',
  ),
  cancelled('Cancelled', 'Refunds processed automatically.');

  const TournamentStatus(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Formats used per spec §5.1.
enum BracketFormat {
  doubleElimination('Double elimination', 'Teams lose twice to be eliminated.'),
  singleElimination('Single elimination', 'One loss eliminates.'),
  roundRobin('Round robin', 'Every team plays every other team. Post-MVP.');

  const BracketFormat(this.displayName, this.description);
  final String displayName;
  final String description;
}
