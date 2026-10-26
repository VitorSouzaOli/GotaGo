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

  test('registos de água somam e sobem a streak ao bater a meta', () async {
    final first = await dio.post('/water-logs', data: {'amount': 1250});
    expect(first.data['totalToday'], 1250);
    expect(first.data['newAchievements'], ['Primeira Gota']);
    expect(first.data['streakUpdated'], isFalse);

    final second = await dio.post('/water-logs', data: {'amount': 1250});
    expect(second.data['totalToday'], 2500);
    expect(second.data['streakUpdated'], isTrue);
  });

  test('rota sem mock responde 404', () async {
    expect(
      () => dio.get('/leagues/1/leaderboard'),
      throwsA(isA<DioException>()),
    );
  });
}
