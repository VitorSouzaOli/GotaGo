import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // URL para o Emulador Android (porta 3333)
  static const String _baseUrl = 'http://10.0.2.2:3333';

  ApiService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Preparado para injetar o JWT futuramente
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Dio get client => _dio;

  // Guarda o utilizador inteiro para restaurar a sessão ao reabrir o app
  // (enquanto não usamos JWT nem temos GET /me no backend)
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
