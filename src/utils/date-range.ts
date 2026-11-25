// Início (00:00) do dia da data informada, no horário do servidor (variável TZ)
export function startOfDay(date: Date): Date {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  return start;
}

// Soma (ou subtrai) dias de calendário, respeitando horário de verão
export function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

// Filtro do Prisma para "tudo o que aconteceu no dia da data informada"
export function dayRange(date: Date) {
  const start = startOfDay(date);
  return { gte: start, lt: addDays(start, 1) };
}

// Data no formato "AAAA-MM-DD" (horário do servidor), usada para agrupar registros por dia
export function toDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
