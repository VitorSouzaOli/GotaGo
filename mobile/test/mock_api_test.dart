import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gotago/services/mock_api_interceptor.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio()..interceptors.add(MockApiInterceptor());
  });

  test('login devolve o utilizador demo', () async {
    final response = await dio.post(
      '/sessions',
      data: {'login': 'qualquer', 'password': 'qualquer'},
    );

    expect(response.data['user']['name'], 'Vitor Souza');
  });

  test('histórico começa com 1.250 ml hoje', () async {
    final response = await dio.get(
      '/users/demo-user/water-logs',
      queryParameters: {'days': 7},
    );
    final logs = response.data['waterLogs'] as List;
    final now = DateTime.now();
    final today = logs.where((log) {
      final at = DateTime.parse(log['createdAt']).toLocal();
      return at.year == now.year && at.month == now.month && at.day == now.day;
    });

    expect(today.length, 4);
    expect(today.fold<int>(0, (sum, log) => sum + log['amount'] as int), 1250);
  });

  test('ao bater a meta a streak sobe e libera "Semana Perfeita"', () async {
    final first = await dio.post('/water-logs', data: {'amount': 500});
    expect(first.data['totalToday'], 1750);
    expect(first.data['streakUpdated'], isFalse);

    final second = await dio.post('/water-logs', data: {'amount': 750});
    expect(second.data['totalToday'], 2500);
    expect(second.data['streakUpdated'], isTrue);
    expect(second.data['newAchievements'], ['Semana Perfeita']);
  });

  test('rota sem mock responde 404', () async {
    expect(
      () => dio.get('/leagues/1/leaderboard'),
      throwsA(isA<DioException>()),
    );
  });

  test('lista as ligas do utilizador demo com ranking', () async {
    final response = await dio.get('/users/demo-user/leagues');
    final leagues = response.data['leagues'] as List;
    expect(leagues.map((l) => l['name']), [
      'Time do gole',
      'Gotas do trabalho',
    ]);

    final ranking = await dio.get(
      '/leagues/${leagues.first['id']}/leaderboard',
    );
    final names = (ranking.data['leaderboard'] as List).map((m) => m['name']);
    expect(names.take(2), ['Breno Lima', 'Vitor Souza']);
  });

  test('entrar com código: RITMO6 funciona e código errado falha', () async {
    final joined = await dio.post(
      '/leagues/join',
      data: {'userId': 'demo-user', 'code': 'ritmo6'},
    );
    expect(joined.data['membership']['leagueId'], 'league-ritmo-de-agua');

    expect(
      () => dio.post(
        '/leagues/join',
        data: {'userId': 'demo-user', 'code': 'GOTA-0000'},
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('criar liga coloca o utilizador como único membro', () async {
    final created = await dio.post(
      '/leagues',
      data: {'name': 'Família', 'ownerId': 'demo-user'},
    );
    final id = created.data['league']['id'];

    final ranking = await dio.get('/leagues/$id/leaderboard');
    expect((ranking.data['leaderboard'] as List).length, 1);
  });
}
