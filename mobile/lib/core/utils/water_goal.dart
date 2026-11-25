import 'dart:math';

// Mesmo cálculo do backend (src/utils/calculate-water-goal.ts):
// 35 ml por kg de peso, nunca abaixo de 2.000 ml
const minDailyGoal = 2000;
const maxDailyGoal = 10000;

const _mlPerKg = 35;

int estimateDailyGoal(double? weightKg) {
  if (weightKg == null || weightKg <= 0) return minDailyGoal;
  return max((weightKg * _mlPerKg).round(), minDailyGoal);
}

// Validação de meta digitada pela pessoa (mínimo de 2.000 ml)
String? validateDailyGoal(String? value) {
  final goal = int.tryParse((value ?? '').trim());
  if (goal == null || goal < minDailyGoal) {
    return 'A meta precisa ser de pelo menos 2.000 ml';
  }
  if (goal > maxDailyGoal) return 'Use no máximo 10.000 ml';
  return null;
}

double? parseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

String? validateWeight(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final weight = parseDecimal(value);
  if (weight == null || weight < 20 || weight > 300) {
    return 'Informe um peso entre 20 e 300 kg';
  }
  return null;
}

// "70" ou "70,5"
String formatDecimal(double value) =>
    value.toStringAsFixed(value % 1 == 0 ? 0 : 1).replaceAll('.', ',');
