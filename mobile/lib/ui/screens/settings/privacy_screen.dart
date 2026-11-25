import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/flow_page.dart';
import 'account_screens.dart';
import 'legal_screens.dart';
import 'widgets/settings_widgets.dart';

// Privacidade e segurança: cada item abre a sua tela
class PrivacyScreen extends StatelessWidget {
  final VoidCallback onBack;

  const PrivacyScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final exportRequested = settings.dataExportRequestedAt != null;

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
                onTap: () => pushPage(context, const AccessMethodsScreen()),
              ),
              SettingsRow(
                title: 'Dispositivos conectados',
                subtitle: 'Revise e encerre acessos à sua conta.',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(context, const DevicesScreen()),
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
                subtitle: 'Nome e informações exibidas nas ligas.',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(context, const ProfileVisibilityScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Seus dados',
            children: [
              SettingsRow(
                title: 'Solicitar cópia dos meus dados',
                subtitle: exportRequested
                    ? 'Pedido em processamento.'
                    : 'Histórico e informações da conta.',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(
                  context,
                  exportRequested
                      ? const DataCopyRequestedScreen()
                      : const DataCopyScreen(),
                ),
              ),
              SettingsRow(
                title: 'Política de privacidade',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(context, const PrivacyPolicyScreen()),
              ),
              SettingsRow(
                title: 'Termos de uso',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(context, const TermsScreen()),
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
                onTap: () => pushPage(context, const DeleteAccountScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
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
