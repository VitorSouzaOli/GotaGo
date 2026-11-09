class AchievementModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  AchievementModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isUnlocked,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isUnlocked: json['isUnlocked'] == true,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt']).toLocal()
          : null,
    );
  }
}
