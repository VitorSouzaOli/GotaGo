class LeagueMember {
  final String id;
  final String name;
  final String username;
  final int currentStreak;

  LeagueMember({
    required this.id,
    required this.name,
    required this.username,
    required this.currentStreak,
  });

  factory LeagueMember.fromJson(Map<String, dynamic> json) {
    return LeagueMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeagueModel {
  final String id;
  final String name;
  final String? description;
  // Código de convite (ex.: "GOTA-8X91")
  final String code;
  // Membros já ordenados pelo backend, do maior para o menor currentStreak
  final List<LeagueMember> ranking;

  LeagueModel({
    required this.id,
    required this.name,
    required this.code,
    required this.ranking,
    this.description,
  });

  // Resposta de GET /leagues/:id/leaderboard
  factory LeagueModel.fromLeaderboard(Map<String, dynamic> json) {
    final league = json['league'] as Map<String, dynamic>;
    return LeagueModel(
      id: league['id'] ?? '',
      name: league['name'] ?? '',
      description: league['description'],
      code: league['code'] ?? '',
      ranking: (json['leaderboard'] as List)
          .map((member) => LeagueMember.fromJson(member))
          .toList(),
    );
  }

  int get memberCount => ranking.length;

  // Posição do utilizador no ranking (1, 2, 3...); null se não estiver na liga
  int? positionOf(String userId) {
    final index = ranking.indexWhere((member) => member.id == userId);
    return index == -1 ? null : index + 1;
  }
}
