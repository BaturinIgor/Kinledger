# Design tokens

Source of truth: `src/constants/theme.ts`. Mockups: [Kinledger MVP mockups](https://claude.ai/artifact/12KEn6bYc7X67UZBuwEncV).

One color per quantity, the same in the app and in the report siblings see. Red is for input errors only.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| background | #F7F5F0 | #121816 | Paper |
| card | #FFFFFF | #1B2320 | Cards |
| text | #18211E | #ECF1EE | Body |
| textSecondary | #4F5A55 | #A9B4AF | Labels |
| time | #0B6E66 | #5CC2B5 | Hours of care, primary action |
| money | #A24E05 | #F0A55A | Out of pocket |
| visits | #4353A6 | #9AA6F0 | Visits |
| error | #B3261E | #F2B8B5 | Input errors only |

All text pairs pass WCAG AA. Body 17, labels at least 14. Touch targets 44, primary actions 56.
