import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../painters/drop_painter.dart';
import '../../painters/ripple_painter.dart';
import '../../widgets/gotago_logo.dart';
import '../home/home_shell.dart';
import '../welcome/welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _dropSize = Size(104, 132);
  static const _rippleSize = Size(200, 30);
  // Distância que a gota cai até a posição final
  static const _fallDistance = 110.0;

  late final AnimationController _controller;
  late final Animation<double> _dropOpacityAnimation;
  late final Animation<double> _dropFallAnimation;
  late final Animation<double> _dropColorAnimation;
  late final Animation<double> _dropSquashAnimation;
  late final Animation<double> _rippleAnimation;
  late final Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // 1. Gota surge no alto, ainda clara (5% a 25%)
    _dropOpacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.25, curve: Curves.easeOut),
    );

    // 2. Gota cai até o centro, acelerando como gravidade (20% a 50%)
    _dropFallAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.50, curve: Curves.easeInCubic),
    );

    // 3. Cor da gota escurece até o teal final (20% a 55%)
    _dropColorAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.55, curve: Curves.easeInOut),
    );

    // 3b. Gota comprime ao tocar o "solo", estica um pouco e assenta (50% a 70%)
    // 1 = achatada, 0 = formato normal, negativo = esticada
    _dropSquashAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: -0.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.3, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.70),
      ),
    );

    // 4. Ondas nascem no impacto, se abrem e suavizam (48% a 100%)
    _rippleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 1.0),
    );

    // 5. Logo surge subindo levemente (60% a 85%)
    _logoAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
    );

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Executa a animação e verifica o estado do utilizador simultaneamente
    await Future.wait([_controller.forward(), authProvider.checkAuthStatus()]);

    // Mantém a tela final visível por um instante
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final fall = _dropFallAnimation.value;
              final squash = _dropSquashAnimation.value;
              final logo = _logoAnimation.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _rippleSize.width,
                    height: _dropSize.height + 27,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Ondas logo abaixo da gota
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: _rippleSize.height,
                          child: CustomPaint(
                            painter: RipplePainter(
                              progress: _rippleAnimation.value,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, -(1 - fall) * _fallDistance),
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * fall,
                            // Compressão presa pela base, como se apoiasse no chão
                            child: Transform(
                              alignment: Alignment.bottomCenter,
                              transform: Matrix4.diagonal3Values(
                                1 + 0.14 * squash,
                                1 - 0.14 * squash,
                                1,
                              ),
                              child: Opacity(
                                opacity: _dropOpacityAnimation.value,
                                child: CustomPaint(
                                  size: _dropSize,
                                  painter: DropPainter(
                                    colorProgress: _dropColorAnimation.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Opacity(
                    opacity: logo,
                    child: Transform.translate(
                      offset: Offset(0, (1 - logo) * 12),
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: const GotaGoLogo(),
          ),
        ),
      ),
    );
  }
}
