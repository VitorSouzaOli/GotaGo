import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/api_service.dart';

// Lembretes, preferências e privacidade: tudo fica no aparelho
class SettingsProvider extends ChangeNotifier {
  final ApiService _apiService;

  SettingsProvider(this._apiService);

  static const _storageKey = 'settings';

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final raw = await _apiService.readValue(_storageKey);
    if (raw != null) {
      _settings = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    }
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _apiService.writeValue(_storageKey, jsonEncode(settings.toJson()));
  }

  Future<void> addSupportRequest(String message) {
    return update(
      _settings.copyWith(
        supportRequests: [
          ..._settings.supportRequests,
          SupportRequest(message: message, createdAt: DateTime.now()),
        ],
      ),
    );
  }

  // Volta aos padrões ao fazer logout (o storage já é apagado pelo AuthProvider)
  void clear() {
    _settings = const AppSettings();
    _loaded = false;
    notifyListeners();
  }
}
