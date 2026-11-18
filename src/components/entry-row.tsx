import { StyleSheet, View } from 'react-native';

import { Spacing, Touch } from '@/constants/theme';
import { formatDuration, formatMoney } from '@/domain/format';
import type { Entry } from '@/domain/types';
import { useTheme } from '@/hooks/use-theme';

import { ThemedText } from './themed-text';

const dateFormat = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' });

export function EntryRow({ entry }: { entry: Entry }) {
  const theme = useTheme();
  const when = dateFormat.format(new Date(entry.occurredAt));
  const details = [when, entry.note].filter(Boolean).join(' · ');

  return (
    <View style={[styles.row, { borderBottomColor: theme.divider }]}>
      <View style={styles.main}>
        <ThemedText type="row">{entry.title}</ThemedText>
        <ThemedText type="label" themeColor="textSecondary">
          {details}
        </ThemedText>
      </View>
      <View style={styles.amounts}>
        <ThemedText type="label" themeColor="time">
          {formatDuration(entry.minutes)}
        </ThemedText>
        {entry.expense ? (
          <ThemedText type="label" themeColor="money">
            {formatMoney(entry.expense.amountCents)}
            {entry.expense.payer === 'me' ? '' : ' · not mine'}
          </ThemedText>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: Touch.primary,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.three,
    paddingVertical: Spacing.two,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  main: { flex: 1, gap: Spacing.half },
  amounts: { alignItems: 'flex-end', gap: Spacing.half },
});
