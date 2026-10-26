import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../painters/trophy_painter.dart';
import '../../widgets/gotago_logo.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 28),
                const GotaGoLogo(fontSize: 52),
                const SizedBox(height: 12),

                // Troféu em formato de gota
                const Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.6,
                      child: AspectRatio(
                        aspectRatio: 220 / 190,
                        child: CustomPaint(painter: TrophyPainter()),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Um gole de cada vez.\nUm time com você.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Crie o hábito de beber água e desafie\nseus amigos. Cada um no seu ritmo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // Botão Criar Conta
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Criar minha conta'),
                      SizedBox(width: 10),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppColors.limeAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Botão Já tenho conta
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('Já tenho conta · Entrar'),
                ),
                const SizedBox(height: 20),

                // Aviso sobre constância
                Text.rich(
                  const TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.verified_user_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextSpan(
                        text:
                            'A disputa é pela constância, não pela quantidade.\nRespeite as necessidades do seu corpo.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
