import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/league_model.dart';
import '../services/api_service.dart';

class LeagueProvider extends ChangeNotifier {
  final ApiService _apiService;

  LeagueProvider(this._apiService);

  // Ids das ligas guardados no aparelho, enquanto o backend não lista as ligas
  static const _storageKey = 'league_ids';

  List<LeagueModel> _leagues = [];
  String? _selectedId;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _loadedUserId;

  List<LeagueModel> get leagues => _leagues;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // Liga em destaque na aba Ligas e na Home (a primeira, se nenhuma foi escolhida)
  LeagueModel? get selected {
    for (final league in _leagues) {
      if (league.id == _selectedId) return league;
    }
    return _leagues.isEmpty ? null : _leagues.first;
  }

  // Carrega as ligas via GET /users/:userId/leagues e o ranking de cada uma.
  // Sem essa rota no backend, usa os ids guardados no aparelho.
  Future<void> load(String userId, {bool force = false}) async {
    if (_loadedUserId == userId && !force) return;
    _loadedUserId = userId;
    _isLoading = true;
    notifyListeners();

    var ids = await _readCachedIds(userId);
    try {
      final response = await _apiService.client.get('/users/$userId/leagues');
      ids = (response.data['leagues'] as List)
          .map((league) => league['id'] as String)
          .toList();
    } catch (_) {
      // Rota indisponível: mantém as ligas guardadas no aparelho
    }

    final loaded = <LeagueModel>[];
    for (final id in ids) {
      final league = await _fetchLeague(id);
      if (league != null) loaded.add(league);
    }

    _leagues = loaded;
    _isLoading = false;
    await _saveIds(userId);
    notifyListeners();
  }

  void select(String leagueId) {
    _selectedId = leagueId;
    notifyListeners();
  }

  // Criação via POST /leagues (o criador entra como primeiro membro)
  Future<bool> create({
    required String userId,
    required String name,
    String? description,
  }) async {
    _startSubmitting();
    try {
      final response = await _apiService.client.post(
        '/leagues',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          'ownerId': userId,
        },
      );
      return await _addLeague(userId, response.data['league']['id']);
    } catch (e) {
      _fail(apiErrorMessage(e, fallback: 'Não foi possível criar a liga.'));
      return false;
    }
  }

  // Entrada via POST /leagues/join com o código de convite
  Future<bool> join({required String userId, required String code}) async {
    _startSubmitting();
    try {
      final response = await _apiService.client.post(
        '/leagues/join',
        data: {'userId': userId, 'code': code},
      );
      return await _addLeague(userId, response.data['membership']['leagueId']);
    } catch (e) {
      _fail(
        apiErrorMessage(
          e,
          known: {
            'Liga não encontrada com este código.':
                'Nenhuma liga encontrada com esse código.',
            'Já fazes parte desta liga.': 'Você já faz parte desta liga.',
          },
          fallback: 'Não foi possível entrar na liga.',
        ),
      );
      return false;
    }
  }

  // Consulta a liga pelo código antes de entrar (GET /leagues/code/:code).
  // Devolve null se o código não existir. Sem a rota no backend, devolve uma
  // prévia só com o código, e o nome aparece depois de entrar.
  Future<LeaguePreview?> findByCode(String code) async {
    _startSubmitting();
    try {
      final response = await _apiService.client.get('/leagues/code/$code');
      _isSubmitting = false;
      notifyListeners();
      return LeaguePreview.fromJson(response.data['league']);
    } catch (e) {
      if (isMissingRoute(e)) {
        _isSubmitting = false;
        notifyListeners();
        return LeaguePreview(id: '', name: '', code: code, memberCount: 0);
      }
      final notFound = e is DioException && e.response?.statusCode == 404;
      _fail(
        notFound
            ? 'Código inválido ou não disponível.'
            : apiErrorMessage(e, fallback: 'Não foi possível buscar a liga.'),
      );
      return null;
    }
  }

  // Sair da liga (DELETE /leagues/:id/members/:userId)
  Future<bool> leave({required String userId, required String leagueId}) {
    return _adminAction(userId, () async {
      await _apiService.client.delete('/leagues/$leagueId/members/$userId');
      _leagues = _leagues.where((l) => l.id != leagueId).toList();
      if (_selectedId == leagueId) _selectedId = null;
    });
  }

  // Administração (só o criador): renomear, remover membro e trocar o código
  Future<bool> rename({
    required String userId,
    required String leagueId,
    required String name,
  }) {
    return _adminAction(userId, () async {
      await _apiService.client.patch(
        '/leagues/$leagueId',
        data: {'name': name},
      );
      await _refresh(leagueId);
    });
  }

  Future<bool> removeMember({
    required String userId,
    required String leagueId,
    required String memberId,
  }) {
    return _adminAction(userId, () async {
      await _apiService.client.delete('/leagues/$leagueId/members/$memberId');
      await _refresh(leagueId);
    });
  }

  Future<bool> regenerateCode({
    required String userId,
    required String leagueId,
  }) {
    return _adminAction(userId, () async {
      await _apiService.client.post('/leagues/$leagueId/code');
      await _refresh(leagueId);
    });
  }

  LeagueModel? byId(String leagueId) {
    for (final league in _leagues) {
      if (league.id == leagueId) return league;
    }
    return null;
  }

  Future<bool> _adminAction(
    String userId,
    Future<void> Function() action,
  ) async {
    _startSubmitting();
    try {
      await action();
      _isSubmitting = false;
      await _saveIds(userId);
      notifyListeners();
      return true;
    } catch (e) {
      _fail(
        isMissingRoute(e)
            ? missingRouteMessage
            : apiErrorMessage(e, fallback: 'Não foi possível salvar.'),
      );
      return false;
    }
  }

  // Busca o ranking de novo e substitui a liga na lista
  Future<void> _refresh(String leagueId) async {
    final league = await _fetchLeague(leagueId);
    if (league == null) return;
    _leagues = [for (final l in _leagues) l.id == leagueId ? league : l];
  }

  // Limpa o estado ao fazer logout
  void clear() {
    _leagues = [];
    _selectedId = null;
    _loadedUserId = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _addLeague(String userId, String leagueId) async {
    final league = await _fetchLeague(leagueId);
    if (league == null) {
      _fail('Não foi possível carregar o ranking da liga.');
      return false;
    }

    _leagues = [..._leagues.where((l) => l.id != leagueId), league];
    _selectedId = leagueId;
    _isSubmitting = false;
    await _saveIds(userId);
    notifyListeners();
    return true;
  }

  // Ranking via GET /leagues/:id/leaderboard
  Future<LeagueModel?> _fetchLeague(String leagueId) async {
    try {
      final response = await _apiService.client.get(
        '/leagues/$leagueId/leaderboard',
      );
      return LeagueModel.fromLeaderboard(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _readCachedIds(String userId) async {
    final raw = await _apiService.readValue(_storageKey);
    if (raw == null) return [];

    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['userId'] != userId) return [];
    return List<String>.from(data['ids'] ?? []);
  }

  Future<void> _saveIds(String userId) async {
    await _apiService.writeValue(
      _storageKey,
      jsonEncode({
        'userId': userId,
        'ids': _leagues.map((league) => league.id).toList(),
      }),
    );
  }

  void _startSubmitting() {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(String message) {
    _errorMessage = message;
    _isSubmitting = false;
    notifyListeners();
  }
}
