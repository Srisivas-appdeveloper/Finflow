# Google Play store listing: FinFlow

Copy these into Play Console > Grow > Store presence > Main store listing.
Character limits are Play's; lengths were checked with a script (name 24, short 78, full 1867).

## App name (max 30)

FinFlow: Expense Tracker

## Short description (max 80)

Track spending, split bills with roommates, and never miss a card bill or EMI.

## Full description (max 4000)

Paste exactly as below (one line per bullet).

```text
FinFlow is a beautifully simple way to see where your money goes, and to stay on top of credit card bills and EMIs, without handing your data to anyone.

TRACK EVERY RUPEE
• Add spending and income in seconds: amount, payee, category, date
• Search and filter your history by category, status and amount
• See this month's spending, daily average and net cash flow at a glance

UNDERSTAND YOUR SPENDING
• Spending by category, top payees and the last 7 days, as clear charts
• Compare this month with the same period last month

SPLIT WITH ROOMMATES AND FRIENDS
• Make a group for your hostel room, flat or trip
• Add who paid and split equally, by amount or by shares
• See who owes whom and the fewest payments to settle up
• Only your share counts as your spending, so you see what is really left to save or invest each month
• Share a summary with the group in one tap

CREDIT CARDS, BILLS AND EMIS
• Add your cards with their credit limit, statement day and due day
• Enter each statement's total and minimum due; FinFlow shows what's due next and flags anything overdue
• Record payments: paying a card bill settles what you owe and is never counted as new spending, so your totals stay honest
• Track EMIs: instalments paid so far, what's left and the next due date
• Optional reminders 3 days before and on the due date

PRIVATE BY DESIGN
• Everything stays on your phone. FinFlow has no account, no servers and no internet access
• No bank login, no SMS or email reading, no ads, no tracking
• Export your transactions as a CSV whenever you want, or delete everything with one tap

DESIGNED TO FEEL GOOD
• Light and dark themes, smooth animations and a calm glass design

FinFlow does not connect to banks or card issuers: amounts and due dates are the ones you enter. It is a personal tracking tool and does not provide financial advice, payments or credit.
```

## Category and tags

- App category: Finance
- Tags (pick up to 5 in Console): Personal finance, Budgeting, Expense tracker

## Contact details (required)

- Email: info@kalainovainfotech.com
- Website: optional
- Privacy policy URL: https://srisivas-appdeveloper.github.io/finflow-privacy/
  (GitHub Pages, repo `Srisivas-appdeveloper/finflow-privacy`; to update, run
  `python3 tool/build_privacy_html.py` and push the new file as `index.html`)
- Developer name: Kalainova

## Graphics

| Asset | File | Spec |
| --- | --- | --- |
| App icon | `graphics/icon-512.png` | 512×512 PNG |
| Feature graphic (banner) | `graphics/feature-graphic-1024x500.png` | 1024×500, 24-bit PNG, no transparency |
| Phone screenshots | `screenshots/01-home.png` … `08-home-dark.png` | 8 images, 1080×1920 (9:16; Play allows at most 2:1), fictional data |

Regenerate icons with `python3 tool/generate_icons.py`, and the banner with
`cd tool && python3 generate_banner.py` (after the screenshots below).

Regenerate screenshots on an emulator (never a personal phone):

```sh
adb -s EMULATOR_ID shell wm size 1080x1920
flutter drive -d EMULATOR_ID --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/store_screenshots_test.dart
adb -s EMULATOR_ID shell wm size reset
```
