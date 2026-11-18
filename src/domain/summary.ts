import type { Entry } from './types';

export type Totals = {
  minutes: number;
  /** Money the caregiver paid and nobody has repaid. */
  outOfPocketCents: number;
  visits: number;
};

export function totals(entries: readonly Entry[]): Totals {
  return entries.reduce<Totals>(
    (acc, e) => ({
      minutes: acc.minutes + e.minutes,
      outOfPocketCents:
        acc.outOfPocketCents + (e.expense?.payer === 'me' ? e.expense.amountCents : 0),
      visits: acc.visits + (e.visit ? 1 : 0),
    }),
    { minutes: 0, outOfPocketCents: 0, visits: 0 },
  );
}

/** Entries whose care happened in the given calendar month (local time). month is 0-based. */
export function inMonth(entries: readonly Entry[], year: number, month: number): Entry[] {
  return entries.filter((e) => {
    const d = new Date(e.occurredAt);
    return d.getFullYear() === year && d.getMonth() === month;
  });
}

/** Newest first. */
export function recent(entries: readonly Entry[], limit: number): Entry[] {
  return [...entries]
    .sort((a, b) => Date.parse(b.occurredAt) - Date.parse(a.occurredAt))
    .slice(0, limit);
}
