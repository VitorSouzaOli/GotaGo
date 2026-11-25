import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../models/league_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/league_provider.dart';
import '../../../providers/water_provider.dart';
import '../../../services/api_service.dart';
import '../../navigation/shell_controller.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/flow_page.dart';

// Mensagem de convite copiada ao "Compartilhar convite"
Future<void> copyInvite(BuildContext context, LeagueModel league) async {
  await Clipboard.setData(
    ClipboardData(
      text:
          'Entre na minha liga "${league.name}" no GotaGo! Abra Ligas, toque '
          'em Entrar com código e use o código ${league.code}.',
    ),
  );
  if (context.mounted) {
    showAppMessage(context, 'Convite copiado. É só colar na conversa.');
  }
}

Future<void> copyCode(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) showAppMessage(context, 'Código $code copiado.');
}

// Volta para a aba Ligas com a liga escolhida em destaque
void showLeagueInTab(BuildContext context, String leagueId) {
  context.read<LeagueProvider>().select(leagueId);
  backToShell(context, ShellTab.leagues);
}

String _people(int count) =>
    '$count ${count == 1 ? 'participante' : 'participantes'}';

String _days(int count) => '$count ${count == 1 ? 'dia' : 'dias'}';

// "Crie sua liga"
class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final leagues = context.read<LeagueProvider>();
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final ok = await leagues.create(
      userId: user.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
    );
    if (!mounted) return;

    if (ok) {
      replacePage(context, LeagueCreatedScreen(leagueId: leagues.selected!.id));
    } else {
      showAppMessage(
        context,
        leagues.errorMessage ?? 'Não foi possível criar a liga.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<LeagueProvider>().isSubmitting;

    return FlowPage(
      backLabel: 'Ligas',
      title: 'Crie sua liga',
      subtitle: 'Um time para transformar goles em hábito.',
      content: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nome da liga',
                hint: 'Ex.: Gole a gole',
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                helperText: 'Escolha um nome que os amigos reconheçam.',
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Use pelo menos 3 caracteres'
                    : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Descrição',
                hint: 'Uma rotina saudável, juntos.',
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                helperText: 'Opcional',
                onSubmitted: (_) => _create(),
              ),
            ],
          ),
        ),
        const FlowCard(
          title: 'A disputa é por constância',
          body:
              'A classificação usa os dias seguidos de meta cumprida. Beber '
              'além da meta não dá pontos extras.',
        ),
        const NoteCard(
          'Depois de criar, compartilhe o código para convidar seus amigos.',
        ),
      ],
      primary: FlowAction('Criar liga', _create, loading: busy),
      secondary: FlowAction('Cancelar', () => Navigator.pop(context)),
    );
  }
}

// "Sua liga está pronta!"
class LeagueCreatedScreen extends StatelessWidget {
  final String leagueId;

  const LeagueCreatedScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>().byId(leagueId);
    if (league == null) return const SizedBox.shrink();

    return FlowPage(
      backLabel: 'Ligas',
      title: 'Sua liga está pronta!',
      subtitle: 'Convide o primeiro amigo para começar.',
      content: [
        FlowCard(
          title: league.name,
          body: '${_people(league.memberCount)} · Você é o administrador',
        ),
        CodeCard(league.code),
        const NoteCard(
          'Compartilhe o convite apenas com quem você quer na equipe.',
        ),
        const FlowCard(
          title: 'Uma nova equipe na sua jornada',
          body: 'Seus registros de água também contarão nesta liga.',
        ),
      ],
      primary: FlowAction(
        'Compartilhar convite',
        () => copyInvite(context, league),
      ),
      secondary: FlowAction(
        'Ver minha liga',
        () => showLeagueInTab(context, leagueId),
      ),
    );
  }
}

// "Entre em uma liga" (e, com código errado, "Vamos conferir esse código")
class JoinLeagueScreen extends StatefulWidget {
  const JoinLeagueScreen({super.key});

  @override
  State<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends State<JoinLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _notFound = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final leagues = context.read<LeagueProvider>();
    final code = _controller.text.trim().toUpperCase();
    final preview = await leagues.findByCode(code);
    if (!mounted) return;

    if (preview == null) {
      if (leagues.errorMessage == 'Código inválido ou não disponível.') {
        setState(() => _notFound = true);
      } else {
        showAppMessage(
          context,
          leagues.errorMessage ?? 'Não foi possível buscar.',
        );
      }
      return;
    }

    // Sem a rota de consulta no backend, entra direto sem a prévia
    if (preview.name.isEmpty) {
      await joinLeague(context, code, replace: false);
      return;
    }
    pushPage(context, LeaguePreviewScreen(preview: preview));
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<LeagueProvider>().isSubmitting;

    return FlowPage(
      backLabel: _notFound ? 'Voltar' : 'Ligas',
      title: _notFound ? 'Vamos conferir esse código' : 'Entre em uma liga',
      subtitle: _notFound
          ? 'Não encontramos uma liga com esse convite.'
          : 'Recebeu um convite? Seu lugar está aqui.',
      content: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Código de convite',
            hint: ApiService.useMock ? 'Ex.: RITMO6' : 'Ex.: GOTA-AB12',
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            helperText: 'Digite o código compartilhado por um amigo.',
            errorText: _notFound ? 'Código inválido ou não disponível.' : null,
            onChanged: (_) {
              if (_notFound) setState(() => _notFound = false);
            },
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Informe o código'
                : null,
            onSubmitted: (_) => _search(),
          ),
        ),
        if (_notFound)
          const FlowCard(
            title: 'Peça um novo convite',
            body:
                'Confira letras e números ou solicite o código atualizado ao '
                'administrador da liga.',
          )
        else ...const [
          FlowCard(
            title: 'Uma rotina. Várias equipes.',
            body:
                'Cada copo registrado atualiza seu progresso em todas as ligas '
                'em que você participa.',
          ),
          NoteCard(
            'Na próxima etapa, confira o nome da equipe antes de entrar.',
          ),
        ],
      ],
      primary: FlowAction(
        _notFound ? 'Tentar novamente' : 'Buscar liga',
        _search,
        loading: busy,
      ),
      secondary: FlowAction(
        _notFound ? 'Voltar às ligas' : 'Cancelar',
        () => Navigator.pop(context),
      ),
    );
  }
}

// Entra na liga e abre "Você está na liga!"
Future<void> joinLeague(
  BuildContext context,
  String code, {
  bool replace = true,
}) async {
  final leagues = context.read<LeagueProvider>();
  final user = context.read<AuthProvider>().user;
  if (user == null) return;

  final ok = await leagues.join(userId: user.id, code: code);
  if (!context.mounted) return;

  if (!ok) {
    showAppMessage(context, leagues.errorMessage ?? 'Não foi possível entrar.');
    return;
  }
  final page = LeagueJoinedScreen(leagueId: leagues.selected!.id);
  replace ? replacePage(context, page) : pushPage(context, page);
}

// "Esta é a sua equipe?"
class LeaguePreviewScreen extends StatelessWidget {
  final LeaguePreview preview;

  const LeaguePreviewScreen({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final streak = context.watch<AuthProvider>().user?.currentStreak ?? 0;
    final busy = context.watch<LeagueProvider>().isSubmitting;
    final owner = preview.ownerName;

    return FlowPage(
      backLabel: 'Ligas',
      title: 'Esta é a sua equipe?',
      subtitle: 'Confira o convite antes de entrar.',
      content: [
        FlowCard(
          title: preview.name,
          body:
              '${_people(preview.memberCount)}'
              '${owner != null ? ' · Criada por ${owner.split(' ').first}' : ''}',
        ),
        CodeCard(preview.code),
        InfoRowsCard(
          rows: [
            ('Critério de ranking', 'Dias seguidos'),
            ('Sua sequência atual', _days(streak)),
          ],
        ),
        const NoteCard(
          'Sua sequência será considerada na liga. Não é preciso começar a '
          'registrar de novo.',
        ),
      ],
      primary: FlowAction(
        'Entrar na liga',
        () => joinLeague(context, preview.code),
        loading: busy,
      ),
      secondary: FlowAction('Usar outro código', () => Navigator.pop(context)),
    );
  }
}

// "Você está na liga!"
class LeagueJoinedScreen extends StatelessWidget {
  final String leagueId;

  const LeagueJoinedScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>().byId(leagueId);
    final user = context.watch<AuthProvider>().user;
    final water = context.watch<WaterProvider>();
    if (league == null || user == null) return const SizedBox.shrink();
    final goal = water.dailyGoal ?? user.dailyGoal;

    return FlowPage(
      backLabel: 'Ligas',
      onBack: () => showLeagueInTab(context, leagueId),
      title: 'Você está na liga!',
      subtitle: 'Agora fica mais leve manter a rotina.',
      content: [
        FlowCard(
          title: league.name,
          body: '${_people(league.memberCount)}, contando com você.',
        ),
        InfoRowsCard(
          rows: [
            ('Sua sequência', _days(user.currentStreak)),
            (
              'Progresso de hoje',
              '${formatMl(water.totalToday)} / ${formatMl(goal)} ml',
            ),
          ],
        ),
        const NoteCard(
          'Seus registros contam aqui e nas demais ligas. Continue no seu '
          'ritmo.',
        ),
      ],
      primary: FlowAction(
        'Ver classificação',
        () => replacePage(context, LeagueRankingScreen(leagueId: leagueId)),
      ),
      secondary: FlowAction(
        'Voltar às ligas',
        () => showLeagueInTab(context, leagueId),
      ),
    );
  }
}

// "Convide seus amigos"
class InviteScreen extends StatelessWidget {
  final String leagueId;

  const InviteScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>().byId(leagueId);
    if (league == null) return const SizedBox.shrink();

    return FlowPage(
      backLabel: 'Ligas',
      title: 'Convide seus amigos',
      subtitle: '${league.name} · ${_people(league.memberCount)}',
      content: [
        CodeCard(league.code),
        const FlowCard(
          title: 'Como participar',
          body:
              'No GotaGo, abra Ligas, toque em Entrar com código e informe o '
              'convite acima.',
        ),
        const NoteCard(
          'Competição saudável: quem mantém a constância sobe no ranking, não '
          'quem bebe mais água.',
        ),
      ],
      primary: FlowAction(
        'Compartilhar convite',
        () => copyInvite(context, league),
      ),
      secondary: FlowAction(
        'Copiar código',
        () => copyCode(context, league.code),
      ),
    );
  }
}

// Confirmação para sair de uma liga
Future<void> leaveLeague(BuildContext context, LeagueModel league) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Sair da liga ${league.name}?',
    body:
        'Você deixará de aparecer na classificação desta liga. Seu histórico '
        'pessoal e suas outras ligas não serão apagados.',
    confirmLabel: 'Sair da liga',
    cancelLabel: 'Continuar na liga',
  );
  if (!confirmed || !context.mounted) return;

  final leagues = context.read<LeagueProvider>();
  final user = context.read<AuthProvider>().user;
  if (user == null) return;

  final ok = await leagues.leave(userId: user.id, leagueId: league.id);
  if (!context.mounted) return;
  if (ok) {
    backToShell(context, ShellTab.leagues);
    showAppMessage(context, 'Você saiu da liga ${league.name}.');
  } else {
    showAppMessage(context, leagues.errorMessage ?? 'Não foi possível sair.');
  }
}

// Classificação completa da liga
class LeagueRankingScreen extends StatelessWidget {
  final String leagueId;

  const LeagueRankingScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final league = context.watch<LeagueProvider>().byId(leagueId);
    final user = context.watch<AuthProvider>().user;
    if (league == null || user == null) return const SizedBox.shrink();
    final isOwner = league.isOwner(user.id);

    String label(LeagueMember member, int position) {
      final firstName = member.name.trim().split(RegExp(r'\s+')).first;
      final tags = [
        if (member.id == user.id) 'Você',
        if (league.isOwner(member.id)) 'Administrador',
      ];
      return '$positionº  $firstName${tags.isEmpty ? '' : ' · ${tags.join(' · ')}'}';
    }

    return FlowPage(
      backLabel: 'Ligas',
      title: league.name,
      subtitle: '${_people(league.memberCount)} · Ranking por constância',
      content: [
        InfoRowsCard(
          rows: [
            for (int i = 0; i < league.ranking.length; i++)
              (
                label(league.ranking[i], i + 1),
                _days(league.ranking[i].currentStreak),
              ),
          ],
        ),
        const NoteCard(
          'Os dias de meta cumprida definem a ordem. Hoje ainda está em '
          'andamento.',
        ),
      ],
      primary: FlowAction(
        'Convidar amigos',
        () => pushPage(context, InviteScreen(leagueId: leagueId)),
      ),
      // Quem criou a liga administra; os demais podem sair
      secondary: isOwner
          ? FlowAction(
              'Administrar liga',
              () => pushPage(context, LeagueAdminScreen(leagueId: leagueId)),
            )
          : FlowAction('Sair da liga', () => leaveLeague(context, league)),
    );
  }
}

// "Administrar liga": renomear, remover membros e trocar o código
class LeagueAdminScreen extends StatefulWidget {
  final String leagueId;

  const LeagueAdminScreen({super.key, required this.leagueId});

  @override
  State<LeagueAdminScreen> createState() => _LeagueAdminScreenState();
}

class _LeagueAdminScreenState extends State<LeagueAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: context.read<LeagueProvider>().byId(widget.leagueId)?.name ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _userId => context.read<AuthProvider>().user!.id;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final leagues = context.read<LeagueProvider>();
    final ok = await leagues.rename(
      userId: _userId,
      leagueId: widget.leagueId,
      name: _nameController.text.trim(),
    );
    if (!mounted) return;
    showAppMessage(
      context,
      ok
          ? 'Alterações salvas.'
          : leagues.errorMessage ?? 'Não foi possível salvar.',
    );
  }

  Future<void> _remove(LeagueMember member) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover ${member.name.split(' ').first}?',
      body:
          'A pessoa deixa de aparecer na classificação. Ela pode voltar se '
          'receber o código de convite de novo.',
      confirmLabel: 'Remover da liga',
      cancelLabel: 'Cancelar',
    );
    if (!confirmed || !mounted) return;

    final leagues = context.read<LeagueProvider>();
    final ok = await leagues.removeMember(
      userId: _userId,
      leagueId: widget.leagueId,
      memberId: member.id,
    );
    if (!mounted) return;
    if (!ok) {
      showAppMessage(
        context,
        leagues.errorMessage ?? 'Não foi possível remover.',
      );
    }
  }

  Future<void> _newCode() async {
    final leagues = context.read<LeagueProvider>();
    final ok = await leagues.regenerateCode(
      userId: _userId,
      leagueId: widget.leagueId,
    );
    if (!mounted) return;
    showAppMessage(
      context,
      ok
          ? 'Novo código gerado. O anterior deixou de funcionar.'
          : leagues.errorMessage ?? 'Não foi possível gerar o código.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagues = context.watch<LeagueProvider>();
    final league = leagues.byId(widget.leagueId);
    final user = context.watch<AuthProvider>().user;
    if (league == null || user == null) return const SizedBox.shrink();

    final members = league.ranking;

    return FlowPage(
      backLabel: 'Ligas',
      title: 'Administrar liga',
      subtitle: '${league.name} · Visão do administrador',
      content: [
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Nome da liga',
            hint: 'Ex.: Gole a gole',
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            helperText: 'Alterações serão vistas por todos os participantes.',
            validator: (value) => (value == null || value.trim().length < 3)
                ? 'Use pelo menos 3 caracteres'
                : null,
          ),
        ),
        InfoRowsCard(
          rows: [
            for (final member in members)
              member.id == user.id
                  ? ('${member.name.split(' ').first} · Você', 'Administrador')
                  : (member.name.split(' ').first, 'Remover'),
          ],
          onTapRow: (index) {
            final member = members[index];
            if (member.id != user.id) _remove(member);
          },
        ),
        CodeCard(league.code),
        const FlowCard(
          title: 'Proteja seu convite',
          body:
              'Você pode gerar um novo código caso o atual seja compartilhado '
              'fora da equipe.',
        ),
      ],
      primary: FlowAction(
        'Salvar alterações',
        _save,
        loading: leagues.isSubmitting,
      ),
      secondary: FlowAction('Gerar novo código', _newCode),
    );
  }
}
