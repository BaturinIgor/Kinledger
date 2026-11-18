import { Text, type TextProps } from 'react-native';

import { Type, type ThemeColor } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

export type ThemedTextProps = TextProps & {
  type?: keyof typeof Type;
  themeColor?: ThemeColor;
};

export function ThemedText({ style, type = 'body', themeColor = 'text', ...rest }: ThemedTextProps) {
  const theme = useTheme();
  return <Text style={[Type[type], { color: theme[themeColor] }, style]} {...rest} />;
}
