import { StyleSheet, View } from 'react-native';

import { Radius, Spacing, type ThemeColor } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

import { ThemedText } from './themed-text';

type Props = {
  label: string;
  value: string;
  /** One color per quantity: time, money or visits. */
  tone: Extract<ThemeColor, 'time' | 'money' | 'visits'>;
};

export function StatTile({ label, value, tone }: Props) {
  const theme = useTheme();
  return (
    <View
      accessible
      accessibilityLabel={`${label}: ${value}`}
      style={[styles.tile, { backgroundColor: theme[`${tone}Soft`] }]}>
      <ThemedText type="number" style={{ color: theme[tone] }}>
        {value}
      </ThemedText>
      <ThemedText type="label" themeColor="textSecondary">
        {label}
      </ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
  tile: {
    flex: 1,
    borderRadius: Radius.tile,
    paddingVertical: Spacing.three,
    paddingHorizontal: Spacing.two,
    gap: Spacing.one,
  },
});
