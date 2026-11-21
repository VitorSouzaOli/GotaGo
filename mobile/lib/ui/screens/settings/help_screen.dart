import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/flow_page.dart';
import '../support/support_screens.dart';
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

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<SettingsProvider>().settings.supportTickets;
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
            style: TextStyle(fontSize: 15, color: AppColors.primaryDark),
            decoration: InputDecoration(
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
                    style: TextStyle(
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
                  onPressed: () => pushPage(context, const SupportFormScreen()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Falar com o suporte'),
                ),
              ),
              SettingsRow(
                title: 'Minhas solicitações',
                subtitle: tickets.isEmpty
                    ? 'Acompanhe suas conversas.'
                    : '${tickets.length} '
                          '${tickets.length == 1 ? 'solicitação' : 'solicitações'}',
                trailing: SettingsRow.chevron,
                onTap: () => pushPage(context, const SupportTicketsScreen()),
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
            child: Column(
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
                    style: TextStyle(
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
