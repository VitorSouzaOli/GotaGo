// Formata mililitros com separador de milhar: 1250 → "1.250"
String formatMl(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

// Hora no formato "09:20"
String formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

// Saudação conforme o horário do aparelho
String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Bom dia';
  if (time.hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

// Iniciais para o avatar: "Vitor Souza" → "VS"
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

// Minutos desde 00:00 no formato "08:00" (480 → "08:00")
String formatClock(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

// Intervalo dos lembretes: 120 → "A cada 2 h", 90 → "A cada 1h30"
String formatInterval(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return 'A cada $hours h';
  if (hours == 0) return 'A cada $rest min';
  return 'A cada ${hours}h${rest.toString().padLeft(2, '0')}';
}
