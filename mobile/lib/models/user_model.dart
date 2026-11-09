class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;
  final double? weight;
  final int dailyGoal;
  final int currentStreak;
  final int maxStreak;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.weight,
    this.dailyGoal = 2000,
    this.currentStreak = 0,
    this.maxStreak = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      weight: (json['weight'] as num?)?.toDouble(),
      dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? 2000,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      maxStreak: (json['maxStreak'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'weight': weight,
      'dailyGoal': dailyGoal,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
    };
  }

  UserModel copyWith({int? dailyGoal, int? currentStreak, int? maxStreak}) {
    return UserModel(
      id: id,
      name: name,
      username: username,
      email: email,
      avatarUrl: avatarUrl,
      weight: weight,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
    );
  }
}
