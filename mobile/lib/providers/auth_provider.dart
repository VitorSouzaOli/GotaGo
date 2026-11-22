import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

// Por que a última ação falhou, para as telas mostrarem o estado certo
enum AuthFailure { none, invalidCredentials, emailInUse, offline, other }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  AuthProvider(this._apiService);

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  AuthFailure _failure = AuthFailure.none;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthFailure get failure => _failure;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Estimativa da meta pelo peso: mesma regra do backend (35 ml/kg, mínimo 2.000)
  static int estimateGoal(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return 2000;
    return max((weightKg * 35).round(), 2000);
  }

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
        e,
        apiErrorMessage(
          e,
          known: {'Invalid credentials': 'E-mail ou senha incorretos.'},
          fallback: 'Não foi possível entrar. Tente novamente.',
        ),
        known: {'Invalid credentials': AuthFailure.invalidCredentials},
      );
      return false;
    }
  }

  // Cadastro via POST /users. O peso ou a meta manual vêm da tela
  // "Vamos encontrar seu ritmo", depois do formulário de cadastro.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    double? weightKg,
    int? customDailyGoal,
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
          'weightKg': ?weightKg,
          'customDailyGoal': ?customDailyGoal,
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
        e,
        apiErrorMessage(
          e,
          known: {
            'Email already exists': 'Já existe uma conta com este e-mail.',
          },
          fallback: 'Não foi possível criar sua conta. Tente novamente.',
        ),
        known: {'Email already exists': AuthFailure.emailInUse},
      );
      return false;
    }
  }

  // Edição de perfil e meta via PATCH /users/:id. Sem a rota no backend,
  // a alteração fica salva só neste aparelho.
  Future<bool> updateProfile({String? name, double? weight, int? dailyGoal}) {
    return _runAccountAction(() async {
      final current = _user!;
      try {
        await _apiService.client.patch(
          '/users/${current.id}',
          data: {'name': ?name, 'weight': ?weight, 'dailyGoal': ?dailyGoal},
        );
      } catch (e) {
        if (!isMissingRoute(e)) rethrow;
      }
      _user = current.copyWith(
        name: name,
        weight: weight,
        dailyGoal: dailyGoal,
      );
      await _apiService.saveUser(_user!);
    });
  }

  // Alterar senha (logado) via PATCH /users/:id/password
  Future<bool> changePassword(String currentPassword, String newPassword) {
    return _runAccountAction(() async {
      await _apiService.client.patch(
        '/users/${_user!.id}/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    }, known: {'Invalid credentials': 'A senha atual está incorreta.'});
  }

  // Recuperação de senha: envia o link por e-mail (POST /passwords/forgot)
  Future<bool> requestPasswordReset(String email) {
    return _runAccountAction(() async {
      await _apiService.client.post(
        '/passwords/forgot',
        data: {'email': email},
      );
    });
  }

  // Nova senha a partir do link do e-mail (POST /passwords/reset)
  Future<bool> resetPassword(String token, String newPassword) {
    return _runAccountAction(() async {
      await _apiService.client.post(
        '/passwords/reset',
        data: {'token': token, 'password': newPassword},
      );
    });
  }

  // Exclusão da conta via DELETE /users/:id; depois disso, sai da conta
  Future<bool> deleteAccount() async {
    final ok = await _runAccountAction(() async {
      await _apiService.client.delete('/users/${_user!.id}');
    });
    if (ok) await logout();
    return ok;
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

  // Ações de conta que não mudam o status de login
  Future<bool> _runAccountAction(
    Future<void> Function() action, {
    Map<String, String> known = const {},
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _failure = AuthFailure.none;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (e) {
      _failure = isConnectionError(e) ? AuthFailure.offline : AuthFailure.other;
      _errorMessage = isMissingRoute(e)
          ? missingRouteMessage
          : apiErrorMessage(
              e,
              known: known,
              fallback: 'Não foi possível salvar.',
            );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startLoading() {
    _isLoading = true;
    _errorMessage = null;
    _failure = AuthFailure.none;
    notifyListeners();
  }

  Future<void> _authenticate(UserModel user) async {
    _user = user;
    await _apiService.saveUser(user);
    _status = AuthStatus.authenticated;
    _isLoading = false;
    notifyListeners();
  }

  void _fail(
    Object error,
    String message, {
    Map<String, AuthFailure> known = const {},
  }) {
    _errorMessage = message;
    _failure = AuthFailure.other;
    if (isConnectionError(error)) {
      _failure = AuthFailure.offline;
    } else if (error is DioException) {
      final data = error.response?.data;
      final serverError = data is Map ? data['error'] : null;
      _failure = known[serverError] ?? AuthFailure.other;
    }
    _isLoading = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
