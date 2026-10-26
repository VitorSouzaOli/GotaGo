import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

// Resultado de um registo de água, para a tela reagir (streak, conquistas, alerta)
class WaterLogResult {
  final bool streakUpdated;
  final List<String> newAchievements;
  final String? warning;

  WaterLogResult({
    required this.streakUpdated,
    required this.newAchievements,
    this.warning,
  });
}

class WaterProvider extends ChangeNotifier {
  final ApiService _apiService;

  WaterProvider(this._apiService);

  static const _storageKey = 'water_today';

  int _totalToday = 0;
  int? _dailyGoal;
  int _selectedAmount = 250;
  int? _lastAmount;
  DateTime? _lastLogAt;
  bool _isAdding = false;
  String? _errorMessage;
  String? _loadedUserId;

  int get totalToday => _totalToday;
  // Meta devolvida pelo backend no último registo (null até o primeiro)
  int? get dailyGoal => _dailyGoal;
  int get selectedAmount => _selectedAmount;
  int? get lastAmount => _lastAmount;
  DateTime? get lastLogAt => _lastLogAt;
  bool get isAdding => _isAdding;
  String? get errorMessage => _errorMessage;

  // Recupera o total de hoje salvo no aparelho
  // (o backend ainda não tem uma rota GET para o consumo do dia)
  Future<void> loadToday(String userId) async {
    if (_loadedUserId == userId) return;
    _loadedUserId = userId;
    _reset();

    final raw = await _apiService.readValue(_storageKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['userId'] == userId && data['date'] == _todayKey()) {
        _totalToday = data['total'] ?? 0;
        _dailyGoal = data['dailyGoal'];
        _lastAmount = data['lastAmount'];
        _lastLogAt = data['lastLogAt'] != null
            ? DateTime.parse(data['lastLogAt'])
            : null;
      }
    }

    notifyListeners();
  }

  // Registo via POST /water-logs
  Future<WaterLogResult?> addWater(String userId, int amount) async {
    if (_isAdding) return null;

    _isAdding = true;
    _selectedAmount = amount;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.client.post(
        '/water-logs',
        data: {'userId': userId, 'amount': amount},
      );

      final data = response.data as Map<String, dynamic>;
      _totalToday = (data['totalToday'] as num).toInt();
      _dailyGoal = (data['dailyGoal'] as num).toInt();
      _lastAmount = amount;
      _lastLogAt = DateTime.parse(data['waterLog']['createdAt']).toLocal();
      await _saveToday(userId);

      return WaterLogResult(
        streakUpdated: data['streakUpdated'] == true,
        newAchievements: List<String>.from(data['newAchievements'] ?? []),
        warning: data['warning'],
      );
    } catch (e) {
      _errorMessage = apiErrorMessage(
        e,
        fallback: 'Não foi possível registrar. Tente novamente.',
      );
      return null;
    } finally {
      _isAdding = false;
      notifyListeners();
    }
  }

  // Limpa o estado ao fazer logout
  void clear() {
    _loadedUserId = null;
    _reset();
    notifyListeners();
  }

  Future<void> _saveToday(String userId) async {
    await _apiService.writeValue(
      _storageKey,
      jsonEncode({
        'userId': userId,
        'date': _todayKey(),
        'total': _totalToday,
        'dailyGoal': _dailyGoal,
        'lastAmount': _lastAmount,
        'lastLogAt': _lastLogAt?.toIso8601String(),
      }),
    );
  }

  void _reset() {
    _totalToday = 0;
    _dailyGoal = null;
    _selectedAmount = 250;
    _lastAmount = null;
    _lastLogAt = null;
    _errorMessage = null;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
