import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/water_goal.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/water_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../common/status_screens.dart';
import '../goal/goal_screens.dart';

// "Editar perfil": nome e peso. O peso não muda a meta sozinho: se a meta
// calculada mudar, o app pergunta antes de aplicar.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().user!;
  late final _nameController = TextEditingController(text: _user.name);
  late final _weightController = TextEditingController(
    text: _user.weight == null ? '' : formatDecimal(_user.weight!),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? get _weight => parseDecimal(_weightController.text);

  // Peso novo gera outra meta calculada: pergunta se quer usá-la
  Future<void> _offerCalculatedGoal() async {
    final weight = _weight;
    if (weight == null) return;

    final auth = context.read<AuthProvider>();
    final water = context.read<WaterProvider>();
    final current = water.dailyGoal ?? auth.user!.dailyGoal;
    final estimate = estimateDailyGoal(weight);
    if (estimate == current) return;

    final useIt = await showConfirmDialog(
      context,
      eyebrow: 'SUA META',
      title: 'Usar a meta calculada?',
      body:
          'Com o peso novo, a meta calculada é de ${formatMl(estimate)} ml. '
          'Sua meta atual é de ${formatMl(current)} ml.',
      confirmLabel: 'Usar ${formatMl(estimate)} ml',
      cancelLabel: 'Manter minha meta',
      destructive: false,
    );
    if (!useIt || !mounted) return;

    if (await auth.updateProfile(dailyGoal: estimate)) {
      await water.setDailyGoal(auth.user!.id, estimate);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final weightChanged = _weight != _user.weight;
    final ok = await auth.updateProfile(
      name: _nameController.text.trim(),
      weight: _weight,
    );
    if (!mounted) return;

    if (ok) {
      if (weightChanged) await _offerCalculatedGoal();
      if (!mounted) return;
      Navigator.pop(context);
      showAppMessage(context, 'Perfil atualizado.');
    } else if (auth.failure == AuthFailure.offline) {
      showOffline(context, _save);
    } else {
      showAppMessage(context, auth.errorMessage ?? 'Não foi possível salvar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final goal =
        context.watch<WaterProvider>().dailyGoal ??
        auth.user?.dailyGoal ??
        2000;

    return FlowPage(
      title: 'Editar perfil',
      subtitle: 'Seu espaço, do seu jeito.',
      content: [
        FlowCard(
          title: 'Foto do perfil',
          body: 'Alterar foto',
          onTap: () => showAppMessage(context, 'Fotos de perfil em breve.'),
        ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nome',
                hint: 'Como você quer ser chamado?',
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                helperText: 'Como você aparece nas ligas.',
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Informe como você quer ser chamado'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Peso',
                hint: 'Informe seu peso em kg',
                controller: _weightController,
                suffixText: 'kg',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                helperText:
                    'Opcional. Use para revisar a estimativa da sua meta.',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final weight = _weight;
                  if (weight == null || weight < 20 || weight > 300) {
                    return 'Informe um peso entre 20 e 300 kg';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        FlowCard(
          title: 'Meta diária atual',
          body: '${formatMl(goal)} ml · Ajustar meta',
          onTap: () =>
              pushPage(context, const EditGoalScreen(backLabel: 'Voltar')),
        ),
        const NoteCard(
          'Alterar o peso não muda sua meta sem a sua confirmação.',
        ),
      ],
      primary: FlowAction('Salvar perfil', _save, loading: auth.isLoading),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}
