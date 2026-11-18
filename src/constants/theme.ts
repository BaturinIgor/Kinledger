/**
 * Kinledger design tokens. Rationale and contrast checks: docs/design.md.
 *
 * One color per quantity, the same in the app and in the report siblings see:
 * time = teal, money = ochre, visits = indigo. Red is for input errors only.
 */

import '@/global.css';

import { Platform } from 'react-native';

export const Colors = {
  light: {
    background: '#F7F5F0',
    card: '#FFFFFF',
    border: '#E4E1D8',
    divider: '#ECE9E1',
    inputBorder: '#CFCBC0',
    text: '#18211E',
    textSecondary: '#4F5A55',
    time: '#0B6E66',
    timeSoft: '#DDEFEA',
    onTime: '#FFFFFF',
    money: '#A24E05',
    moneySoft: '#FCEBD3',
    moneyInk: '#6B3307',
    visits: '#4353A6',
    visitsSoft: '#E5E8F7',
    error: '#B3261E',
  },
  dark: {
    background: '#121816',
    card: '#1B2320',
    border: '#2C3632',
    divider: '#2C3632',
    inputBorder: '#3A4641',
    text: '#ECF1EE',
    textSecondary: '#A9B4AF',
    time: '#5CC2B5',
    timeSoft: '#173A36',
    onTime: '#121816',
    money: '#F0A55A',
    moneySoft: '#3A2A17',
    moneyInk: '#F7C99A',
    visits: '#9AA6F0',
    visitsSoft: '#1E2540',
    error: '#F2B8B5',
  },
} as const;

export type ThemeColor = keyof typeof Colors.light;
export type Theme = { [K in ThemeColor]: string };

export const Fonts = Platform.select({
  ios: { sans: 'system-ui', rounded: 'ui-rounded', mono: 'ui-monospace' },
  default: { sans: 'normal', rounded: 'normal', mono: 'monospace' },
  web: { sans: 'var(--font-display)', rounded: 'var(--font-rounded)', mono: 'var(--font-mono)' },
});

/** Minimum sizes for a 40–65 audience: body 17, labels 14. */
export const Type = {
  title: { fontSize: 30, lineHeight: 36, fontWeight: '600' },
  number: { fontSize: 26, lineHeight: 32, fontWeight: '600' },
  heading: { fontSize: 17, lineHeight: 24, fontWeight: '600' },
  body: { fontSize: 17, lineHeight: 24, fontWeight: '400' },
  row: { fontSize: 16, lineHeight: 22, fontWeight: '600' },
  label: { fontSize: 14, lineHeight: 20, fontWeight: '500' },
} as const;

export const Spacing = {
  half: 2,
  one: 4,
  two: 8,
  three: 16,
  four: 24,
  five: 32,
  six: 64,
} as const;

export const Radius = { card: 20, tile: 12, pill: 999 } as const;

/** Touch targets: 44 minimum, primary actions 56. */
export const Touch = { min: 44, primary: 56 } as const;

export const BottomTabInset = Platform.select({ ios: 50, android: 80 }) ?? 0;
export const MaxContentWidth = 640;
