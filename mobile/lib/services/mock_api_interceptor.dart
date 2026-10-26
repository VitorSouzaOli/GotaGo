import 'package:dio/dio.dart';

import 'api_service.dart';

// Modo demo: responde às rotas da API com dados falsos, sem precisar do backend.
// Ligado por padrão no `flutter run` (ver ApiService.useMock).
class MockApiInterceptor extends Interceptor {
  // Simula o tempo de resposta da rede
  static const _latency = Duration(milliseconds: 400);

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

  int _totalToday = 0;
  final _unlocked = <String, DateTime>{};

  static const _achievements = [
    ('FIRST_DROP', 'Primeira Gota', 'Registaste o teu primeiro consumo de água no GotaGo!'),
    ('STREAK_3_DAYS', '3 Dias Hidratado', 'Atingiste a meta diária por 3 dias consecutivos!'),
    ('STREAK_7_DAYS', 'Semana Perfeita', 'Atingiste a meta diária por 7 dias consecutivos!'),
  ];

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
        'currentStreak': 0,
        'maxStreak': 0,
      };
      return handler.resolve(_ok(options, {'user': _user}, status: 201));
    }

    if (route == 'POST /water-logs') {
      return handler.resolve(_waterLog(options, body));
    }

    if (options.method == 'GET' && options.path.endsWith('/achievements')) {
      return handler.resolve(_ok(options, {'achievements': _achievementList()}));
    }

    handler.reject(
      DioException(
        requestOptions: options,
        response: _ok(options, {'error': 'Rota sem mock: $route'}, status: 404),
        type: DioExceptionType.badResponse,
      ),
    );
  }

  Response _waterLog(RequestOptions options, Map body) {
    final amount = (body['amount'] as num).toInt();
    final dailyGoal = _user['dailyGoal'] as int;
    final previousTotal = _totalToday;
    _totalToday += amount;

    // Mesma regra do backend: a streak sobe ao cruzar a meta do dia
    final streakUpdated = previousTotal < dailyGoal && _totalToday >= dailyGoal;
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
    if (!_unlocked.containsKey('FIRST_DROP')) {
      _unlocked['FIRST_DROP'] = DateTime.now();
      newAchievements.add('Primeira Gota');
    }

    return _ok(options, {
      'waterLog': {
        'id': 'log-${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
      'totalToday': _totalToday,
      'dailyGoal': dailyGoal,
      'goalReached': _totalToday >= dailyGoal,
      'streakUpdated': streakUpdated,
      'newAchievements': newAchievements,
      'warning': _totalToday > 4000
          ? 'Atenção: o teu consumo total de hoje ultrapassou os 4000ml.'
          : null,
    }, status: 201);
  }

  List<Map<String, dynamic>> _achievementList() {
    return [
      for (final (code, name, description) in _achievements)
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
