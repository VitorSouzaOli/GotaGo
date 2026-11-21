import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/water_log_model.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/water_provider.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../achievements/achievement_detail_screen.dart';
import '../common/status_screens.dart';

// Registra água e decide o que mostrar depois:
// - meta do dia batida agora → "Meta do dia concluída!"
// - conquista nova → celebração da conquista
// - vindo de "Registrar água" → "Água registrada!"
// - passou de 4.000 ml → aviso "Atenção ao consumo"
Future<void> registerWater(
  BuildContext context,
  int amount, {
  bool fromRegisterScreen = false,
}) async {
  final auth = context.read<AuthProvider>();
  final water = context.read<WaterProvider>();
  final achievements = context.read<AchievementProvider>();
  final user = auth.user;
  if (user == null) return;

  final result = await water.addWater(user.id, amount);
  if (!context.mounted) return;

  if (result == null) {
    if (water.offline) {
      showOffline(
        context,
        () => registerWater(
          context,
          amount,
          fromRegisterScreen: fromRegisterScreen,
        ),
      );
    } else if (water.errorMessage != null) {
      showAppMessage(context, water.errorMessage!);
    }
    return;
  }

  if (result.streakUpdated) await auth.incrementStreak();
  if (result.newAchievements.isNotEmpty) await achievements.load(user.id);
  if (!context.mounted) return;

  final excess = result.totalToday > WaterProvider.excessLimit;
  final unlocked = result.newAchievements.isEmpty
      ? null
      : result.newAchievements.last;

  Widget? next;
  if (result.goalJustReached) {
    next = GoalCompletedScreen(
      result: result,
      streak: auth.user?.currentStreak ?? 0,
      unlockedAchievement: unlocked,
    );
  } else if (unlocked != null) {
    next = AchievementUnlockedScreen(name: unlocked);
  } else if (fromRegisterScreen) {
    next = WaterRegisteredScreen(result: result, showExcessAlert: excess);
  }

  if (next == null) {
    if (excess) await showExcessAlert(context, result.totalToday);
    return;
  }

  if (fromRegisterScreen) {
    replacePage(context, next);
  } else {
    pushPage(context, next);
  }
}

// Aviso de consumo excessivo (> 4.000 ml no dia)
Future<void> showExcessAlert(BuildContext context, int total) async {
  final understood = await showConfirmDialog(
    context,
    eyebrow: 'HIDRATAÇÃO CONSCIENTE',
    title: 'Atenção ao consumo',
    body:
        'Você registrou ${formatMl(total)} ml hoje e ultrapassou o alerta de '
        '${formatMl(WaterProvider.excessLimit)} ml do aplicativo.\n\n'
        'Excesso de água pode causar hiponatremia e outros problemas. Não '
        'beba mais para competir.\n\n'
        'As necessidades variam. Se estiver com mal-estar, procure '
        'atendimento de saúde.',
    confirmLabel: 'Entendi',
    cancelLabel: 'Revisar registros',
    destructive: false,
    dismissible: false,
  );
  if (!understood && context.mounted) {
    pushPage(context, const TodayLogsScreen());
  }
}

// "Registrar água": quantidade livre, com o total antes e depois
class RegisterWaterScreen extends StatefulWidget {
  final String backLabel;

  const RegisterWaterScreen({super.key, this.backLabel = 'Início'});

  @override
  State<RegisterWaterScreen> createState() => _RegisterWaterScreenState();
}

class _RegisterWaterScreenState extends State<RegisterWaterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '300');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_controller.text.trim()) ?? 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await registerWater(context, _amount, fromRegisterScreen: true);
  }

  @override
  Widget build(BuildContext context) {
    final water = context.watch<WaterProvider>();
    final user = context.watch<AuthProvider>().user;
    final goal = water.dailyGoal ?? user?.dailyGoal ?? 2000;
    final total = water.totalToday;

    return FlowPage(
      backLabel: widget.backLabel,
      title: 'Registrar água',
      subtitle: 'Cada gole faz parte da sua rotina.',
      content: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Quantidade de água',
            hint: 'Ex.: 300',
            controller: _controller,
            suffixText: 'ml',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            helperText: 'Informe o volume que você já bebeu.',
            validator: validateWaterAmount,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
        InfoRowsCard(
          rows: [
            ('Consumido hoje', '${formatMl(total)} ml'),
            ('Após este registro', '${formatMl(total + _amount)} ml'),
            ('Meta diária', '${formatMl(goal)} ml'),
          ],
        ),
        const NoteCard(
          'Este registro contará em todas as suas ligas. Não é necessário '
          'registrá-lo novamente.',
        ),
      ],
      primary: FlowAction(
        _amount > 0 ? 'Registrar ${formatMl(_amount)} ml' : 'Registrar',
        _submit,
        loading: water.isAdding,
      ),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Água registrada!"
class WaterRegisteredScreen extends StatefulWidget {
  final WaterLogResult result;
  final bool showExcessAlert;

  const WaterRegisteredScreen({
    super.key,
    required this.result,
    this.showExcessAlert = false,
  });

  @override
  State<WaterRegisteredScreen> createState() => _WaterRegisteredScreenState();
}

class _WaterRegisteredScreenState extends State<WaterRegisteredScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showExcessAlert) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showExcessAlert(context, widget.result.totalToday),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final progress = result.totalToday / result.dailyGoal;
    final remaining = result.dailyGoal - result.totalToday;

    return FlowPage(
      title: 'Água registrada!',
      subtitle: 'Mais um passo no seu dia.',
      illustration: const DropIllustration(),
      content: [
        FlowCard(
          eyebrow: 'Registro concluído',
          headline: '+${formatMl(result.amount)} ml',
          body:
              'Total de hoje: ${formatMl(result.totalToday)} de '
              '${formatMl(result.dailyGoal)} ml.',
        ),
        FlowProgressBar(progress),
        NoteCard(
          remaining > 0
              ? '${(progress * 100).round()}% da meta · Faltam '
                    '${formatMl(remaining)} ml.'
              : 'Meta de hoje cumprida. Não é preciso beber mais.',
        ),
        const FlowCard(
          title: 'Suas ligas estão em dia',
          body: 'Este registro foi considerado em todas as suas ligas.',
        ),
      ],
      primary: FlowAction(
        'Voltar ao início',
        () => backToShell(context, ShellTab.home),
      ),
      secondary: FlowAction(
        'Ver histórico',
        () => backToShell(context, ShellTab.history),
      ),
    );
  }
}

// "Meta do dia concluída!"
class GoalCompletedScreen extends StatelessWidget {
  final WaterLogResult result;
  final int streak;
  final String? unlockedAchievement;

  const GoalCompletedScreen({
    super.key,
    required this.result,
    required this.streak,
    this.unlockedAchievement,
  });

  @override
  Widget build(BuildContext context) {
    final achievements = context.watch<AchievementProvider>();
    final unlocked = unlockedAchievement;
    final percent = (result.totalToday / result.dailyGoal * 100).round();

    return FlowPage(
      title: 'Meta do dia concluída!',
      subtitle: 'Hoje você cuidou da sua constância.',
      illustration: const TrophyIllustration(),
      content: [
        FlowCard(
          eyebrow: '$percent% da meta',
          headline:
              '${formatMl(result.totalToday)} / ${formatMl(result.dailyGoal)} ml',
          body:
              '$streak ${streak == 1 ? 'dia seguido' : 'dias seguidos'} '
              'de meta cumprida.',
        ),
        if (unlocked != null)
          FlowCard(
            title: '$unlocked desbloqueada',
            body:
                'Agora você tem ${achievements.unlockedCount} de '
                '${achievements.total} conquistas.',
          ),
        const NoteCard(
          'Parabéns pelo hábito. Não é preciso beber mais para pontuar nas '
          'ligas.',
        ),
      ],
      primary: FlowAction(
        'Voltar ao início',
        () => backToShell(context, ShellTab.home),
      ),
      secondary: unlocked != null
          ? FlowAction(
              'Ver minha conquista',
              () => replacePage(
                context,
                AchievementUnlockedScreen(name: unlocked),
              ),
            )
          : FlowAction(
              'Ver histórico',
              () => backToShell(context, ShellTab.history),
            ),
    );
  }
}

// "Registros de hoje": lista para corrigir ou excluir um lançamento
class TodayLogsScreen extends StatelessWidget {
  const TodayLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final water = context.watch<WaterProvider>();
    final user = context.watch<AuthProvider>().user;
    final goal = water.dailyGoal ?? user?.dailyGoal ?? 2000;
    final logs = water.todayLogs;
    final percent = goal > 0 ? (water.totalToday / goal * 100).round() : 0;

    return FlowPage(
      title: 'Registros de hoje',
      subtitle: 'Um dia de cada vez. Cada gole conta.',
      content: [
        FlowCard(
          eyebrow: 'Total registrado',
          headline: '${formatMl(water.totalToday)} ml',
          body: '$percent% da meta de ${formatMl(goal)} ml.',
        ),
        if (logs.isEmpty)
          const FlowCard(
            title: 'Nenhum registro hoje',
            body: 'Quando você registrar água, os lançamentos aparecem aqui.',
          )
        else
          InfoRowsCard(
            rows: [
              for (final log in logs)
                (
                  '${formatTime(log.createdAt)} · Água',
                  '${formatMl(log.amount)} ml  ›',
                ),
            ],
            onTapRow: (index) =>
                pushPage(context, EditLogScreen(log: logs[index])),
          ),
        const NoteCard(
          'Toque em um registro para corrigir a quantidade ou excluir um '
          'lançamento.',
        ),
      ],
      primary: FlowAction(
        'Registrar água',
        () => pushPage(context, const RegisterWaterScreen(backLabel: 'Voltar')),
      ),
      secondary: FlowAction(
        'Voltar ao histórico',
        () => backToShell(context, ShellTab.history),
      ),
    );
  }
}

// Confirmação de exclusão de um registro
Future<bool> confirmDeleteLog(
  BuildContext context,
  WaterLogModel log,
  int total,
) {
  final after = total - log.amount;
  return showConfirmDialog(
    context,
    title: 'Excluir este registro?',
    body:
        'Hoje · ${formatTime(log.createdAt)} · ${formatMl(log.amount)} ml\n\n'
        'Seu total passará de ${formatMl(total)} ml para ${formatMl(after)} '
        'ml. A alteração também será considerada nas suas ligas.',
    confirmLabel: 'Excluir registro',
    cancelLabel: 'Manter registro',
  );
}

// Exclui o registro (com confirmação); devolve true se excluiu
Future<bool> deleteLogWithConfirmation(
  BuildContext context,
  WaterLogModel log,
) async {
  final water = context.read<WaterProvider>();
  final user = context.read<AuthProvider>().user;
  if (user == null) return false;

  final confirmed = await confirmDeleteLog(context, log, water.totalToday);
  if (!confirmed || !context.mounted) return false;

  final ok = await water.deleteLog(user.id, log);
  if (!context.mounted) return ok;
  showAppMessage(
    context,
    ok
        ? 'Registro excluído.'
        : water.errorMessage ?? 'Não foi possível excluir.',
  );
  return ok;
}

// "Editar registro": corrige quantidade e horário, ou exclui
class EditLogScreen extends StatefulWidget {
  final WaterLogModel log;

  const EditLogScreen({super.key, required this.log});

  @override
  State<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends State<EditLogScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: '${widget.log.amount}',
  );
  late final _timeController = TextEditingController(
    text: formatTime(widget.log.createdAt),
  );
  late DateTime _createdAt = widget.log.createdAt;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_createdAt),
      helpText: 'Horário do registro',
    );
    if (picked == null) return;

    final updated = DateTime(
      _createdAt.year,
      _createdAt.month,
      _createdAt.day,
      picked.hour,
      picked.minute,
    );
    if (updated.isAfter(DateTime.now())) {
      if (mounted) showAppMessage(context, 'Escolha um horário que já passou.');
      return;
    }
    setState(() {
      _createdAt = updated;
      _timeController.text = formatTime(updated);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final water = context.read<WaterProvider>();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _saving = true);
    final ok = await water.updateLog(
      user.id,
      widget.log,
      amount: _amount,
      createdAt: _createdAt,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      showAppMessage(context, 'Registro atualizado.');
    } else {
      showAppMessage(context, water.errorMessage ?? 'Não foi possível salvar.');
    }
  }

  Future<void> _delete() async {
    final deleted = await deleteLogWithConfirmation(context, widget.log);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = context.watch<WaterProvider>().totalToday;
    final after = total - widget.log.amount + _amount;

    return FlowPage(
      title: 'Editar registro',
      subtitle: 'Corrija um lançamento sem duplicá-lo.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Quantidade',
                hint: 'Ex.: 300',
                controller: _amountController,
                suffixText: 'ml',
                keyboardType: TextInputType.number,
                helperText:
                    'Quantidade anterior: ${formatMl(widget.log.amount)} ml.',
                validator: validateWaterAmount,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Horário',
                hint: '09:20',
                controller: _timeController,
                helperText: 'Registro de hoje.',
                onTap: _pickTime,
              ),
            ],
          ),
        ),
        InfoRowsCard(
          rows: [
            ('Total atual', '${formatMl(total)} ml'),
            ('Total após salvar', '${formatMl(after)} ml'),
          ],
        ),
        const NoteCard(
          'A correção será considerada no seu histórico e em todas as suas '
          'ligas.',
        ),
      ],
      primary: FlowAction('Salvar alteração', _save, loading: _saving),
      secondary: FlowAction('Excluir registro', _delete),
    );
  }
}
