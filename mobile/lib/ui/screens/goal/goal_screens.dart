import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/water_goal.dart';
import '../../../providers/achievement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/water_provider.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../achievements/achievement_detail_screen.dart';
import '../common/status_screens.dart';
import '../home/home_shell.dart';
import '../profile/edit_profile_screen.dart';
import '../settings/notification_screens.dart';
import 'widgets/goal_choice.dart';

// Resultado da tela de meta quando o cadastro falha por e-mail já usado
const goalSetupEmailInUse = 'emailInUse';

// "Vamos encontrar seu ritmo": última etapa do cadastro. O peso estima a meta
// (ver water_goal.dart), ou a pessoa define a própria (mínimo 2.000 ml).
class GoalSetupScreen extends StatefulWidget {
  final String name;
  final String email;
  final String password;

  const GoalSetupScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController(text: '$minDailyGoal');
  bool _useEstimate = true;

  @override
  void dispose() {
    _weightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  double? get _weight => parseDecimal(_weightController.text);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: widget.name,
      email: widget.email,
      password: widget.password,
      weightKg: _weight,
      customDailyGoal: _useEstimate
          ? null
          : int.parse(_goalController.text.trim()),
    );
    if (!mounted) return;

    if (ok) {
      context.read<ShellController>().reset();
      // Home por baixo e o convite para ativar lembretes por cima
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationPromptScreen()),
      );
      return;
    }

    switch (auth.failure) {
      case AuthFailure.emailInUse:
        Navigator.pop(context, goalSetupEmailInUse);
      case AuthFailure.offline:
        showOffline(context, _submit);
      default:
        showAppMessage(
          context,
          auth.errorMessage ?? 'Não foi possível criar sua conta.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = estimateDailyGoal(_weight);
    final isLoading = context.watch<AuthProvider>().isLoading;

    return FlowPage(
      backLabel: 'Cadastro',
      title: 'Vamos encontrar seu ritmo',
      subtitle: 'Comece com uma meta que faça sentido para você.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Seu peso',
                hint: 'Ex.: 70',
                controller: _weightController,
                suffixText: 'kg',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                helperText:
                    'Usado para estimar sua meta. Você pode ajustar depois.',
                onChanged: (_) => setState(() {}),
                validator: validateWeight,
              ),
              const SizedBox(height: 16),
              GoalChoice(
                estimate: estimate,
                estimateBody: estimateExplanation(_weight),
                useEstimate: _useEstimate,
                onChanged: (value) => setState(() => _useEstimate = value),
                customController: _goalController,
              ),
            ],
          ),
        ),
        if (_useEstimate && estimate > WaterProvider.excessLimit)
          const NoteCard(
            'Sua estimativa passa de 4.000 ml. Converse com um profissional de '
            'saúde antes de seguir essa meta.',
          ),
        const NoteCard(
          'Necessidades variam. Esta estimativa não substitui orientação '
          'profissional.',
        ),
      ],
      primary: FlowAction('Continuar', _submit, loading: isLoading),
      secondary: FlowAction(
        _useEstimate ? 'Definir meta manualmente' : 'Usar a meta calculada',
        () => setState(() => _useEstimate = !_useEstimate),
      ),
    );
  }
}

// "Editar meta diária": meta calculada pelo perfil ou meta própria (mín. 2.000)
class EditGoalScreen extends StatefulWidget {
  final String backLabel;

  const EditGoalScreen({super.key, this.backLabel = 'Início'});

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late bool _useEstimate;

  int get _currentGoal {
    final water = context.read<WaterProvider>();
    final user = context.read<AuthProvider>().user;
    return water.dailyGoal ?? user?.dailyGoal ?? minDailyGoal;
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final current = _currentGoal;
    _controller = TextEditingController(
      text: '${current < minDailyGoal ? minDailyGoal : current}',
    );
    // Começa marcada a opção que corresponde à meta de hoje
    _useEstimate =
        user?.weight != null && estimateDailyGoal(user!.weight) == current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final water = context.read<WaterProvider>();
    final achievements = context.read<AchievementProvider>();
    final user = auth.user!;
    final goal = _useEstimate
        ? estimateDailyGoal(user.weight)
        : int.parse(_controller.text.trim());

    final ok = await auth.updateProfile(dailyGoal: goal);
    if (!mounted) return;
    if (!ok) {
      if (auth.failure == AuthFailure.offline) {
        showOffline(context, _save);
      } else {
        showAppMessage(
          context,
          auth.errorMessage ?? 'Não foi possível salvar.',
        );
      }
      return;
    }

    await water.setDailyGoal(auth.user!.id, goal);
    // A meta menor pode ter completado uma sequência
    final unlocked = await achievements.reload(auth.user!.id);
    if (!mounted) return;
    replacePage(
      context,
      unlocked.isEmpty
          ? const GoalSavedScreen()
          : AchievementUnlockedScreen(name: unlocked.last),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final hasWeight = user?.weight != null;

    return FlowPage(
      backLabel: widget.backLabel,
      title: 'Editar meta diária',
      subtitle: 'Uma meta flexível para sua rotina.',
      content: [
        FlowCard(
          eyebrow: 'Sua meta atual',
          headline: '${formatMl(_currentGoal)} ml',
          body: 'O ajuste vale para sua meta de hoje.',
        ),
        Form(
          key: _formKey,
          child: GoalChoice(
            estimate: estimateDailyGoal(user?.weight),
            estimateBody: hasWeight
                ? estimateExplanation(user!.weight)
                : 'Informe seu peso em Editar perfil para calcular a meta.',
            useEstimate: _useEstimate,
            onChanged: (value) => setState(() => _useEstimate = value),
            customController: _controller,
            onEstimateUnavailable: hasWeight
                ? null
                : () => pushPage(context, const EditProfileScreen()),
          ),
        ),
        const FlowCard(
          title: 'Como definir a meta?',
          body:
              'Use a estimativa do seu perfil como ponto de partida, não como '
              'orientação médica.',
        ),
        const NoteCard(
          'O ranking das ligas valoriza constância, não litros a mais.',
        ),
      ],
      primary: FlowAction('Salvar meta', _save, loading: auth.isLoading),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Sua meta foi salva"
class GoalSavedScreen extends StatelessWidget {
  const GoalSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final water = context.watch<WaterProvider>();
    final user = context.watch<AuthProvider>().user;
    final goal = water.dailyGoal ?? user?.dailyGoal ?? 2000;
    final total = water.totalToday;
    final progress = goal > 0 ? total / goal : 0.0;

    return FlowPage(
      title: 'Sua meta foi salva',
      subtitle: 'Continue no seu ritmo, sem pressão.',
      illustration: const DropIllustration(),
      content: [
        FlowCard(
          eyebrow: 'Meta diária atualizada',
          headline: '${formatMl(goal)} ml',
          body: 'Hoje você já registrou ${formatMl(total)} ml.',
        ),
        FlowProgressBar(progress),
        NoteCard(
          progress >= 1
              ? 'Meta de hoje cumprida. Não é preciso beber mais.'
              : '${(progress * 100).round()}% da meta. Distribua sua '
                    'hidratação ao longo do dia.',
        ),
      ],
      primary: FlowAction(
        'Voltar ao início',
        () => backToShell(context, ShellTab.home),
      ),
    );
  }
}
