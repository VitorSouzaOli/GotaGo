import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    checkAuthStatus();
  }

  // Verifica se já temos um userId salvo no dispositivo
  Future<void> checkAuthStatus() async {
    final storedUserId = await _apiService.getUserId();
    if (storedUserId != null && storedUserId.isNotEmpty) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // Login via POST /sessions
  Future<bool> login(String login, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.client.post(
        '/sessions',
        data: {
          'login': login, // Aceita e-mail ou username
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend devolve { "user": { "id": "...", ... } }
        final userData = response.data['user'];
        _user = UserModel.fromJson(userData);

        // Guarda o ID temporariamente enquanto não usamos JWT
        await _apiService.saveUserId(_user!.id);

        _status = AuthStatus.authenticated;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Falha ao autenticar. Verifique o login/senha ou a conexão com a API.';
    }

    _isLoading = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    return false;
  }

  // Logout
  Future<void> logout() async {
    await _apiService.clearStorage();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
