/** Who paid for an expense. Drives the "out of pocket" total in the report (R4). */
export type Payer = 'me' | 'parent' | 'repaid';

export type Category =
  | 'doctor'
  | 'pharmacy'
  | 'groceries'
  | 'overnight'
  | 'bills'
  | 'home-help'
  | 'transport'
  | 'other';

export type Expense = {
  /** Integer cents, never floats. */
  amountCents: number;
  payer: Payer;
  /** Counts toward the US medical-expense export (R14). */
  medical: boolean;
  receiptUri?: string;
};

export type Entry = {
  id: string;
  category: Category;
  title: string;
  /** When the care happened. ISO 8601. */
  occurredAt: string;
  /** When it was logged. Shown in the report as evidence (R9). ISO 8601. */
  loggedAt: string;
  minutes: number;
  /** A visit counts once toward the visits total. */
  visit: boolean;
  expense?: Expense;
  /** Private by default; the caregiver chooses to include notes in a report (R7). */
  note?: string;
};
