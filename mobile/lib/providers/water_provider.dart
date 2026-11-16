import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/water_log_model.dart';
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

  static const _storageKey = 'water_logs';

  // Dias de histórico carregados e guardados no aparelho (visão "Mês")
  static const historyDays = 30;

  List<WaterLogModel> _logs = [];
  int? _dailyGoal;
  // Total do dia devolvido pelo último POST (vale mais que a soma local)
  int? _serverTotalToday;
  DateTime? _serverTotalDate;
  int _selectedAmount = 250;
  bool _isAdding = false;
  String? _errorMessage;
  String? _loadedUserId;

  // Meta devolvida pelo backend no último registo (null até o primeiro)
  int? get dailyGoal => _dailyGoal;
  int get selectedAmount => _selectedAmount;
  bool get isAdding => _isAdding;
  String? get errorMessage => _errorMessage;

  // Registos de hoje, do mais recente para o mais antigo
  List<WaterLogModel> get todayLogs {
    final now = DateTime.now();
    return _logs
        .where((log) => DateUtils.isSameDay(log.createdAt, now))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get totalToday {
    final serverDate = _serverTotalDate;
    if (_serverTotalToday != null &&
        serverDate != null &&
        DateUtils.isSameDay(serverDate, DateTime.now())) {
      return _serverTotalToday!;
    }
    return todayLogs.fold(0, (sum, log) => sum + log.amount);
  }

  WaterLogModel? get lastLog {
    final logs = todayLogs;
    return logs.isEmpty ? null : logs.first;
  }

  int? get lastAmount => lastLog?.amount;
  DateTime? get lastLogAt => lastLog?.createdAt;

  // Total de cada um dos últimos `days` dias, do mais antigo até hoje
  List<int> dailyTotals(int days) {
    final now = DateTime.now();
    return List.generate(days, (index) {
      final daysAgo = days - 1 - index;
      if (daysAgo == 0) return totalToday;

      final day = DateTime(now.year, now.month, now.day - daysAgo);
      return _logs
          .where((log) => DateUtils.isSameDay(log.createdAt, day))
          .fold(0, (sum, log) => sum + log.amount);
    });
  }

  // Carrega o histórico: primeiro o guardado no aparelho, depois o do backend.
  // Se o backend ainda não tiver GET /users/:userId/water-logs, fica o local.
  Future<void> load(String userId) async {
    if (_loadedUserId == userId) return;
    _loadedUserId = userId;
    _reset();

    await _loadCache(userId);
    notifyListeners();

    try {
      final response = await _apiService.client.get(
        '/users/$userId/water-logs',
        queryParameters: {'days': historyDays},
      );
      final list = response.data['waterLogs'] as List;
      _logs = list.map((json) => WaterLogModel.fromJson(json)).toList();
      _serverTotalToday = null;
      await _saveCache(userId);
      notifyListeners();
    } catch (_) {
      // Rota indisponível: mantém o histórico local
    }
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
      _logs.add(
        WaterLogModel(
          amount: amount,
          createdAt: DateTime.parse(data['waterLog']['createdAt']).toLocal(),
        ),
      );
      _serverTotalToday = (data['totalToday'] as num).toInt();
      _serverTotalDate = DateTime.now();
      _dailyGoal = (data['dailyGoal'] as num).toInt();
      await _saveCache(userId);

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

  Future<void> _loadCache(String userId) async {
    final raw = await _apiService.readValue(_storageKey);
    if (raw == null) return;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['userId'] != userId) return;

    _dailyGoal = data['dailyGoal'];
    _logs = (data['logs'] as List)
        .map((json) => WaterLogModel.fromJson(json))
        .toList();
  }

  Future<void> _saveCache(String userId) async {
    // Descarta registos mais antigos que o período do histórico
    final now = DateTime.now();
    final oldestDay = DateTime(now.year, now.month, now.day - historyDays);
    _logs.removeWhere((log) => log.createdAt.isBefore(oldestDay));

    await _apiService.writeValue(
      _storageKey,
      jsonEncode({
        'userId': userId,
        'dailyGoal': _dailyGoal,
        'logs': _logs.map((log) => log.toJson()).toList(),
      }),
    );
  }

  void _reset() {
    _logs = [];
    _dailyGoal = null;
    _serverTotalToday = null;
    _serverTotalDate = null;
    _selectedAmount = 250;
    _errorMessage = null;
  }
}
