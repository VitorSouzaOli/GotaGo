import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/water_provider.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../common/status_screens.dart';
import '../home/home_shell.dart';
import '../settings/notification_screens.dart';

// Resultado da tela de meta quando o cadastro falha por e-mail já usado
const goalSetupEmailInUse = 'emailInUse';

// "Vamos encontrar seu ritmo": última etapa do cadastro. O peso estima a meta
// (35 ml/kg, mínimo 2.000), ou a pessoa define a meta manualmente.
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
  final _goalController = TextEditingController(text: '2000');
  bool _manual = false;

  @override
  void dispose() {
    _weightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  double? get _weight =>
      double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: widget.name,
      email: widget.email,
      password: widget.password,
      weightKg: _weight,
      customDailyGoal: _manual ? int.parse(_goalController.text.trim()) : null,
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
    final weight = _weight;
    final estimate = AuthProvider.estimateGoal(weight);
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = _weight;
                  if (parsed == null || parsed < 20 || parsed > 300) {
                    return 'Informe um peso entre 20 e 300 kg';
                  }
                  return null;
                },
              ),
              if (_manual) ...[
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Sua meta diária',
                  hint: 'Ex.: 2500',
                  controller: _goalController,
                  suffixText: 'ml',
                  keyboardType: TextInputType.number,
                  helperText: 'A partir de 2.000 ml por dia.',
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final goal = int.tryParse((value ?? '').trim());
                    if (goal == null || goal < 2000) {
                      return 'A meta precisa ser de pelo menos 2.000 ml';
                    }
                    if (goal > 6000) return 'Use no máximo 6.000 ml';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
        if (!_manual)
          FlowCard(
            eyebrow: 'Ponto de partida do aplicativo',
            headline: '${formatMl(estimate)} ml',
            body: weight == null
                ? 'Preencha o peso para receber uma estimativa personalizada.'
                : 'Estimativa para ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} '
                      'kg: 35 ml por kg, a partir de 2.000 ml.',
          ),
        FlowCard(
          title: 'A meta é sua',
          body: _manual
              ? 'Você está definindo o volume manualmente.'
              : 'Você também pode definir o volume manualmente.',
        ),
        if (!_manual && estimate > WaterProvider.excessLimit)
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
        _manual ? 'Usar a estimativa pelo peso' : 'Definir meta manualmente',
        () => setState(() => _manual = !_manual),
      ),
    );
  }
}

// "Editar meta diária"
class EditGoalScreen extends StatefulWidget {
  final String backLabel;

  const EditGoalScreen({super.key, this.backLabel = 'Início'});

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  int get _currentGoal {
    final water = context.read<WaterProvider>();
    final user = context.read<AuthProvider>().user;
    return water.dailyGoal ?? user?.dailyGoal ?? 2000;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '$_currentGoal');
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
    final goal = int.parse(_controller.text.trim());

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
    if (mounted) replacePage(context, const GoalSavedScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

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
          child: AppTextField(
            label: 'Nova meta diária',
            hint: 'Ex.: 2500',
            controller: _controller,
            suffixText: 'ml',
            keyboardType: TextInputType.number,
            helperText: 'Você pode mudar este valor quando precisar.',
            validator: (value) {
              final goal = int.tryParse((value ?? '').trim());
              if (goal == null || goal < 1000) {
                return 'Use pelo menos 1.000 ml';
              }
              if (goal > 6000) return 'Use no máximo 6.000 ml';
              return null;
            },
            onSubmitted: (_) => _save(),
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
      primary: FlowAction('Salvar meta', _save, loading: isLoading),
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
