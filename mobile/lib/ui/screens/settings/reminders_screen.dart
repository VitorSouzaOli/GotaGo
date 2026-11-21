import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/settings_widgets.dart';
import '../../widgets/flow_page.dart';
import 'notification_screens.dart';

// Lembretes de hidratação. As escolhas ficam num rascunho e só são gravadas
// em "Salvar lembretes". O app ainda não agenda as notificações em si.
class RemindersScreen extends StatefulWidget {
  final VoidCallback onBack;

  const RemindersScreen({super.key, required this.onBack});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  static const _weekdayLetters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
  static const _weekdayNames = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  static const _intervals = [60, 90, 120, 180, 240];

  late AppSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<SettingsProvider>().settings;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final minutes = isStart ? _draft.startMinutes : _draft.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: isStart ? 'Começar às' : 'Encerrar às',
    );
    if (picked == null) return;

    final value = picked.hour * 60 + picked.minute;
    setState(() {
      _draft = isStart
          ? _draft.copyWith(startMinutes: value)
          : _draft.copyWith(endMinutes: value);
    });
  }

  Future<void> _pickInterval() async {
    final picked = await showOptionsSheet<int>(
      context: context,
      title: 'Intervalo entre lembretes',
      selected: _draft.intervalMinutes,
      options: [
        for (final minutes in _intervals)
          (value: minutes, label: formatInterval(minutes), disabledHint: null),
      ],
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(intervalMinutes: picked));
    }
  }

  void _toggleWeekday(int index) {
    final weekdays = [..._draft.weekdays];
    weekdays[index] = !weekdays[index];
    setState(() => _draft = _draft.copyWith(weekdays: weekdays));
  }

  String get _weekdaysSummary {
    final count = _draft.weekdays.where((day) => day).length;
    if (count == 7) return 'Todos os dias selecionados';
    if (count == 0) return 'Nenhum dia selecionado';
    return '$count ${count == 1 ? 'dia selecionado' : 'dias selecionados'}';
  }

  Future<void> _save() async {
    if (_draft.endMinutes <= _draft.startMinutes) {
      showSettingsMessage(
        context,
        'O horário de encerrar precisa ser depois do início.',
      );
      return;
    }

    final provider = context.read<SettingsProvider>();
    final permission = provider.settings.notificationPermission;
    await provider.update(_draft.copyWith(notificationPermission: permission));
    if (!mounted) return;
    widget.onBack();

    // Lembretes ligados precisam da permissão de notificações
    // (a tela de permissão já confirma o que acontece, sem o aviso por cima)
    if (!_draft.remindersEnabled || permission == 'granted') {
      showSettingsMessage(context, 'Lembretes salvos.');
    } else {
      pushPage(
        context,
        permission == 'denied'
            ? const NotificationsBlockedScreen()
            : const NotificationPromptScreen(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _draft.remindersEnabled;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubpageHeader(
            title: 'Lembretes de hidratação',
            subtitle: 'Um toque de cuidado ao longo do seu dia.',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 18),
          SettingsCard(
            children: [
              SettingsSwitchRow(
                title: 'Lembrar de beber água',
                subtitle: 'Lembretes no seu ritmo, sem pressão.',
                value: enabled,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(remindersEnabled: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Com os lembretes desligados, o resto fica apagado e bloqueado
          IgnorePointer(
            ignoring: !enabled,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsCard(
                    title: 'Sua rotina',
                    children: [
                      SettingsRow(
                        title: 'Começar às',
                        subtitle: 'Primeiro lembrete do dia',
                        trailing: SettingsRow.value(
                          formatClock(_draft.startMinutes),
                        ),
                        onTap: () => _pickTime(isStart: true),
                      ),
                      SettingsRow(
                        title: 'Encerrar às',
                        subtitle: 'Depois disso, hora de descansar',
                        trailing: SettingsRow.value(
                          formatClock(_draft.endMinutes),
                        ),
                        onTap: () => _pickTime(isStart: false),
                      ),
                      SettingsRow(
                        title: 'Intervalo',
                        subtitle: 'Dentro do horário escolhido',
                        trailing: SettingsRow.value(
                          formatInterval(_draft.intervalMinutes),
                        ),
                        onTap: _pickInterval,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Dias da semana',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (int i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _WeekdayChip(
                            letter: _weekdayLetters[i],
                            semanticName: _weekdayNames[i],
                            selected: _draft.weekdays[i],
                            onTap: () => _toggleWeekday(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _weekdaysSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsCard(
                    children: [
                      SettingsSwitchRow(
                        title: 'Pausar ao atingir a meta',
                        subtitle: 'Sem novos lembretes após completar o dia.',
                        value: _draft.pauseOnGoal,
                        onChanged: (value) => setState(
                          () => _draft = _draft.copyWith(pauseOnGoal: value),
                        ),
                      ),
                      SettingsSwitchRow(
                        title: 'Som do lembrete',
                        subtitle: 'Um aviso discreto para você.',
                        value: _draft.reminderSound,
                        onChanged: (value) => setState(
                          () => _draft = _draft.copyWith(reminderSound: value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Beba aos poucos. Lembretes não são uma meta extra nem um '
            'incentivo a ultrapassar sua necessidade.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Salvar lembretes')),
        ],
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  final String letter;
  final String semanticName;
  final bool selected;
  final VoidCallback onTap;

  const _WeekdayChip({
    required this.letter,
    required this.semanticName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticName,
      selected: selected,
      button: true,
      // O leitor de tela diz "domingo", não a letra "D"
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primaryDark : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
