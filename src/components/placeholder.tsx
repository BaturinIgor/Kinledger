import { Screen } from './screen';
import { ThemedText } from './themed-text';

/** Stand-in for screens that are designed but not built yet. */
export function Placeholder({ title, body }: { title: string; body: string }) {
  return (
    <Screen>
      <ThemedText type="title">{title}</ThemedText>
      <ThemedText themeColor="textSecondary">{body}</ThemedText>
    </Screen>
  );
}
