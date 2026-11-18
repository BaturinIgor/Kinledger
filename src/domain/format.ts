/** 0 → "0 h", 25 → "25 min", 130 → "2 h 10 min", 1890 → "31.5 h" (summaries round to half hours). */
export function formatDuration(minutes: number, style: 'exact' | 'summary' = 'exact'): string {
  if (style === 'summary') {
    const halfHours = Math.round(minutes / 30) / 2;
    return `${Number.isInteger(halfHours) ? halfHours : halfHours.toFixed(1)} h`;
  }
  if (minutes < 60) return `${minutes} min`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

export function formatMoney(cents: number, currency = 'USD', locale = 'en-US'): string {
  const whole = cents % 100 === 0;
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: whole ? 0 : 2,
    maximumFractionDigits: whole ? 0 : 2,
  }).format(cents / 100);
}
