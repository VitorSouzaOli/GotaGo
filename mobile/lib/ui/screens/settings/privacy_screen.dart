import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/settings_widgets.dart';

// Privacidade e segurança. Itens que dependem do backend (senha, cópia dos
// dados, exclusão) ainda avisam que estão em breve.
class PrivacyScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenHelp;

  const PrivacyScreen({
    super.key,
    required this.onBack,
    required this.onOpenHelp,
  });

  static const _visibilityLabels = {
    'name': 'Nome e iniciais',
    'initials': 'Só as iniciais',
  };

  Future<void> _pickVisibility(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    final picked = await showOptionsSheet<String>(
      context: context,
      title: 'Visibilidade do perfil',
      selected: provider.settings.profileVisibility,
      options: const [
        (value: 'name', label: 'Nome e iniciais', disabledHint: null),
        (value: 'initials', label: 'Só as iniciais', disabledHint: null),
      ],
    );
    if (picked != null) {
      await provider.update(
        provider.settings.copyWith(profileVisibility: picked),
      );
    }
  }

  void _showDevices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dispositivos conectados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.smartphone_rounded,
                  color: AppColors.tealDark,
                ),
                title: Text(
                  'Este aparelho',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Sessão atual'),
              ),
              SizedBox(height: 4),
              Text(
                'Ver e encerrar acessos em outros aparelhos estará '
                'disponível em breve.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocument(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text(
          'O texto completo será publicado antes do lançamento do GotaGo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir minha conta?'),
        content: const Text(
          'Excluir a conta apaga seu histórico, suas conquistas e sua '
          'participação nas ligas, sem volta.\n\nA exclusão ainda não está '
          'disponível pelo app. Fale com o suporte para solicitar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onOpenHelp();
            },
            child: const Text('Falar com o suporte'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibility = context
        .watch<SettingsProvider>()
        .settings
        .profileVisibility;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubpageHeader(
            title: 'Privacidade e segurança',
            subtitle: 'Mais clareza e controle sobre sua conta.',
            onBack: onBack,
          ),
          const SizedBox(height: 18),
          SettingsCard(
            title: 'Acesso à conta',
            children: [
              SettingsRow(
                title: 'Senha e métodos de acesso',
                subtitle: 'Gerencie suas formas de entrar.',
                trailing: SettingsRow.chevron,
                onTap: () =>
                    showSettingsMessage(context, 'Troca de senha em breve.'),
              ),
              SettingsRow(
                title: 'Dispositivos conectados',
                subtitle: 'Revise e encerre acessos à sua conta.',
                trailing: SettingsRow.chevron,
                onTap: () => _showDevices(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'O que os amigos veem',
            description:
                'Sua posição nas ligas é baseada nos dias de constância, não '
                'no volume de água.',
            children: [
              SettingsRow(
                title: 'Visibilidade do perfil',
                subtitle:
                    'Exibido nas ligas: '
                    '${_visibilityLabels[visibility] ?? 'Nome e iniciais'}',
                trailing: SettingsRow.chevron,
                onTap: () => _pickVisibility(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Seus dados',
            children: [
              SettingsRow(
                title: 'Solicitar cópia dos meus dados',
                subtitle: 'Histórico e informações da conta.',
                trailing: SettingsRow.chevron,
                onTap: () => showSettingsMessage(
                  context,
                  'Pedido de cópia dos dados em breve.',
                ),
              ),
              SettingsRow(
                title: 'Política de privacidade',
                trailing: SettingsRow.chevron,
                onTap: () => _showDocument(context, 'Política de privacidade'),
              ),
              SettingsRow(
                title: 'Termos de uso',
                trailing: SettingsRow.chevron,
                onTap: () => _showDocument(context, 'Termos de uso'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Excluir minha conta',
                subtitle: 'Revise as consequências antes de confirmar.',
                titleColor: AppColors.error,
                trailing: SettingsRow.chevron,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Nunca compartilhe sua senha ou códigos de acesso. O suporte não '
            'solicita essas informações.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
