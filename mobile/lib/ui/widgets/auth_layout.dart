import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../painters/drop_painter.dart';
import 'gotago_logo.dart';

// Estrutura comum de Login e Cadastro: barra do topo, título, subtítulo,
// conteúdo rolável e rodapé encostado no fim da tela.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        const _AuthTopBar(),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.8,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ...children,
                        const Spacer(),
                        const SizedBox(height: 24),
                        footer,
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Voltar à esquerda, logo no centro e selo verde-amarelado com a gota à direita
class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.outlineBorder, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: AppColors.primaryDark,
                semanticLabel: 'Voltar',
              ),
            ),
          ),
        ),
        const GotaGoLogo(fontSize: 28, showSubtitle: false),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.limeAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const CustomPaint(
            size: Size(16, 20),
            painter: DropPainter(),
          ),
        ),
      ],
    );
  }
}
