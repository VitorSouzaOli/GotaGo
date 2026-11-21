import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/water_log_model.dart';
import '../services/api_service.dart';

// Resultado de um registo de água, para a tela reagir (streak, conquistas, alerta)
class WaterLogResult {
  final int amount;
  final int previousTotal;
  final int totalToday;
  final int dailyGoal;
  final bool streakUpdated;
  final List<String> newAchievements;
  final String? warning;

  WaterLogResult({
    required this.amount,
    required this.previousTotal,
    required this.totalToday,
    required this.dailyGoal,
    required this.streakUpdated,
    required this.newAchievements,
    this.warning,
  });

  // Este registo fez o dia passar da meta
  bool get goalJustReached =>
      previousTotal < dailyGoal && totalToday >= dailyGoal;
}

class WaterProvider extends ChangeNotifier {
  final ApiService _apiService;

  WaterProvider(this._apiService);

  static const _storageKey = 'water_logs';

  // Dias de histórico carregados e guardados no aparelho (visão "Mês")
  static const historyDays = 30;

  // Alerta de consumo excessivo do app (o mesmo limite do backend)
  static const excessLimit = 4000;

  List<WaterLogModel> _logs = [];
  int? _dailyGoal;
  // Total do dia devolvido pelo último POST (vale mais que a soma local)
  int? _serverTotalToday;
  DateTime? _serverTotalDate;
  int _selectedAmount = 250;
  bool _isAdding = false;
  bool _isLoading = false;
  bool _offline = false;
  String? _errorMessage;
  String? _loadedUserId;

  // Meta devolvida pelo backend no último registo (null até o primeiro)
  int? get dailyGoal => _dailyGoal;
  int get selectedAmount => _selectedAmount;
  bool get isAdding => _isAdding;
  // Primeira carga em andamento, ainda sem nada guardado no aparelho
  bool get isLoading => _isLoading && _logs.isEmpty;
  // A última ação falhou por falta de conexão
  bool get offline => _offline;
  String? get errorMessage => _errorMessage;
  bool get hasAnyLogs => _logs.isNotEmpty;

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
  Future<void> load(String userId, {bool force = false}) async {
    if (_loadedUserId == userId && !force) return;
    if (_loadedUserId != userId) {
      _reset();
      await _loadCache(userId);
    }
    _loadedUserId = userId;
    _isLoading = true;
    _offline = false;
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
    } catch (e) {
      // Rota indisponível: mantém o histórico local
      _offline = isConnectionError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Registo via POST /water-logs
  Future<WaterLogResult?> addWater(String userId, int amount) async {
    if (_isAdding) return null;

    _isAdding = true;
    _offline = false;
    _selectedAmount = amount;
    _errorMessage = null;
    notifyListeners();

    final previousTotal = totalToday;
    try {
      final response = await _apiService.client.post(
        '/water-logs',
        data: {'userId': userId, 'amount': amount},
      );

      final data = response.data as Map<String, dynamic>;
      _logs.add(WaterLogModel.fromJson(data['waterLog']));
      _serverTotalToday = (data['totalToday'] as num).toInt();
      _serverTotalDate = DateTime.now();
      _dailyGoal = (data['dailyGoal'] as num).toInt();
      await _saveCache(userId);

      return WaterLogResult(
        amount: amount,
        previousTotal: previousTotal,
        totalToday: _serverTotalToday!,
        dailyGoal: _dailyGoal!,
        streakUpdated: data['streakUpdated'] == true,
        newAchievements: List<String>.from(data['newAchievements'] ?? []),
        warning: data['warning'],
      );
    } catch (e) {
      _offline = isConnectionError(e);
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

  // Correção via PATCH /water-logs/:id (rota ainda não existe no backend)
  Future<bool> updateLog(
    String userId,
    WaterLogModel log, {
    required int amount,
    required DateTime createdAt,
  }) {
    return _change(userId, () async {
      await _apiService.client.patch(
        '/water-logs/${log.id}',
        data: {
          'amount': amount,
          'createdAt': createdAt.toUtc().toIso8601String(),
        },
      );
      final index = _logs.indexWhere((l) => l.id == log.id);
      if (index != -1) {
        _logs[index] = log.copyWith(amount: amount, createdAt: createdAt);
      }
    });
  }

  // Exclusão via DELETE /water-logs/:id (rota ainda não existe no backend)
  Future<bool> deleteLog(String userId, WaterLogModel log) {
    return _change(userId, () async {
      await _apiService.client.delete('/water-logs/${log.id}');
      _logs.removeWhere((l) => l.id == log.id);
    });
  }

  // A meta mudou (Editar meta): o anel e o histórico passam a usar a nova
  Future<void> setDailyGoal(String userId, int goal) async {
    _dailyGoal = goal;
    await _saveCache(userId);
    notifyListeners();
  }

  // Limpa o estado ao fazer logout
  void clear() {
    _loadedUserId = null;
    _reset();
    notifyListeners();
  }

  Future<bool> _change(String userId, Future<void> Function() action) async {
    _errorMessage = null;
    _offline = false;
    try {
      await action();
      // O total passa a ser a soma dos registos locais
      _serverTotalToday = null;
      await _saveCache(userId);
      return true;
    } catch (e) {
      _offline = isConnectionError(e);
      _errorMessage = isMissingRoute(e)
          ? missingRouteMessage
          : apiErrorMessage(e, fallback: 'Não foi possível salvar.');
      return false;
    } finally {
      notifyListeners();
    }
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
    _offline = false;
  }
}
