# App Store listing

`metadata/<locale>/` holds the text for each App Store Connect language, in the layout
[fastlane deliver](https://docs.fastlane.tools/actions/deliver/) reads. Without fastlane, copy each file
into the matching field in App Store Connect → App Information / version page.

| File | Field | Limit |
| --- | --- | --- |
| name.txt | Name | 30 |
| subtitle.txt | Subtitle | 30 |
| promotional_text.txt | Promotional Text | 170 |
| keywords.txt | Keywords (comma separated, no spaces) | 100 |
| description.txt | Description | 4000 |
| privacy_url.txt, support_url.txt | Privacy Policy URL, Support URL | |

Locales: en-US, es-ES, fr-FR, de-DE, it, pt-BR, nl-NL, sv, da, no, pl, ru, uk, tr, ja, ko, zh-Hans, zh-Hant.
The app itself ships the same 18 languages and follows the iPhone's language.
