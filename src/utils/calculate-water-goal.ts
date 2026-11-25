interface GoalCalculationResult {
  dailyGoal: number;
  warning?: string;
}

// Meta mínima do app, em qualquer caso
export const MIN_DAILY_GOAL = 2000;

const ML_PER_KG = 35;

// 35 ml por kg de peso, nunca abaixo de 2.000 ml
export function calculateWaterGoal(weightKg?: number): GoalCalculationResult {
  if (!weightKg || weightKg <= 0) {
    return { dailyGoal: MIN_DAILY_GOAL };
  }

  const calculated = Math.round(weightKg * ML_PER_KG);
  const finalGoal = Math.max(calculated, MIN_DAILY_GOAL);

  let warning: string | undefined;

  if (finalGoal > 4000) {
    warning =
      "Your calculated water goal exceeds 4000ml. Please consult with a healthcare professional.";
  }

  return {
    dailyGoal: finalGoal,
    warning,
  };
}
