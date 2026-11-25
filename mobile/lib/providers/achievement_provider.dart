import 'package:flutter/material.dart';

import '../models/achievement_model.dart';
import '../services/api_service.dart';

class AchievementProvider extends ChangeNotifier {
  final ApiService _apiService;

  AchievementProvider(this._apiService);

  List<AchievementModel> _achievements = [];

  List<AchievementModel> get achievements => _achievements;
  int get total => _achievements.length;
  int get unlockedCount => _achievements.where((a) => a.isUnlocked).length;

  // Conquista desbloqueada mais recentemente (para o card da Home)
  AchievementModel? get latestUnlocked {
    final unlocked = _achievements.where((a) => a.unlockedAt != null).toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    return unlocked.isEmpty ? null : unlocked.first;
  }

  // Lista via GET /users/:userId/achievements
  Future<void> load(String userId) async {
    try {
      final response = await _apiService.client.get(
        '/users/$userId/achievements',
      );
      final list = response.data['achievements'] as List;
      _achievements = list
          .map((json) => AchievementModel.fromJson(json))
          .toList();
      notifyListeners();
    } catch (_) {
      // Mantém a lista atual; o card da Home apenas mostra o que houver
    }
  }

  // Recarrega a lista e devolve os nomes das conquistas desbloqueadas agora
  // (ex.: ao corrigir um registro ou baixar a meta)
  Future<List<String>> reload(String userId) async {
    final loadedBefore = _achievements.isNotEmpty;
    final unlockedBefore = {
      for (final a in _achievements)
        if (a.isUnlocked) a.code,
    };

    await load(userId);

    // Sem a lista anterior não dá para saber o que é novidade
    if (!loadedBefore) return [];
    return [
      for (final a in _achievements)
        if (a.isUnlocked && !unlockedBefore.contains(a.code)) a.name,
    ];
  }

  // Limpa o estado ao fazer logout
  void clear() {
    _achievements = [];
    notifyListeners();
  }
}
