import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/api_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';
import '../settings/widgets/settings_widgets.dart';

// O suporte ainda não tem backend: as conversas ficam guardadas no aparelho.
// Na demo, cada solicitação recebe uma resposta automática.
const _localNotice =
    'O envio ao suporte ainda não está conectado: suas mensagens ficam '
    'guardadas neste aparelho.';

String _status(SupportTicket ticket) =>
    ticket.closed ? 'Concluída' : 'Em análise';

// "Fale com o suporte"
class SupportFormScreen extends StatefulWidget {
  const SupportFormScreen({super.key});

  @override
  State<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends State<SupportFormScreen> {
  static const _subjects = [
    'Dúvida sobre meus registros',
    'Problema para entrar',
    'Ligas e convites',
    'Metas e lembretes',
    'Outro assunto',
  ];

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController(text: _subjects.first);
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickSubject() async {
    final picked = await showOptionsSheet<String>(
      context: context,
      title: 'Assunto',
      selected: _subjectController.text,
      options: [
        for (final subject in _subjects)
          (value: subject, label: subject, disabledHint: null),
      ],
    );
    if (picked != null) setState(() => _subjectController.text = picked);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    final ticket = await context.read<SettingsProvider>().openTicket(
      _subjectController.text,
      _messageController.text.trim(),
    );
    if (!mounted) return;
    replacePage(context, SupportThreadScreen(ticketNumber: ticket.number));
    showAppMessage(context, 'Solicitação ${ticket.label} aberta.');
  }

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Fale com o suporte',
      subtitle: 'Conte como podemos ajudar.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Assunto',
                hint: 'Escolha um assunto',
                controller: _subjectController,
                helperText: 'Selecione o tema da sua solicitação.',
                onTap: _pickSubject,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Mensagem',
                hint: 'Descreva sua dúvida ou problema',
                controller: _messageController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                helperText:
                    'Descreva o que aconteceu. Não inclua senhas ou dados '
                    'sensíveis.',
                validator: (value) =>
                    (value == null || value.trim().length < 10)
                    ? 'Escreva pelo menos 10 caracteres'
                    : null,
              ),
            ],
          ),
        ),
        FlowCard(
          title: 'Anexos',
          body: 'Adicionar imagem  +',
          onTap: () => showAppMessage(context, 'Anexos em breve.'),
        ),
        if (!ApiService.useMock) const NoteCard(_localNotice),
        const NoteCard(
          'Se estiver com mal-estar, procure atendimento de saúde. Este canal '
          'não atende emergências.',
        ),
      ],
      primary: FlowAction('Enviar solicitação', _send, loading: _sending),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Minhas solicitações" (vazia: "Tudo tranquilo por aqui")
class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tickets = [
      ...context.watch<SettingsProvider>().settings.supportTickets,
    ]..sort((a, b) => b.number.compareTo(a.number));

    if (tickets.isEmpty) {
      return FlowPage(
        title: 'Tudo tranquilo por aqui',
        subtitle: 'Suporte · Nenhuma solicitação',
        content: const [
          FlowCard(
            title: 'Nenhuma conversa por enquanto',
            body:
                'Se precisar de ajuda, abra uma solicitação. Suas respostas '
                'ficarão reunidas aqui.',
          ),
          NoteCard('Você também pode consultar as dúvidas frequentes.'),
        ],
        primary: FlowAction(
          'Falar com o suporte',
          () => replacePage(context, const SupportFormScreen()),
        ),
        secondary: FlowAction(
          'Ver dúvidas frequentes',
          () => Navigator.pop(context),
        ),
      );
    }

    final open = tickets.where((t) => !t.closed).length;
    final latest = tickets.first;

    return FlowPage(
      title: 'Minhas solicitações',
      subtitle: 'Acompanhe suas conversas com o GotaGo.',
      content: [
        InfoRowsCard(
          rows: [
            ('Em andamento', '$open'),
            ('Concluídas', '${tickets.length - open}'),
          ],
        ),
        for (final ticket in tickets)
          FlowCard(
            title: ticket.subject,
            body:
                '${_status(ticket)} · Solicitação ${ticket.label}\n'
                'Última mensagem: ${ticket.messages.last.text}',
            onTap: () => pushPage(
              context,
              SupportThreadScreen(ticketNumber: ticket.number),
            ),
          ),
        NoteCard(
          ApiService.useMock
              ? 'Você poderá ler e responder às mensagens por aqui.'
              : _localNotice,
        ),
      ],
      primary: FlowAction(
        'Abrir solicitação ${latest.label}',
        () =>
            pushPage(context, SupportThreadScreen(ticketNumber: latest.number)),
      ),
      secondary: FlowAction(
        'Nova solicitação',
        () => pushPage(context, const SupportFormScreen()),
      ),
    );
  }
}

// Conversa de uma solicitação
class SupportThreadScreen extends StatefulWidget {
  final int ticketNumber;

  const SupportThreadScreen({super.key, required this.ticketNumber});

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showAppMessage(context, 'Escreva uma mensagem antes de enviar.');
      return;
    }
    await context.read<SettingsProvider>().reply(widget.ticketNumber, text);
    _controller.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = context.watch<SettingsProvider>().ticket(
      widget.ticketNumber,
    );
    if (ticket == null) return const SizedBox.shrink();

    return FlowPage(
      title: ticket.subject,
      subtitle: 'Solicitação ${ticket.label} · ${_status(ticket)}',
      content: [
        for (final message in ticket.messages) _MessageBubble(message),
        AppTextField(
          label: 'Sua resposta',
          hint: 'Escreva uma mensagem',
          controller: _controller,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          helperText: 'Não compartilhe senhas ou códigos de acesso.',
        ),
      ],
      primary: FlowAction('Enviar mensagem', _send),
      secondary: FlowAction(
        'Voltar às solicitações',
        () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
        ),
      ),
    );
  }
}

// "Você" em verde-amarelado; "Equipe GotaGo" em branco
class _MessageBubble extends StatelessWidget {
  final SupportMessage message;

  const _MessageBubble(this.message);

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final textColor = mine ? AppColors.onLime : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: mine ? AppColors.limeAccent : AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine ? 'Você' : 'Equipe GotaGo',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: mine ? AppColors.onLime : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message.text,
            style: TextStyle(fontSize: 15, height: 1.45, color: textColor),
          ),
        ],
      ),
    );
  }
}
