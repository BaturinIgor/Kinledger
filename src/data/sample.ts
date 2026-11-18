import type { Entry } from '@/domain/types';

/** Sample data matching the mockups, until local storage lands. */
export const sampleEntries: Entry[] = [
  {
    id: 'e1',
    category: 'pharmacy',
    title: 'Pharmacy pickup',
    occurredAt: '2026-11-18T15:00:00',
    loggedAt: '2026-11-18T15:12:00',
    minutes: 25,
    visit: false,
    expense: { amountCents: 4280, payer: 'me', medical: true },
    note: 'Receipt saved',
  },
  {
    id: 'e2',
    category: 'doctor',
    title: 'Dr. Patel, cardiology',
    occurredAt: '2026-11-16T10:00:00',
    loggedAt: '2026-11-16T12:30:00',
    minutes: 130,
    visit: true,
    expense: { amountCents: 1800, payer: 'me', medical: true },
    note: 'Drove her',
  },
  {
    id: 'e3',
    category: 'overnight',
    title: 'Overnight stay',
    occurredAt: '2026-11-15T22:30:00',
    loggedAt: '2026-11-16T07:40:00',
    minutes: 540,
    visit: true,
    note: "After a fall, she's OK",
  },
  {
    id: 'e4',
    category: 'groceries',
    title: 'Groceries',
    occurredAt: '2026-11-14T11:00:00',
    loggedAt: '2026-11-14T12:05:00',
    minutes: 60,
    visit: true,
    expense: { amountCents: 6715, payer: 'parent', medical: false },
  },
];
