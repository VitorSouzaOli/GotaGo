import 'dart:math';

import 'package:dio/dio.dart';

import 'api_service.dart';

// Modo demo: responde às rotas da API com dados falsos, sem precisar do backend.
// Ligado por padrão no `flutter run` (ver ApiService.useMock).
//
// Também responde às rotas que o app já usa mas o backend ainda não tem
// (editar/excluir registro, editar perfil, senha, ligas...), no formato que o
// app espera. O README do mobile lista essas rotas.
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

  final _logs = <Map<String, dynamic>>[];
  final _unlocked = <String, DateTime>{
    'FIRST_DROP': DateTime.now().subtract(const Duration(days: 20)),
  };
  final _random = Random();
  int _nextLogId = 1;

  // Ligas da demo; o utilizador demo entra pelo id, com a streak atual dele
  final _leagues = <String, Map<String, dynamic>>{
    'league-time-do-gole': {
      'name': 'Time do gole',
      'code': 'GOTA8A',
      'ownerId': 'breno',
      'members': [
        'breno',
        ApiService.mockUserId,
        'marina',
        'julia',
        'caio',
        'ana',
        'pedro',
        'bia',
      ],
    },
    'league-gotas-do-trabalho': {
      'name': 'Gotas do trabalho',
      'code': 'GOTA4K',
      'ownerId': 'carla',
      'members': ['carla', ApiService.mockUserId, 'diego', 'lucas', 'tiago'],
    },
    // Fora das ligas do utilizador: dá para entrar com o código RITMO6
    'league-ritmo-de-agua': {
      'name': 'Ritmo de água',
      'code': 'RITMO6',
      'ownerId': 'marina',
      'members': ['marina', 'diego', 'ana', 'lucas', 'bia'],
    },
  };

  static const _people = {
    'breno': ('Breno Lima', 8),
    'marina': ('Marina Alves', 5),
    'julia': ('Júlia Reis', 4),
    'caio': ('Caio Torres', 3),
    'ana': ('Ana Costa', 2),
    'pedro': ('Pedro Nunes', 1),
    'bia': ('Bia Santos', 0),
    'carla': ('Carla Dias', 9),
    'diego': ('Diego Prado', 5),
    'lucas': ('Lucas Rocha', 3),
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

    void add(int amount, DateTime createdAt) {
      _logs.add({
        'id': 'log-${_nextLogId++}',
        'amount': amount,
        'createdAt': createdAt,
      });
    }

    add(250, at(0, 7));
    add(500, at(0, 8));
    add(250, at(0, 8, 45));
    add(250, at(0, 9, 20));

    for (int daysAgo = 1; daysAgo <= 6; daysAgo++) {
      for (final hour in [8, 10, 12, 15, 18]) {
        add(500, at(daysAgo, hour));
      }
    }

    const olderTotals = [1750, 2500, 2500, 2000, 2500, 1500, 2500, 2500, 2250];
    for (int daysAgo = 7; daysAgo < 30; daysAgo++) {
      add(olderTotals[daysAgo % olderTotals.length], at(daysAgo, 12));
    }
  }

  int get _totalToday {
    final now = DateTime.now();
    return _logs
        .where((log) {
          final at = log['createdAt'] as DateTime;
          return at.year == now.year &&
              at.month == now.month &&
              at.day == now.day;
        })
        .fold(0, (sum, log) => sum + (log['amount'] as int));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future.delayed(_latency);

    final body = options.data is Map ? options.data as Map : const {};
    final method = options.method;
    final path = options.path;

    Response? match(String pattern, Response Function(RegExpMatch m) build) {
      final m = RegExp('^$pattern\$').firstMatch(path);
      return m == null ? null : build(m);
    }

    try {
      final response = switch (method) {
        'POST' when path == '/sessions' => _ok(options, {'user': _user}),
        'POST' when path == '/users' => _register(options, body),
        'POST' when path == '/water-logs' => _waterLog(options, body),
        'POST' when path == '/passwords/forgot' => _ok(
          options,
          {},
          status: 202,
        ),
        'POST' when path == '/passwords/reset' => _ok(options, {}),
        'POST' when path == '/leagues' => _createLeague(options, body),
        'POST' when path == '/leagues/join' => _joinLeague(options, body),
        'GET' =>
          match(r'/users/[^/]+/water-logs', (_) => _logList(options)) ??
              match(
                r'/users/[^/]+/achievements',
                (_) => _ok(options, {'achievements': _achievementList()}),
              ) ??
              match(r'/users/[^/]+/leagues', (_) => _myLeagues(options)) ??
              match(
                r'/leagues/code/([^/]+)',
                (m) => _leagueByCode(options, m.group(1)!),
              ) ??
              match(
                r'/leagues/([^/]+)/leaderboard',
                (m) => _ok(options, _leaderboardJson(_league(m.group(1)!))),
              ),
        'PATCH' =>
          match(
                r'/water-logs/([^/]+)',
                (m) => _updateLog(options, m.group(1)!, body),
              ) ??
              match(r'/users/[^/]+/password', (_) => _ok(options, {})) ??
              match(r'/users/[^/]+', (_) => _updateUser(options, body)) ??
              match(r'/leagues/([^/]+)', (m) {
                _league(m.group(1)!)['name'] = '${body['name']}';
                return _ok(options, {});
              }),
        'DELETE' =>
          match(r'/water-logs/([^/]+)', (m) {
                _logs.removeWhere((log) => log['id'] == m.group(1));
                return _ok(options, {}, status: 204);
              }) ??
              match(r'/leagues/([^/]+)/members/([^/]+)', (m) {
                (_league(m.group(1)!)['members'] as List).remove(m.group(2));
                return _ok(options, {}, status: 204);
              }) ??
              match(r'/users/[^/]+', (_) => _ok(options, {}, status: 204)),
        _ => null,
      };

      final regenerated = method == 'POST'
          ? RegExp(r'^/leagues/([^/]+)/code$').firstMatch(path)
          : null;
      if (regenerated != null) {
        final league = _league(regenerated.group(1)!);
        league['code'] = _newCode();
        return handler.resolve(_ok(options, {'code': league['code']}));
      }

      if (response != null) return handler.resolve(response);
      handler.reject(_error(options, 'Rota sem mock: $method $path', 404));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  Response _register(RequestOptions options, Map body) {
    // Para testar o aviso de e-mail já cadastrado na demo
    if ('${body['email']}'.toLowerCase() == 'vitor@exemplo.com') {
      throw _error(options, 'Email already exists', 400);
    }

    final weight = body['weightKg'] as num?;
    final customGoal = body['customDailyGoal'] as num?;
    _user = {
      ..._user,
      'name': body['name'] ?? _user['name'],
      'username': body['username'] ?? _user['username'],
      'email': body['email'] ?? _user['email'],
      'weight': weight ?? _user['weight'],
      'dailyGoal':
          customGoal?.toInt() ??
          (weight != null ? max((weight * 35).round(), 2000) : 2000),
    };
    return _ok(options, {'user': _user}, status: 201);
  }

  Response _updateUser(RequestOptions options, Map body) {
    _user = {
      ..._user,
      if (body['name'] != null) 'name': body['name'],
      if (body['weight'] != null) 'weight': body['weight'],
      if (body['dailyGoal'] != null) 'dailyGoal': body['dailyGoal'],
    };
    return _ok(options, {'user': _user});
  }

  Response _waterLog(RequestOptions options, Map body) {
    final amount = (body['amount'] as num).toInt();
    final dailyGoal = _user['dailyGoal'] as int;
    final previousTotal = _totalToday;
    final createdAt = DateTime.now();
    final log = {
      'id': 'log-${_nextLogId++}',
      'amount': amount,
      'createdAt': createdAt,
    };
    _logs.add(log);
    final totalToday = _totalToday;

    // Mesma regra do backend: a streak sobe ao cruzar a meta do dia
    final streakUpdated = previousTotal < dailyGoal && totalToday >= dailyGoal;
    if (streakUpdated) {
      final streak = (_user['currentStreak'] as int) + 1;
      _user = {
        ..._user,
        'currentStreak': streak,
        'maxStreak': max(streak, _user['maxStreak'] as int),
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
      'waterLog': _logJson(log),
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

  Response _updateLog(RequestOptions options, String id, Map body) {
    final log = _logs.firstWhere(
      (log) => log['id'] == id,
      orElse: () => throw _error(options, 'Registro não encontrado.', 404),
    );
    if (body['amount'] != null) log['amount'] = (body['amount'] as num).toInt();
    if (body['createdAt'] != null) {
      log['createdAt'] = DateTime.parse('${body['createdAt']}').toLocal();
    }
    return _ok(options, {'waterLog': _logJson(log)});
  }

  Response _logList(RequestOptions options) {
    final days = int.tryParse('${options.queryParameters['days']}') ?? 30;
    final now = DateTime.now();
    final oldestDay = DateTime(now.year, now.month, now.day - (days - 1));
    return _ok(options, {
      'waterLogs': [
        for (final log in _logs)
          if (!(log['createdAt'] as DateTime).isBefore(oldestDay))
            _logJson(log),
      ],
    });
  }

  Map<String, dynamic> _logJson(Map<String, dynamic> log) {
    return {
      'id': log['id'],
      'amount': log['amount'],
      'createdAt': (log['createdAt'] as DateTime).toUtc().toIso8601String(),
    };
  }

  Response _myLeagues(RequestOptions options) {
    return _ok(options, {
      'leagues': [
        for (final id in _leagues.keys)
          if ((_leagues[id]!['members'] as List).contains(
            ApiService.mockUserId,
          ))
            _leagueJson(id),
      ],
    });
  }

  Response _leagueByCode(RequestOptions options, String code) {
    final id = _idByCode(code);
    if (id == null) {
      throw _error(options, 'Liga não encontrada com este código.', 404);
    }
    final league = _leagues[id]!;
    return _ok(options, {
      'league': {
        ..._leagueJson(id),
        'memberCount': (league['members'] as List).length,
        'ownerName': _nameOf(league['ownerId']),
      },
    });
  }

  Response _createLeague(RequestOptions options, Map body) {
    final id = 'league-${DateTime.now().millisecondsSinceEpoch}';
    _leagues[id] = {
      'name': '${body['name']}',
      'description': body['description'],
      'code': _newCode(),
      'ownerId': ApiService.mockUserId,
      'members': [ApiService.mockUserId],
    };
    return _ok(options, {'league': _leagueJson(id)}, status: 201);
  }

  Response _joinLeague(RequestOptions options, Map body) {
    final id = _idByCode('${body['code']}');
    if (id == null) {
      throw _error(options, 'Liga não encontrada com este código.', 404);
    }
    final members = _leagues[id]!['members'] as List;
    if (members.contains(ApiService.mockUserId)) {
      throw _error(options, 'Já fazes parte desta liga.', 400);
    }
    members.add(ApiService.mockUserId);
    return _ok(options, {
      'message': "Entraste na liga '${_leagues[id]!['name']}' com sucesso!",
      'membership': {'leagueId': id, 'userId': ApiService.mockUserId},
    }, status: 201);
  }

  Map<String, dynamic> _league(String id) {
    final league = _leagues[id];
    if (league == null) {
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 404,
          data: {'error': 'Liga não encontrada.'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return league;
  }

  String? _idByCode(String code) {
    final normalized = code.toUpperCase().replaceAll('-', '');
    for (final entry in _leagues.entries) {
      if (entry.value['code'] == normalized) return entry.key;
    }
    return null;
  }

  // Código de convite de 6 caracteres, sem letras/números ambíguos
  String _newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _nameOf(String id) =>
      id == ApiService.mockUserId ? _user['name'] : _people[id]?.$1 ?? id;

  Map<String, dynamic> _leagueJson(String id) {
    final league = _leagues[id]!;
    return {
      'id': id,
      'name': league['name'],
      'description': league['description'],
      'code': league['code'],
      'ownerId': league['ownerId'],
    };
  }

  // Mesmo formato de GET /leagues/:id/leaderboard, ordenado por dias seguidos
  Map<String, dynamic> _leaderboardJson(Map<String, dynamic> league) {
    final id = _leagues.entries.firstWhere((e) => e.value == league).key;
    final members =
        [
          for (final memberId in league['members'] as List)
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

  DioException _error(RequestOptions options, String message, int status) {
    return DioException(
      requestOptions: options,
      response: _ok(options, {'error': message}, status: status),
      type: DioExceptionType.badResponse,
    );
  }

  Response _ok(RequestOptions options, Object data, {int status = 200}) {
    return Response(requestOptions: options, data: data, statusCode: status);
  }
}
