import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/flow_page.dart';

// "Sem conexão por enquanto": aberta quando uma ação falha sem resposta do
// servidor. "Tentar novamente" fecha a tela e repete a ação.
class OfflineScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflineScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      title: 'Sem conexão por enquanto',
      subtitle: 'Não conseguimos atualizar as informações.',
      content: const [
        FlowCard(
          title: 'Confira sua internet',
          body: 'Tente conectar-se a uma rede e toque em Tentar novamente.',
        ),
        NoteCard(
          'Não envie o mesmo registro várias vezes. Aguarde a confirmação de '
          'salvamento.',
        ),
      ],
      primary: FlowAction('Tentar novamente', () {
        Navigator.pop(context);
        onRetry();
      }),
      secondary: FlowAction('Voltar', () => Navigator.pop(context)),
    );
  }
}

// Abre a tela "Sem conexão" por cima da atual
void showOffline(BuildContext context, VoidCallback onRetry) {
  pushPage(context, OfflineScreen(onRetry: onRetry));
}

// "Preparando seu dia": esqueleto enquanto a primeira carga não chega
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      embedded: true,
      showBack: false,
      title: 'Preparando seu dia',
      subtitle: 'Carregando suas informações…',
      content: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final widthFactor in [0.45, 0.85, 0.7, 0.5]) ...[
                _SkeletonBar(widthFactor: widthFactor),
                const SizedBox(height: 22),
              ],
            ],
          ),
        ),
        const NoteCard(
          'Estamos buscando seus registros e suas ligas. Aguarde um momento.',
        ),
      ],
    );
  }
}

// Barra cinza do esqueleto, pulsando suavemente
class _SkeletonBar extends StatefulWidget {
  final double widthFactor;

  const _SkeletonBar({required this.widthFactor});

  @override
  State<_SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<_SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_controller),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.widthFactor,
        child: Container(
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.lockedSurface,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
