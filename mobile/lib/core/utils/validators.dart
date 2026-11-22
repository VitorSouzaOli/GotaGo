// Regra de senha do app: 8+ caracteres, com letras e números
const passwordRule = 'Use pelo menos 8 caracteres, com letras e números.';

String? validateNewPassword(String? value) {
  final password = value ?? '';
  final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
  final hasNumber = password.contains(RegExp(r'[0-9]'));
  if (password.length < 8 || !hasLetter || !hasNumber) return passwordRule;
  return null;
}

// Confirmação: precisa ser igual à senha digitada no outro campo
String? Function(String?) validatePasswordConfirmation(
  String Function() password,
) {
  return (value) {
    if (value == null || value.isEmpty) return 'Repita a senha';
    if (value != password()) {
      return 'As senhas não coincidem. Digite novamente.';
    }
    return null;
  };
}

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Informe seu e-mail';
  if (!_emailRegex.hasMatch(value.trim())) return 'E-mail inválido';
  return null;
}

// Quantidade de água em ml (1 a 2.000 por registro)
String? validateWaterAmount(String? value) {
  final amount = int.tryParse((value ?? '').trim());
  if (amount == null || amount <= 0) return 'Informe uma quantidade válida';
  if (amount > 2000) return 'Registre no máximo 2.000 ml por vez';
  return null;
}
