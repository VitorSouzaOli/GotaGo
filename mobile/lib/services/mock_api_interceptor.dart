import 'package:dio/dio.dart';

import 'api_service.dart';

// Modo demo: responde às rotas da API com dados falsos, sem precisar do backend.
// Ligado por padrão no `flutter run` (ver ApiService.useMock).
class MockApiInterceptor extends Interceptor {
  // Simula o tempo de resposta da rede
  static const _latency = Duration(milliseconds: 400);

  MockApiInterceptor() {
    _seedHistory();
  }

  Map<String, dynamic> _user = {
    'id': ApiService.mockUserId,
    'name': 'Vitor Souza',
    'username': 'vitor',
    'email': 'vitor@gotago.com',
    'avatarUrl': null,
    'weight': 70,
    'dailyGoal': 2500,
    'currentStreak': 6,
    'maxStreak': 8,
  };

  final _logs = <({int amount, DateTime createdAt})>[];
  final _unlocked = <String, DateTime>{
    'FIRST_DROP': DateTime.now().subtract(const Duration(days: 20)),
  };

  // Ligas da demo: membros com (nome, dias seguidos); o utilizador demo é
  // incluído pelo id, com a streak atual dele
  final _leagues =
      <String, ({String name, String code, List<String> memberIds})>{
        'league-time-do-gole': (
          name: 'Time do gole',
          code: 'GOTA-8X91',
          memberIds: [
            'breno',
            ApiService.mockUserId,
            'marina',
            'lucas',
            'ana',
            'pedro',
            'julia',
            'rafa',
          ],
        ),
        'league-gotas-do-trabalho': (
          name: 'Gotas do trabalho',
          code: 'GOTA-4K2P',
          memberIds: ['carla', ApiService.mockUserId, 'diego', 'bia', 'tiago'],
        ),
        // Fora das ligas do utilizador: dá para entrar com o código GOTA-DEMO
        'league-amigos-da-academia': (
          name: 'Amigos da academia',
          code: 'GOTA-DEMO',
          memberIds: ['marina', 'diego', 'ana'],
        ),
      };

  static const _people = {
    'breno': ('Breno Lima', 8),
    'marina': ('Marina Alves', 4),
    'lucas': ('Lucas Rocha', 3),
    'ana': ('Ana Costa', 2),
    'pedro': ('Pedro Nunes', 2),
    'julia': ('Júlia Reis', 1),
    'rafa': ('Rafa Melo', 0),
    'carla': ('Carla Dias', 9),
    'diego': ('Diego Prado', 5),
    'bia': ('Bia Santos', 3),
    'tiago': ('Tiago Luz', 1),
  };

  static const _achievements = [
    (
      'FIRST_DROP',
      'Primeira Gota',
      'Registaste o teu primeiro consumo de água no GotaGo!',
      0,
    ),
    (
      'STREAK_7_DAYS',
      'Semana Perfeita',
      'Atingiste a meta diária por 7 dias consecutivos!',
      7,
    ),
    (
      'STREAK_30_DAYS',
      'Mestre da Hidratação',
      'Mantiveste a tua meta por 30 dias seguidos!',
      30,
    ),
  ];

  // Histórico igual ao mock: hoje 1.250 ml em 4 registos, os 6 dias anteriores
  // com a meta batida e dias variados antes disso
  void _seedHistory() {
    final now = DateTime.now();
    DateTime at(int daysAgo, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

    _logs.addAll([
      (amount: 250, createdAt: at(0, 7)),
      (amount: 500, createdAt: at(0, 8)),
      (amount: 250, createdAt: at(0, 8, 45)),
      (amount: 250, createdAt: at(0, 9, 20)),
    ]);

    for (int daysAgo = 1; daysAgo <= 6; daysAgo++) {
      for (final hour in [8, 10, 12, 15, 18]) {
        _logs.add((amount: 500, createdAt: at(daysAgo, hour)));
      }
    }

    const olderTotals = [1750, 2500, 2500, 2000, 2500, 1500, 2500, 2500, 2250];
    for (int daysAgo = 7; daysAgo < 30; daysAgo++) {
      final total = olderTotals[daysAgo % olderTotals.length];
      _logs.add((amount: total, createdAt: at(daysAgo, 12)));
    }
  }

  int get _totalToday {
    final now = DateTime.now();
    return _logs
        .where(
          (log) =>
              log.createdAt.year == now.year &&
              log.createdAt.month == now.month &&
              log.createdAt.day == now.day,
        )
        .fold(0, (sum, log) => sum + log.amount);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future.delayed(_latency);

    final body = options.data is Map ? options.data as Map : const {};
    final route = '${options.method} ${options.path}';

    if (route == 'POST /sessions') {
      return handler.resolve(_ok(options, {'user': _user}));
    }

    if (route == 'POST /users') {
      _user = {
        ..._user,
        'name': body['name'] ?? _user['name'],
        'username': body['username'] ?? _user['username'],
        'email': body['email'] ?? _user['email'],
      };
      return handler.resolve(_ok(options, {'user': _user}, status: 201));
    }

    if (route == 'POST /water-logs') {
      return handler.resolve(_waterLog(options, body));
    }

    if (options.method == 'GET' && options.path.endsWith('/water-logs')) {
      final days = int.tryParse('${options.queryParameters['days']}') ?? 30;
      return handler.resolve(_ok(options, {'waterLogs': _logList(days)}));
    }

    if (options.method == 'GET' && options.path.endsWith('/achievements')) {
      return handler.resolve(
        _ok(options, {'achievements': _achievementList()}),
      );
    }

    if (options.method == 'GET' && options.path.endsWith('/leagues')) {
      final mine = _leagues.entries.where(
        (entry) => entry.value.memberIds.contains(ApiService.mockUserId),
      );
      return handler.resolve(
        _ok(options, {
          'leagues': [for (final entry in mine) _leagueJson(entry.key)],
        }),
      );
    }

    final leaderboard = RegExp(r'^/leagues/([^/]+)/leaderboard$')
        .firstMatch(options.path);
    if (options.method == 'GET' && leaderboard != null) {
      final id = leaderboard.group(1)!;
      if (_leagues.containsKey(id)) {
        return handler.resolve(_ok(options, _leaderboardJson(id)));
      }
      return handler.reject(_error(options, 'Liga não encontrada.', 404));
    }

    if (route == 'POST /leagues') {
      final id = 'league-${DateTime.now().millisecondsSinceEpoch}';
      final code = 'GOTA-${id.substring(id.length - 4)}';
      _leagues[id] = (
        name: '${body['name']}',
        code: code,
        memberIds: [ApiService.mockUserId],
      );
      return handler.resolve(
        _ok(options, {'league': _leagueJson(id)}, status: 201),
      );
    }

    if (route == 'POST /leagues/join') {
      final code = '${body['code']}'.toUpperCase();
      final entry = _leagues.entries
          .where((entry) => entry.value.code == code)
          .firstOrNull;
      if (entry == null) {
        return handler.reject(
          _error(options, 'Liga não encontrada com este código.', 404),
        );
      }
      if (entry.value.memberIds.contains(ApiService.mockUserId)) {
        return handler.reject(
          _error(options, 'Já fazes parte desta liga.', 400),
        );
      }
      entry.value.memberIds.add(ApiService.mockUserId);
      return handler.resolve(
        _ok(options, {
          'message': "Entraste na liga '${entry.value.name}' com sucesso!",
          'membership': {
            'leagueId': entry.key,
            'userId': ApiService.mockUserId,
          },
        }, status: 201),
      );
    }

    handler.reject(_error(options, 'Rota sem mock: $route', 404));
  }

  Map<String, dynamic> _leagueJson(String id) {
    final league = _leagues[id]!;
    return {
      'id': id,
      'name': league.name,
      'description': null,
      'code': league.code,
    };
  }

  // Mesmo formato de GET /leagues/:id/leaderboard, ordenado por dias seguidos
  Map<String, dynamic> _leaderboardJson(String id) {
    final members =
        [
          for (final memberId in _leagues[id]!.memberIds)
            if (memberId == ApiService.mockUserId)
              {
                'id': _user['id'],
                'name': _user['name'],
                'username': _user['username'],
                'avatarUrl': null,
                'currentStreak': _user['currentStreak'],
                'maxStreak': _user['maxStreak'],
              }
            else
              {
                'id': memberId,
                'name': _people[memberId]!.$1,
                'username': memberId,
                'avatarUrl': null,
                'currentStreak': _people[memberId]!.$2,
                'maxStreak': _people[memberId]!.$2,
              },
        ]..sort(
          (a, b) =>
              (b['currentStreak'] as int).compareTo(a['currentStreak'] as int),
        );

    return {'league': _leagueJson(id), 'leaderboard': members};
  }

  DioException _error(RequestOptions options, String message, int status) {
    return DioException(
      requestOptions: options,
      response: _ok(options, {'error': message}, status: status),
      type: DioExceptionType.badResponse,
    );
  }

  Response _waterLog(RequestOptions options, Map body) {
    final amount = (body['amount'] as num).toInt();
    final dailyGoal = _user['dailyGoal'] as int;
    final previousTotal = _totalToday;
    final createdAt = DateTime.now();
    _logs.add((amount: amount, createdAt: createdAt));
    final totalToday = _totalToday;

    // Mesma regra do backend: a streak sobe ao cruzar a meta do dia
    final streakUpdated = previousTotal < dailyGoal && totalToday >= dailyGoal;
    if (streakUpdated) {
      final streak = (_user['currentStreak'] as int) + 1;
      _user = {
        ..._user,
        'currentStreak': streak,
        'maxStreak': streak > (_user['maxStreak'] as int)
            ? streak
            : _user['maxStreak'],
      };
    }

    final newAchievements = <String>[];
    final streak = _user['currentStreak'] as int;
    for (final (code, name, _, requiredDays) in _achievements) {
      final earned = requiredDays == 0 || streak >= requiredDays;
      if (earned && !_unlocked.containsKey(code)) {
        _unlocked[code] = createdAt;
        newAchievements.add(name);
      }
    }

    return _ok(options, {
      'waterLog': {
        'id': 'log-${createdAt.millisecondsSinceEpoch}',
        'amount': amount,
        'createdAt': createdAt.toUtc().toIso8601String(),
      },
      'totalToday': totalToday,
      'dailyGoal': dailyGoal,
      'goalReached': totalToday >= dailyGoal,
      'streakUpdated': streakUpdated,
      'newAchievements': newAchievements,
      'warning': totalToday > 4000
          ? 'Atenção: o teu consumo total de hoje ultrapassou os 4000ml.'
          : null,
    }, status: 201);
  }

  List<Map<String, dynamic>> _logList(int days) {
    final now = DateTime.now();
    final oldestDay = DateTime(now.year, now.month, now.day - (days - 1));
    return [
      for (final log in _logs)
        if (!log.createdAt.isBefore(oldestDay))
          {
            'id': 'log-${log.createdAt.millisecondsSinceEpoch}',
            'amount': log.amount,
            'createdAt': log.createdAt.toUtc().toIso8601String(),
          },
    ];
  }

  List<Map<String, dynamic>> _achievementList() {
    return [
      for (final (code, name, description, _) in _achievements)
        {
          'id': code,
          'code': code,
          'name': name,
          'description': description,
          'isUnlocked': _unlocked.containsKey(code),
          'unlockedAt': _unlocked[code]?.toUtc().toIso8601String(),
        },
    ];
  }

  Response _ok(RequestOptions options, Object data, {int status = 200}) {
    return Response(requestOptions: options, data: data, statusCode: status);
  }
}
