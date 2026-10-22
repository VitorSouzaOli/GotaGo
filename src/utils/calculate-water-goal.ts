interface GoalCalculationResult {
  dailyGoal: number;
  warning?: string;
}

export function calculateWaterGoal(weightKg?: number): GoalCalculationResult {
  if (!weightKg || weightKg <= 0) {
    return { dailyGoal: 2000 };
  }

  const calculated = Math.round(weightKg * 35);
  const finalGoal = Math.max(calculated, 2000);

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
