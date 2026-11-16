import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import 'widgets/settings_widgets.dart';

typedef _Faq = ({String question, String summary, String answer});

// Ajuda e suporte: dúvidas frequentes com busca e contato com o suporte.
// O suporte ainda não tem backend: as mensagens ficam guardadas no aparelho.
class HelpScreen extends StatefulWidget {
  final VoidCallback onBack;

  const HelpScreen({super.key, required this.onBack});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const List<_Faq> _faqs = [
    (
      question: 'Como ajustar minha meta?',
      summary: 'Defina quanto beber por dia.',
      answer:
          'No Perfil, toque em Ajustar na sua meta diária. Você também pode '
          'editar a meta pela tela Início.',
    ),
    (
      question: 'Como funciona a sequência?',
      summary: 'Dias seguidos em que você cumpre sua meta.',
      answer:
          'Cada dia em que você bate a meta soma 1 dia à sua sequência. Se um '
          'dia passar sem bater a meta, a contagem recomeça. O ranking das '
          'ligas usa essa sequência.',
    ),
    (
      question: 'Como entrar em uma liga?',
      summary: 'Use o código de convite dos seus amigos.',
      answer:
          'Na aba Ligas, toque em Entrar com código e digite o código que '
          'quem criou a liga compartilhou com você (ex.: GOTA-8X91).',
    ),
    (
      question: 'Registrei água por engano',
      summary: 'Saiba como revisar um registro.',
      answer:
          'Ainda não dá para apagar um registro pelo app. Fale com o suporte '
          'informando o horário e a quantidade.',
    ),
  ];

  final _searchController = TextEditingController();
  String _query = '';
  // Começa com a primeira dúvida aberta, como no mock
  int? _openIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<int> get _visibleFaqs {
    final query = _query.trim().toLowerCase();
    return [
      for (int i = 0; i < _faqs.length; i++)
        if (query.isEmpty ||
            _faqs[i].question.toLowerCase().contains(query) ||
            _faqs[i].answer.toLowerCase().contains(query))
          i,
    ];
  }

  Future<void> _contactSupport() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SupportMessageSheet(),
    );
    if (message == null || !mounted) return;

    await context.read<SettingsProvider>().addSupportRequest(message);
    if (!mounted) return;
    showSettingsMessage(context, 'Mensagem guardada em Minhas solicitações.');
  }

  void _showRequests(List<SupportRequest> requests) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RequestsSheet(requests: requests),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<SettingsProvider>().settings.supportRequests;
    final visible = _visibleFaqs;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubpageHeader(
            title: 'Ajuda e suporte',
            subtitle: 'Uma mãozinha para seguir no seu ritmo.',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {
              _query = value;
              _openIndex = null;
            }),
            style: const TextStyle(fontSize: 15, color: AppColors.primaryDark),
            decoration: const InputDecoration(
              hintText: 'Buscar por assunto',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Dúvidas frequentes',
            children: [
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Nenhuma dúvida encontrada para "${_query.trim()}".',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final i in visible)
                _FaqItem(
                  faq: _faqs[i],
                  open: _openIndex == i,
                  onTap: () =>
                      setState(() => _openIndex = _openIndex == i ? null : i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            title: 'Ainda precisa de ajuda?',
            description:
                'Envie sua dúvida ou relate um problema. Inclua o que '
                'aconteceu para facilitar o atendimento.',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: FilledButton(
                  onPressed: _contactSupport,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Falar com o suporte'),
                ),
              ),
              SettingsRow(
                title: 'Minhas solicitações',
                subtitle: requests.isEmpty
                    ? 'Acompanhe suas conversas.'
                    : '${requests.length} '
                          '${requests.length == 1 ? 'mensagem' : 'mensagens'}',
                trailing: SettingsRow.chevron,
                onTap: () => _showRequests(requests),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lockedSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sua saúde vem primeiro',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'O suporte do GotaGo não substitui orientação médica. Em '
                  'caso de mal-estar, procure atendimento de saúde.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Dúvida que abre/fecha: aberta mostra a resposta e "–"; fechada, o resumo e "›"
class _FaqItem extends StatelessWidget {
  final _Faq faq;
  final bool open;
  final VoidCallback onTap;

  const _FaqItem({required this.faq, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    faq.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.remove_rounded : Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.tealDark,
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                open ? faq.answer : faq.summary,
                style: TextStyle(
                  fontSize: open ? 13 : 11,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportMessageSheet extends StatefulWidget {
  const _SupportMessageSheet();

  @override
  State<_SupportMessageSheet> createState() => _SupportMessageSheetState();
}

class _SupportMessageSheetState extends State<_SupportMessageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Falar com o suporte',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Conte o que aconteceu. O envio ao suporte ainda não está '
              'conectado: sua mensagem fica guardada neste aparelho.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 6,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.primaryDark,
              ),
              decoration: const InputDecoration(
                hintText: 'Descreva sua dúvida ou problema',
              ),
              validator: (value) => (value == null || value.trim().length < 10)
                  ? 'Escreva pelo menos 10 caracteres'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Guardar mensagem'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsSheet extends StatelessWidget {
  final List<SupportRequest> requests;

  const _RequestsSheet({required this.requests});

  @override
  Widget build(BuildContext context) {
    final sorted = [...requests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Minhas solicitações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Você ainda não abriu nenhuma solicitação.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.ringTrack),
                  itemBuilder: (context, index) {
                    final request = sorted[index];
                    final date = request.createdAt;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day.toString().padLeft(2, '0')}/'
                            '${date.month.toString().padLeft(2, '0')} · '
                            '${formatTime(date)} · Guardada no aparelho',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tealDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.message,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
