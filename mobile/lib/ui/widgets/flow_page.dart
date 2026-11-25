import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../painters/drop_painter.dart';
import '../painters/trophy_painter.dart';

// Botão de rodapé de uma FlowPage
class FlowAction {
  final String label;
  // null = desativado
  final VoidCallback? onPressed;
  // Vermelho ("Excluir minha conta", "Sair da liga")
  final bool destructive;
  final bool loading;

  const FlowAction(
    this.label,
    this.onPressed, {
    this.destructive = false,
    this.loading = false,
  });
}

// Molde das telas de fluxo do GotaGo: "‹ Voltar", título, subtítulo,
// ilustração opcional, conteúdo rolável e até dois botões fixos no rodapé.
// Com `embedded`, não cria Scaffold (para usar dentro de uma aba).
class FlowPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String backLabel;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? illustration;
  final List<Widget> content;
  final FlowAction? primary;
  final FlowAction? secondary;
  final bool embedded;

  const FlowPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.backLabel = 'Voltar',
    this.onBack,
    this.showBack = true,
    this.illustration,
    this.content = const [],
    this.primary,
    this.secondary,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final illustration = this.illustration;
    final primary = this.primary;
    final secondary = this.secondary;

    final body = SafeArea(
      bottom: !embedded,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              children: [
                if (showBack)
                  BackLink(
                    label: backLabel,
                    onTap: onBack ?? () => Navigator.maybePop(context),
                  ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.8,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (illustration != null) ...[
                  Center(child: illustration),
                  const SizedBox(height: 20),
                ],
                for (int i = 0; i < content.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  content[i],
                ],
              ],
            ),
          ),
          if (primary != null || secondary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (primary != null) _FlowButton(action: primary),
                  if (primary != null && secondary != null)
                    const SizedBox(height: 12),
                  if (secondary != null)
                    _FlowButton(action: secondary, outlined: true),
                ],
              ),
            ),
        ],
      ),
    );

    if (embedded) return body;
    return AnnotatedRegion(
      value: AppColors.overlayStyle,
      child: Scaffold(body: body),
    );
  }
}

class _FlowButton extends StatelessWidget {
  final FlowAction action;
  final bool outlined;

  const _FlowButton({required this.action, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final onPressed = action.loading ? null : action.onPressed;
    final child = action.loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: outlined ? AppColors.tealDark : AppColors.white,
            ),
          )
        : Text(action.label);

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: action.destructive
              ? AppColors.danger
              : AppColors.primaryDark,
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: action.destructive
          ? FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            )
          : null,
      child: child,
    );
  }
}

// "‹ Voltar" em teal
class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const BackLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: AppColors.tealDark,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Card branco: rótulo em teal, título, número grande e texto.
// Com `onTap`, o texto ganha a seta "›" ("Alterar foto ›").
class FlowCard extends StatelessWidget {
  final String? eyebrow;
  final String? title;
  final String? headline;
  final String? body;
  final Widget? child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? titleColor;

  const FlowCard({
    super.key,
    this.eyebrow,
    this.title,
    this.headline,
    this.body,
    this.child,
    this.onTap,
    this.color,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final eyebrow = this.eyebrow;
    final title = this.title;
    final headline = this.headline;
    final body = this.body;
    final child = this.child;

    return Material(
      color: color ?? AppColors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (title != null) ...[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor ?? AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (headline != null) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    headline,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (body != null)
                Text.rich(
                  TextSpan(
                    text: body,
                    children: [
                      if (onTap != null)
                        TextSpan(
                          text: '  ›',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ?child,
            ],
          ),
        ),
      ),
    );
  }
}

// Aviso cinza-esverdeado ("Necessidades variam...")
class NoteCard extends StatelessWidget {
  final String text;

  const NoteCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.lockedSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// Aviso rosado de erro ("Não foi possível entrar")
class ErrorCard extends StatelessWidget {
  final String title;
  final String body;

  const ErrorCard({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Card de linhas "rótulo ............ valor em teal"
class InfoRowsCard extends StatelessWidget {
  final List<(String, String)> rows;
  // Opcional: ação ao tocar numa linha (ex.: abrir um registro)
  final void Function(int index)? onTapRow;

  const InfoRowsCard({super.key, required this.rows, this.onTapRow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            InkWell(
              onTap: onTapRow == null ? null : () => onTapRow!(i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rows[i].$2,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// "CÓDIGO DE CONVITE" + código grande centralizado
class CodeCard extends StatelessWidget {
  final String code;

  const CodeCard(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CÓDIGO DE CONVITE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Barra fina de progresso (0 a 1)
class FlowProgressBar extends StatelessWidget {
  final double value;

  const FlowProgressBar(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 10,
        color: AppColors.dropDark,
        backgroundColor: AppColors.ringTrack,
      ),
    );
  }
}

// Gota grande das telas de confirmação
class DropIllustration extends StatelessWidget {
  final double height;

  const DropIllustration({super.key, this.height = 156});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(height * 0.77, height),
      painter: const DropPainter(),
    );
  }
}

// Troféu-gota das conquistas; `faded` para conquista bloqueada
class TrophyIllustration extends StatelessWidget {
  final bool faded;

  const TrophyIllustration({super.key, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.4 : 1,
      child: const SizedBox(
        width: 210,
        height: 182,
        child: CustomPaint(painter: TrophyPainter()),
      ),
    );
  }
}

// Modal de confirmação no centro da tela (fundo escurecido), como nos mocks.
// Devolve true se a pessoa confirmou.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  String eyebrow = 'CONFIRMAÇÃO',
  bool destructive = true,
  // false: só fecha pelos botões (avisos que pedem uma resposta)
  bool dismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: destructive ? AppColors.danger : AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              body,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _FlowButton(
              action: FlowAction(
                confirmLabel,
                () => Navigator.pop(dialogContext, true),
                destructive: destructive,
              ),
            ),
            const SizedBox(height: 12),
            _FlowButton(
              action: FlowAction(
                cancelLabel,
                () => Navigator.pop(dialogContext, false),
              ),
              outlined: true,
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// Abre uma tela de fluxo por cima da atual
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

// Troca a tela atual por outra (o "voltar" pula a tela de origem)
Future<T?> replacePage<T>(BuildContext context, Widget page) {
  return Navigator.of(context)
      .pushReplacement<T, void>(MaterialPageRoute(builder: (_) => page));
}
