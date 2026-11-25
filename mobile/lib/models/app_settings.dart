// Mensagem de uma conversa com o suporte
class SupportMessage {
  final bool fromUser;
  final String text;
  final DateTime createdAt;

  const SupportMessage({
    required this.fromUser,
    required this.text,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      fromUser: json['fromUser'] ?? true,
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromUser': fromUser,
      'text': text,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}

// Solicitação ao suporte (ainda guardada no aparelho; o backend não tem suporte)
class SupportTicket {
  final int number;
  final String subject;
  final bool closed;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.number,
    required this.subject,
    required this.messages,
    this.closed = false,
  });

  // "#001"
  String get label => '#${number.toString().padLeft(3, '0')}';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      number: json['number'] ?? 1,
      subject: json['subject'] ?? 'Solicitação',
      closed: json['closed'] ?? false,
      messages: (json['messages'] as List? ?? [])
          .map((message) => SupportMessage.fromJson(message))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'subject': subject,
      'closed': closed,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  SupportTicket withMessage(SupportMessage message) {
    return SupportTicket(
      number: number,
      subject: subject,
      closed: closed,
      messages: [...messages, message],
    );
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

  // Pedido de permissão de notificações: 'unknown' | 'granted' | 'denied'
  final String notificationPermission;

  // Preferências e notificações
  final String appearance; // 'system' | 'light' | 'dark'
  final String volumeUnit; // 'ml'
  final bool notifyLeagues;
  final bool notifyAchievements;
  final bool notifyTips;

  // Visibilidade nas ligas (nome e constância são sempre exibidos)
  final bool photoInLeagues;
  final bool shareVolume;

  // Pedido de cópia dos dados (null = nunca pedido)
  final DateTime? dataExportRequestedAt;

  final List<SupportTicket> supportTickets;

  const AppSettings({
    this.remindersEnabled = true,
    this.startMinutes = 8 * 60,
    this.endMinutes = 21 * 60,
    this.intervalMinutes = 120,
    this.weekdays = const [true, true, true, true, true, true, true],
    this.pauseOnGoal = true,
    this.reminderSound = false,
    this.notificationPermission = 'unknown',
    this.appearance = 'system',
    this.volumeUnit = 'ml',
    this.notifyLeagues = true,
    this.notifyAchievements = true,
    this.notifyTips = false,
    this.photoInLeagues = true,
    this.shareVolume = false,
    this.dataExportRequestedAt,
    this.supportTickets = const [],
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
      notificationPermission:
          json['notificationPermission'] ?? defaults.notificationPermission,
      appearance: json['appearance'] ?? defaults.appearance,
      volumeUnit: json['volumeUnit'] ?? defaults.volumeUnit,
      notifyLeagues: json['notifyLeagues'] ?? defaults.notifyLeagues,
      notifyAchievements:
          json['notifyAchievements'] ?? defaults.notifyAchievements,
      notifyTips: json['notifyTips'] ?? defaults.notifyTips,
      photoInLeagues: json['photoInLeagues'] ?? defaults.photoInLeagues,
      shareVolume: json['shareVolume'] ?? defaults.shareVolume,
      dataExportRequestedAt: json['dataExportRequestedAt'] != null
          ? DateTime.parse(json['dataExportRequestedAt']).toLocal()
          : null,
      supportTickets: (json['supportTickets'] as List? ?? [])
          .map((ticket) => SupportTicket.fromJson(ticket))
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
      'notificationPermission': notificationPermission,
      'appearance': appearance,
      'volumeUnit': volumeUnit,
      'notifyLeagues': notifyLeagues,
      'notifyAchievements': notifyAchievements,
      'notifyTips': notifyTips,
      'photoInLeagues': photoInLeagues,
      'shareVolume': shareVolume,
      'dataExportRequestedAt': dataExportRequestedAt?.toUtc().toIso8601String(),
      'supportTickets': supportTickets.map((t) => t.toJson()).toList(),
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
    String? notificationPermission,
    String? appearance,
    String? volumeUnit,
    bool? notifyLeagues,
    bool? notifyAchievements,
    bool? notifyTips,
    bool? photoInLeagues,
    bool? shareVolume,
    DateTime? dataExportRequestedAt,
    List<SupportTicket>? supportTickets,
  }) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      weekdays: weekdays ?? this.weekdays,
      pauseOnGoal: pauseOnGoal ?? this.pauseOnGoal,
      reminderSound: reminderSound ?? this.reminderSound,
      notificationPermission:
          notificationPermission ?? this.notificationPermission,
      appearance: appearance ?? this.appearance,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      notifyLeagues: notifyLeagues ?? this.notifyLeagues,
      notifyAchievements: notifyAchievements ?? this.notifyAchievements,
      notifyTips: notifyTips ?? this.notifyTips,
      photoInLeagues: photoInLeagues ?? this.photoInLeagues,
      shareVolume: shareVolume ?? this.shareVolume,
      dataExportRequestedAt:
          dataExportRequestedAt ?? this.dataExportRequestedAt,
      supportTickets: supportTickets ?? this.supportTickets,
    );
  }
}
