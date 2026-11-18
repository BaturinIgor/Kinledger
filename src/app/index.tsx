import { useRouter } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';

import { EntryRow } from '@/components/entry-row';
import { Screen } from '@/components/screen';
import { StatTile } from '@/components/stat-tile';
import { ThemedText } from '@/components/themed-text';
import { Radius, Spacing, Touch } from '@/constants/theme';
import { sampleEntries } from '@/data/sample';
import { formatDuration, formatMoney } from '@/domain/format';
import { inMonth, recent, totals } from '@/domain/summary';
import { useTheme } from '@/hooks/use-theme';

// Until local storage lands, the screen shows the mockup month (November 2026).
const YEAR = 2026;
const MONTH = 10;

export default function TodayScreen() {
  const theme = useTheme();
  const router = useRouter();
  const month = inMonth(sampleEntries, YEAR, MONTH);
  const sum = totals(month);
  const monthName = new Date(YEAR, MONTH).toLocaleString('en-US', { month: 'long' });

  return (
    <Screen>
      <View style={styles.header}>
        <ThemedText type="label" themeColor="textSecondary">
          Caring for Mom
        </ThemedText>
        <ThemedText type="title">Today</ThemedText>
      </View>

      <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
        <ThemedText type="heading">{monthName} so far</ThemedText>
        <View style={styles.tiles}>
          <StatTile tone="time" label="of care" value={formatDuration(sum.minutes, 'summary')} />
          <StatTile tone="money" label="out of pocket" value={formatMoney(sum.outOfPocketCents)} />
          <StatTile tone="visits" label="visits" value={String(sum.visits)} />
        </View>
      </View>

      <Pressable
        accessibilityRole="button"
        onPress={() => router.navigate('/log')}
        style={({ pressed }) => [
          styles.primary,
          { backgroundColor: theme.time, opacity: pressed ? 0.85 : 1 },
        ]}>
        <ThemedText type="heading" themeColor="onTime">
          Log care
        </ThemedText>
      </Pressable>

      <View style={[styles.card, { backgroundColor: theme.card, borderColor: theme.border }]}>
        <ThemedText type="heading">Recent</ThemedText>
        {recent(sampleEntries, 5).map((e) => (
          <EntryRow key={e.id} entry={e} />
        ))}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { gap: Spacing.one, paddingTop: Spacing.two },
  card: {
    borderRadius: Radius.card,
    borderWidth: StyleSheet.hairlineWidth,
    padding: Spacing.three,
    gap: Spacing.three,
  },
  tiles: { flexDirection: 'row', gap: Spacing.two },
  primary: {
    minHeight: Touch.primary,
    borderRadius: Radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
