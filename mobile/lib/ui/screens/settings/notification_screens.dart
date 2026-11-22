import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../widgets/flow_page.dart';

// "Um lembrete amigo": pede permissão de notificações.
// O app ainda não agenda notificações (precisa de um pacote como
// flutter_local_notifications); por ora a escolha fica salva nas preferências.
class NotificationPromptScreen extends StatelessWidget {
  const NotificationPromptScreen({super.key});

  Future<void> _answer(BuildContext context, bool allowed) async {
    final provider = context.read<SettingsProvider>();
    await provider.update(
      provider.settings.copyWith(
        notificationPermission: allowed ? 'granted' : 'denied',
        remindersEnabled: allowed,
      ),
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    showAppMessage(
      context,
      allowed
          ? 'Lembretes ativados. Ajuste os horários em Perfil → Lembretes.'
          : 'Tudo bem. Você pode ativar depois em Perfil → Lembretes.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Um lembrete amigo',
      subtitle: 'Permita que o GotaGo acompanhe sua rotina.',
      content: const [
        FlowCard(
          title: 'No horário que você escolher',
          body:
              'Receba lembretes suaves de hidratação e avisos importantes '
              'sobre sua conta.',
        ),
        NoteCard(
          'Você controla os horários e pode alterar as preferências a '
          'qualquer momento.',
        ),
      ],
      primary: FlowAction(
        'Permitir notificações',
        () => _answer(context, true),
      ),
      secondary: FlowAction('Agora não', () => _answer(context, false)),
    );
  }
}

// "Ative os avisos no aparelho": a permissão foi recusada antes
class NotificationsBlockedScreen extends StatelessWidget {
  const NotificationsBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Ative os avisos no aparelho',
      subtitle: 'As notificações estão bloqueadas.',
      content: const [
        FlowCard(
          title: 'Como permitir',
          body:
              'Abra os ajustes do aparelho, encontre o GotaGo e habilite as '
              'notificações. Depois, volte ao aplicativo.',
        ),
        NoteCard(
          'Seus registros e metas continuam disponíveis mesmo sem '
          'notificações.',
        ),
      ],
      primary: FlowAction('Já permiti nos ajustes', () async {
        final provider = context.read<SettingsProvider>();
        await provider.update(
          provider.settings.copyWith(notificationPermission: 'granted'),
        );
        if (context.mounted) Navigator.pop(context);
      }),
      secondary: FlowAction(
        'Continuar sem notificações',
        () => Navigator.pop(context),
      ),
    );
  }
}
