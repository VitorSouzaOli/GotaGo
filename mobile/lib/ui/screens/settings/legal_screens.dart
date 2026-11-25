import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/flow_page.dart';

// Texto legal em seções numeradas, com aviso de texto-modelo no topo
class _LegalPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String notice;
  final List<(String, String)> sections;
  final String buttonLabel;

  const _LegalPage({
    required this.title,
    required this.subtitle,
    required this.notice,
    required this.sections,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FlowPage(
      backLabel: 'Privacidade e segurança',
      title: title,
      subtitle: subtitle,
      content: [
        NoteCard(notice),
        for (final (heading, text) in sections)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
      primary: FlowAction(buttonLabel, () => Navigator.pop(context)),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Política de privacidade',
      subtitle: 'Transparência sobre o uso das suas informações.',
      notice:
          'Texto-modelo do projeto. Precisa de revisão jurídica e validação '
          'das práticas reais antes da publicação.',
      buttonLabel: 'Voltar à privacidade',
      sections: [
        (
          '1. Informações da conta',
          'O serviço prevê o uso de nome, dados de acesso, peso informado, '
              'metas e registros de hidratação. Os campos opcionais devem ser '
              'identificados no momento do preenchimento.',
        ),
        (
          '2. Finalidade e visibilidade',
          'Essas informações apoiam o acompanhamento da rotina, a estimativa '
              'de metas e a participação em ligas. Nome e constância aparecem '
              'para os participantes das ligas; detalhes de consumo devem '
              'respeitar as escolhas de privacidade.',
        ),
        (
          '3. Seus direitos',
          'Na área de Privacidade e segurança, você encontra opções para '
              'consultar informações, solicitar uma cópia e pedir exclusão da '
              'conta. Solicitações também podem ser encaminhadas ao suporte.',
        ),
        (
          '4. Retenção e contato',
          'Prazos de retenção, bases legais, fornecedores, canal do '
              'responsável e detalhes de segurança deverão refletir o serviço '
              'implementado. Acesse Ajuda e suporte para esclarecer dúvidas.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      title: 'Termos de uso',
      subtitle: 'Uma experiência saudável, justa e respeitosa.',
      notice:
          'Texto-modelo do projeto. Precisa de revisão jurídica antes da '
          'publicação.',
      buttonLabel: 'Voltar à segurança',
      sections: [
        (
          '1. Uso do GotaGo',
          'O aplicativo apoia o registro de hidratação e a criação de hábitos. '
              'Você é responsável por manter os dados da sua conta corretos e '
              'registrar o consumo com honestidade.',
        ),
        (
          '2. Saúde em primeiro lugar',
          'Metas e alertas são orientações do aplicativo, não diagnóstico ou '
              'prescrição. Necessidades variam; siga orientação profissional. '
              'Não consuma água em excesso para cumprir metas ou competir.',
        ),
        (
          '3. Convivência nas ligas',
          'Respeite outros participantes e não use nomes, imagens ou mensagens '
              'ofensivas. A classificação considera dias de constância, não '
              'volume extra de água.',
        ),
        (
          '4. Conta e suporte',
          'Proteja suas credenciais. Para dúvidas, problemas de acesso ou '
              'pedidos sobre a conta, use Ajuda e suporte. As regras finais de '
              'disponibilidade, suspensão, responsabilidade e alterações dos '
              'termos exigem validação jurídica.',
        ),
      ],
    );
  }
}
