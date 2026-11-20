# App Privacy answers (App Store Connect → App Privacy)

What to click, so the label matches `Kinledger/PrivacyInfo.xcprivacy`, `docs/privacy.md` and `docs/data-safety.md`.

**Do you or your third-party partners collect data from this app?** Yes.
Data leaves the phone only when the person turns on cloud backup (Sign in with Apple) or makes a report link.
Supabase is our processor, not a third party that uses the data for itself.

## Data types

For every type below: **Linked to the user: Yes. Used for tracking: No. Purpose: App Functionality only.**

| App Store Connect type | What it is in Kinledger |
| --- | --- |
| Health & Fitness → Health | Doctor visits, care notes and "medical expense" marks about the person cared for |
| Financial Info → Other Financial Info | Amounts paid and who paid them |
| User Content → Photos or Videos | Receipt photos |
| User Content → Other User Content | Entries, notes, the cared-for person's name and nickname, family members' names and email or phone for the report |
| Identifiers → User ID | The Sign in with Apple account id |

## Not collected

- Contact Info: Sign in with Apple asks for no name or email.
- Location, Contacts, Browsing History, Search History, Purchases (Apple handles subscriptions), Usage Data, Sensitive Info.
- Diagnostics: crash reports stay on the iPhone. A person can choose to send one to support from Me → Send diagnostics.
  That is optional, rare and started by the person, so Apple does not require it on the label.
- No tracking, no ads and no analytics SDKs, so there is no App Tracking Transparency prompt.

## Privacy links

- Privacy Policy: https://baturinigor.github.io/Kinledger/privacy
- Account deletion: in the app, Me → Delete cloud account (guideline 5.1.1(v)).
