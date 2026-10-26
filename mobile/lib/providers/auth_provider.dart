import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  AuthProvider(this._apiService);

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Verifica se já temos um utilizador salvo no dispositivo
  Future<void> checkAuthStatus() async {
    _user = await _apiService.getUser();

    // Sessão salva no modo demo não existe na API real: pede login de novo
    if (_user?.id == ApiService.mockUserId && !ApiService.useMock) {
      await _apiService.clearStorage();
      _user = null;
    }

    _status = _user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  // Login via POST /sessions
  Future<bool> login(String login, String password) async {
    _startLoading();

    try {
      final response = await _apiService.client.post(
        '/sessions',
        data: {
          'login': login, // Aceita e-mail ou username
          'password': password,
        },
      );

      // Backend devolve { "user": { "id": "...", ... } }
      await _authenticate(UserModel.fromJson(response.data['user']));
      return true;
    } catch (e) {
      _fail(
        apiErrorMessage(
          e,
          known: {'Invalid credentials': 'E-mail ou senha incorretos.'},
          fallback: 'Não foi possível entrar. Tente novamente.',
        ),
      );
      return false;
    }
  }

  // Cadastro via POST /users
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _startLoading();

    final baseUsername = _usernameFromEmail(email);

    Future<Response> createUser(String username) {
      return _apiService.client.post(
        '/users',
        data: {
          'name': name,
          'username': username,
          'email': email,
          'password': password,
        },
      );
    }

    try {
      Response response;
      try {
        response = await createUser(baseUsername);
      } on DioException catch (e) {
        final data = e.response?.data;
        if (data is! Map || data['error'] != 'Username already exists') {
          rethrow;
        }
        // Username já usado: tenta de novo com um sufixo numérico
        final suffix = Random().nextInt(9000) + 1000;
        response = await createUser('$baseUsername$suffix');
      }

      await _authenticate(UserModel.fromJson(response.data['user']));
      return true;
    } catch (e) {
      _fail(
        apiErrorMessage(
          e,
          known: {'Email already exists': 'Este e-mail já está cadastrado.'},
          fallback: 'Não foi possível criar sua conta. Tente novamente.',
        ),
      );
      return false;
    }
  }

  // O backend incrementou a streak ao bater a meta: espelha localmente
  Future<void> incrementStreak() async {
    final current = _user;
    if (current == null) return;

    final newStreak = current.currentStreak + 1;
    _user = current.copyWith(
      currentStreak: newStreak,
      maxStreak: max(newStreak, current.maxStreak),
    );
    await _apiService.saveUser(_user!);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    await _apiService.clearStorage();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // O formulário de cadastro não pede username, então ele é derivado do e-mail
  String _usernameFromEmail(String email) {
    final localPart = email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return localPart.length >= 3 ? localPart : '${localPart}gota';
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _authenticate(UserModel user) async {
    _user = user;
    await _apiService.saveUser(user);
    _status = AuthStatus.authenticated;
    _isLoading = false;
    notifyListeners();
  }

  void _fail(String message) {
    _errorMessage = message;
    _isLoading = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
