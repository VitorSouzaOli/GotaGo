import { addDays, startOfDay, toDateKey } from "./date-range.js";

export interface LogForStreak {
  amount: number;
  createdAt: Date;
  dailyGoal: number | null;
}

export interface DaySummary {
  total: number;
  goal: number;
  goalReached: boolean;
}

// Soma os registros por dia. A meta do dia é a gravada no registro mais recente daquele dia.
export function summarizeByDay(logs: LogForStreak[], fallbackGoal: number) {
  const days = new Map<string, DaySummary>();
  const ordered = [...logs].sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

  for (const log of ordered) {
    const key = toDateKey(log.createdAt);
    const total = (days.get(key)?.total ?? 0) + log.amount;
    const goal = log.dailyGoal ?? fallbackGoal;
    days.set(key, { total, goal, goalReached: total >= goal });
  }

  return days;
}

// Sequências de dias com meta batida, calculadas a partir dos registros.
// A sequência atual continua valendo enquanto hoje ainda está em andamento.
export function calculateStreaks(logs: LogForStreak[], fallbackGoal: number, now = new Date()) {
  const days = summarizeByDay(logs, fallbackGoal);
  const reached = (date: Date) => days.get(toDateKey(date))?.goalReached === true;

  const today = startOfDay(now);
  let day = reached(today) ? today : addDays(today, -1);
  let currentStreak = 0;
  while (reached(day)) {
    currentStreak++;
    day = addDays(day, -1);
  }

  // Maior sequência: percorre em ordem os dias com meta batida (as chaves AAAA-MM-DD ordenam)
  let maxStreak = 0;
  let run = 0;
  let previousKey = "";
  const reachedKeys = [...days]
    .filter(([, summary]) => summary.goalReached)
    .map(([key]) => key)
    .sort();

  for (const key of reachedKeys) {
    const [year, month, date] = key.split("-").map(Number);
    const dayBefore = toDateKey(new Date(year, month - 1, date - 1));
    run = previousKey === dayBefore ? run + 1 : 1;
    maxStreak = Math.max(maxStreak, run);
    previousKey = key;
  }

  return { currentStreak, maxStreak };
}
