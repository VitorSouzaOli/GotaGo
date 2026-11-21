import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/api_service.dart';

// Lembretes, preferências, privacidade e suporte: tudo fica no aparelho
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

  // Abre uma solicitação de suporte e devolve o número dela
  Future<SupportTicket> openTicket(String subject, String message) async {
    final tickets = _settings.supportTickets;
    final number = tickets.isEmpty ? 1 : tickets.last.number + 1;
    final now = DateTime.now();

    final ticket = SupportTicket(
      number: number,
      subject: subject,
      messages: [
        SupportMessage(fromUser: true, text: message, createdAt: now),
        // Na demo, uma resposta automática mostra como a conversa fica
        if (ApiService.useMock)
          SupportMessage(
            fromUser: false,
            text:
                'Recebemos sua dúvida. Enquanto isso, no Histórico, abra o '
                'dia e selecione o registro para editar ou excluir.',
            createdAt: now,
          ),
      ],
    );
    await update(_settings.copyWith(supportTickets: [...tickets, ticket]));
    return ticket;
  }

  Future<void> reply(int ticketNumber, String text) {
    return update(
      _settings.copyWith(
        supportTickets: [
          for (final ticket in _settings.supportTickets)
            ticket.number == ticketNumber
                ? ticket.withMessage(
                    SupportMessage(
                      fromUser: true,
                      text: text,
                      createdAt: DateTime.now(),
                    ),
                  )
                : ticket,
        ],
      ),
    );
  }

  SupportTicket? ticket(int number) {
    for (final ticket in _settings.supportTickets) {
      if (ticket.number == number) return ticket;
    }
    return null;
  }

  // Ao sair da conta o storage é apagado; a aparência é do aparelho e continua
  void clear() {
    final appearance = _settings.appearance;
    _settings = AppSettings(appearance: appearance);
    notifyListeners();
    _apiService.writeValue(_storageKey, jsonEncode(_settings.toJson()));
  }
}
