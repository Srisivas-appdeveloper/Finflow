# Play Console: App content answers

Answers for Play Console > Policy > App content, based on what the code
actually does (verified on the release build: the merged manifest requests
no `INTERNET` permission; no analytics, ads or crash SDKs are included).
Re-check these whenever a dependency or feature is added.

## Data safety

| Question | Answer | Why |
| --- | --- | --- |
| Does your app collect or share any of the required user data types? | **No** | Data entered is stored only on the device and never transmitted. Play counts data as "collected" only when it leaves the device. |
| Is all user data encrypted in transit? | Not applicable | Nothing is transmitted. |
| Do you provide a way for users to request deletion? | Yes, in-app | Profile > Your data > Delete all data. |

The CSV export and the split-group summary are started by the user, who
chooses the destination app. Names of people in split groups are typed by
the user and stay on the device, like everything else.
Play treats that kind of user-initiated transfer as not "sharing"; keep the
export behind an explicit user action.

## Other declarations

| Section | Answer |
| --- | --- |
| Privacy policy | Host `privacy-policy.md` at a public URL and enter it |
| Ads | No, the app does not contain ads |
| App access | All functionality available without special access (no login) |
| Content rating | Complete the questionnaire: Utility/Finance, no user-generated public content, no violence; expect "Everyone" / PEGI 3 |
| Target audience | 18+ recommended (personal finance) |
| News app | No |
| Government app | No |
| Health apps | No |
| Financial features | Declare personal finance / expense tracking only: **no** loans, payments, trading, banking or credit services. Check the current options in Console. |
| Permissions | `POST_NOTIFICATIONS` (bill reminders, user opt-in), `RECEIVE_BOOT_COMPLETED` (restore reminders after restart). No sensitive or restricted permissions (no SMS, call log, contacts, location, exact alarms). |
