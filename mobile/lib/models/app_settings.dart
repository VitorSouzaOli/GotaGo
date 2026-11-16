// Mensagem aberta em "Ajuda e suporte" (por enquanto só guardada no aparelho)
class SupportRequest {
  final String message;
  final DateTime createdAt;

  const SupportRequest({required this.message, required this.createdAt});

  factory SupportRequest.fromJson(Map<String, dynamic> json) {
    return SupportRequest(
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

// Preferências do utilizador guardadas no aparelho (o backend não as conhece)
class AppSettings {
  // Lembretes de hidratação
  final bool remindersEnabled;
  final int startMinutes; // minutos desde 00:00 (480 = 08:00)
  final int endMinutes;
  final int intervalMinutes;
  final List<bool> weekdays; // segunda a domingo
  final bool pauseOnGoal;
  final bool reminderSound;

  // Preferências e notificações
  final String appearance; // 'system' | 'light' | 'dark'
  final String volumeUnit; // 'ml'
  final bool notifyLeagues;
  final bool notifyAchievements;
  final bool notifyTips;

  // Privacidade: 'name' (nome e iniciais) | 'initials' (só iniciais)
  final String profileVisibility;

  final List<SupportRequest> supportRequests;

  const AppSettings({
    this.remindersEnabled = true,
    this.startMinutes = 8 * 60,
    this.endMinutes = 21 * 60,
    this.intervalMinutes = 120,
    this.weekdays = const [true, true, true, true, true, true, true],
    this.pauseOnGoal = true,
    this.reminderSound = false,
    this.appearance = 'system',
    this.volumeUnit = 'ml',
    this.notifyLeagues = true,
    this.notifyAchievements = true,
    this.notifyTips = false,
    this.profileVisibility = 'name',
    this.supportRequests = const [],
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppSettings();
    return AppSettings(
      remindersEnabled: json['remindersEnabled'] ?? defaults.remindersEnabled,
      startMinutes: json['startMinutes'] ?? defaults.startMinutes,
      endMinutes: json['endMinutes'] ?? defaults.endMinutes,
      intervalMinutes: json['intervalMinutes'] ?? defaults.intervalMinutes,
      weekdays: json['weekdays'] != null
          ? List<bool>.from(json['weekdays'])
          : defaults.weekdays,
      pauseOnGoal: json['pauseOnGoal'] ?? defaults.pauseOnGoal,
      reminderSound: json['reminderSound'] ?? defaults.reminderSound,
      appearance: json['appearance'] ?? defaults.appearance,
      volumeUnit: json['volumeUnit'] ?? defaults.volumeUnit,
      notifyLeagues: json['notifyLeagues'] ?? defaults.notifyLeagues,
      notifyAchievements:
          json['notifyAchievements'] ?? defaults.notifyAchievements,
      notifyTips: json['notifyTips'] ?? defaults.notifyTips,
      profileVisibility:
          json['profileVisibility'] ?? defaults.profileVisibility,
      supportRequests: (json['supportRequests'] as List? ?? [])
          .map((request) => SupportRequest.fromJson(request))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remindersEnabled': remindersEnabled,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'intervalMinutes': intervalMinutes,
      'weekdays': weekdays,
      'pauseOnGoal': pauseOnGoal,
      'reminderSound': reminderSound,
      'appearance': appearance,
      'volumeUnit': volumeUnit,
      'notifyLeagues': notifyLeagues,
      'notifyAchievements': notifyAchievements,
      'notifyTips': notifyTips,
      'profileVisibility': profileVisibility,
      'supportRequests': supportRequests.map((r) => r.toJson()).toList(),
    };
  }

  AppSettings copyWith({
    bool? remindersEnabled,
    int? startMinutes,
    int? endMinutes,
    int? intervalMinutes,
    List<bool>? weekdays,
    bool? pauseOnGoal,
    bool? reminderSound,
    String? appearance,
    String? volumeUnit,
    bool? notifyLeagues,
    bool? notifyAchievements,
    bool? notifyTips,
    String? profileVisibility,
    List<SupportRequest>? supportRequests,
  }) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      weekdays: weekdays ?? this.weekdays,
      pauseOnGoal: pauseOnGoal ?? this.pauseOnGoal,
      reminderSound: reminderSound ?? this.reminderSound,
      appearance: appearance ?? this.appearance,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      notifyLeagues: notifyLeagues ?? this.notifyLeagues,
      notifyAchievements: notifyAchievements ?? this.notifyAchievements,
      notifyTips: notifyTips ?? this.notifyTips,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      supportRequests: supportRequests ?? this.supportRequests,
    );
  }
}
