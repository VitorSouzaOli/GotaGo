import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/flow_page.dart';
import 'appearance_screen.dart';
import 'widgets/settings_widgets.dart';

// Preferências e notificações (salvas no aparelho a cada alteração)
class PreferencesScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenReminders;

  const PreferencesScreen({
    super.key,
    required this.onBack,
    required this.onOpenReminders,
  });

  static const _appearanceLabels = {
    'system': 'Sistema',
    'light': 'Claro',
    'dark': 'Escuro',
  };

  Future<void> _pickUnit(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    final picked = await showOptionsSheet<String>(
      context: context,
      title: 'Unidade de volume',
      selected: provider.settings.volumeUnit,
      options: const [
        (value: 'ml', label: 'Mililitros (ml)', disabledHint: null),
        (value: 'l', label: 'Litros (L)', disabledHint: 'Em breve'),
      ],
    );
    if (picked != null) {
      await provider.update(provider.settings.copyWith(volumeUnit: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final settings = provider.settings;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubpageHeader(
            title: 'Preferências e notificações',
            subtitle: 'Escolha como o GotaGo acompanha você.',
            onBack: onBack,
          ),
          const SizedBox(height: 18),
          SettingsCard(
            title: 'No aplicativo',
            children: [
              SettingsRow(
                title: 'Aparência',
                subtitle: 'Segue a configuração do aparelho',
                trailing: SettingsRow.value(
                  _appearanceLabels[settings.appearance] ?? 'Sistema',
                ),
                onTap: () => pushPage(context, const AppearanceScreen()),
              ),
              SettingsRow(
                title: 'Unidade de volume',
                subtitle: 'Registros e progresso diário',
                trailing: SettingsRow.value(settings.volumeUnit),
                onTap: () => _pickUnit(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Fique por dentro',
            children: [
              SettingsSwitchRow(
                title: 'Novidades das ligas',
                subtitle: 'Convites e atualizações das suas equipes.',
                value: settings.notifyLeagues,
                onChanged: (value) =>
                    provider.update(settings.copyWith(notifyLeagues: value)),
              ),
              SettingsSwitchRow(
                title: 'Conquistas e sequência',
                subtitle: 'Celebre sua constância e suas medalhas.',
                value: settings.notifyAchievements,
                onChanged: (value) => provider.update(
                  settings.copyWith(notifyAchievements: value),
                ),
              ),
              SettingsSwitchRow(
                title: 'Dicas e novidades',
                subtitle: 'Conteúdos opcionais do GotaGo.',
                value: settings.notifyTips,
                onChanged: (value) =>
                    provider.update(settings.copyWith(notifyTips: value)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Cuidados com você',
            description:
                'Os avisos de consumo excessivo continuam aparecendo no '
                'aplicativo. Eles não dependem destas preferências.',
            children: [
              SettingsRow(
                title: 'Lembretes de hidratação',
                subtitle: 'Ajuste horários e frequência em outra tela.',
                trailing: SettingsRow.chevron,
                onTap: onOpenReminders,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'As permissões do aparelho também controlam a entrega de '
            'notificações.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => showSettingsMessage(
              context,
              'Abra os Ajustes do aparelho e procure por GotaGo para mudar '
              'as permissões.',
            ),
            child: const Text('Configurações do aparelho'),
          ),
        ],
      ),
    );
  }
}
