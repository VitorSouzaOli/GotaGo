import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import 'mock_api_interceptor.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Endereço da API. Para trocar (celular físico, servidor publicado):
  // flutter run --dart-define=API_URL=http://192.168.0.10:3333
  static const String _apiUrl = String.fromEnvironment('API_URL');

  // Sem a flag: no emulador Android o PC é o 10.0.2.2; no resto, localhost
  static String get _baseUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3333'
        : 'http://localhost:3333';
  }

  static const _tokenKey = 'jwt_token';

  // Chamado quando o servidor recusa o token (expirado ou conta removida)
  VoidCallback? onSessionExpired;

  // Modo demo (dados falsos, sem backend).
  // Sem a flag: ligado em debug (`flutter run`) e desligado em release.
  // API real em debug: flutter run --dart-define=MOCK_API=false
  static const bool useMock = bool.hasEnvironment('MOCK_API')
      ? bool.fromEnvironment('MOCK_API')
      : kDebugMode;

  // Id do utilizador falso devolvido pelo MockApiInterceptor
  static const String mockUserId = 'demo-user';

  ApiService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    if (useMock) {
      _dio.interceptors.add(MockApiInterceptor());
      return;
    }

    // Envia o JWT em cada requisição e avisa quando ele deixa de valer
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.headers.containsKey('Authorization')) {
            onSessionExpired?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;

  Future<void> saveToken(String token) => writeValue(_tokenKey, token);

  Future<String?> getToken() => readValue(_tokenKey);

  // Guarda o utilizador inteiro para restaurar a sessão ao reabrir o app
  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final raw = await _storage.read(key: 'user');
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // Leitura e escrita genéricas para outros dados locais (ex.: total do dia)
  Future<void> writeValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readValue(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearStorage() async {
    await _storage.deleteAll();
  }
}

// Converte erros da API numa mensagem amigável em português.
// `known` traduz as mensagens de erro que o backend devolve em { "error": "..." }.
String apiErrorMessage(
  Object error, {
  Map<String, String> known = const {},
  String fallback = 'Algo deu errado. Tente novamente.',
}) {
  if (error is DioException) {
    if (error.response == null) {
      return 'Não foi possível conectar ao servidor. Verifique sua conexão.';
    }

    final data = error.response!.data;
    final serverMessage = data is Map ? data['error'] : null;
    if (serverMessage is String && known.containsKey(serverMessage)) {
      return known[serverMessage]!;
    }
  }

  return fallback;
}

// Sem resposta do servidor (sem internet, servidor desligado, timeout)
bool isConnectionError(Object error) {
  return error is DioException && error.response == null;
}

// A rota ainda não existe no backend. O Fastify responde 404 com
// { "message": "Route PATCH:/users/1 not found" }.
bool isMissingRoute(Object error) {
  if (error is! DioException || error.response?.statusCode != 404) {
    return false;
  }
  final data = error.response!.data;
  final message = data is Map ? data['message'] : null;
  return message is String && message.startsWith('Route ');
}

// Mensagem padrão para funções que ainda dependem de uma rota nova no backend
const String missingRouteMessage =
    'Esta função ainda não está disponível no servidor.';
