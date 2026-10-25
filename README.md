# FinFlow

Personal finance tracker for Android, built with Flutter and GetX.
Application ID: `com.kalainova.finflow`.

Users enter their own transactions, credit cards, card bills and EMIs; all
data is stored on the device in SQLite. FinFlow has no servers, no accounts
and no internet permission, and does not connect to banks or card issuers.

## Features

- **Transactions:** add, edit and delete spending and income; search, filter
  and sort the history; CSV export.
- **Dashboard and insights:** monthly cash flow, daily spending chart,
  spending by category, top payees, month-on-month comparison.
- **Credit cards:** limit, statement and due days, current outstanding (with
  a "possibly out of date" flag after 7 days).
- **Bills:** total and minimum due per statement; status (unpaid, partly
  paid, minimum paid, paid, overdue) derived from recorded payments.
  Duplicate statements are refused.
- **EMIs:** schedule, instalments due and remaining, next due date, cost of
  credit, early closure.
- **Split:** groups for a room, flat or trip; expenses paid by anyone, split
  equally, by amount or by shares (exact to the paisa); balances, fewest
  payments to settle up, recorded settlements, a shareable text summary,
  and "left to save or invest this month". A spend can be split when it is
  added or later from its details.
- **Bill reminders:** local notifications 3 days before and on the due date
  (opt-in; inexact alarms, no exact-alarm permission).
- **Correct totals:** card bill payments, transfers and split settlements are
  "movements", not spending, so nothing is counted twice. For a split spend
  only the user's share counts (the full amount paid is kept for the
  record). EMI instalments are tracked as a schedule, not as new spending.
- Onboarding, light/dark themes, glass design, accessibility labels, layouts
  tested from 320dp phones to tablets at 1.3× text.

## Commands

```sh
flutter pub get
flutter run                                       # debug build
flutter analyze
flutter test                                      # unit, widget, layout, SQLite
flutter test integration_test/app_flow_test.dart -d <emulator-id>
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
python3 tool/build_privacy_html.py                # privacy-policy.md -> .html
```

Store screenshots come from `integration_test/store_screenshots_test.dart`
(fictional data, emulator only); see `docs/play-store/listing.md`.

Release signing, store listing, privacy policy and Play Console answers:
see [docs/play-store/release-checklist.md](docs/play-store/release-checklist.md).

Frame-timing check on an emulator (profile mode):

```sh
flutter drive --no-dds --profile -d <emulator-id> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart
```

## Test data

The app ships with no sample or demo data in any build; everything shown is
what the user enters. Tests build their fixtures from
`test/fixtures/sample_data.dart`, which is not part of `lib/`.

## Architecture

```
lib/
  main.dart            Opens storage, installs error handling, runs the app
  app/                 GetMaterialApp, routes, DI bindings, theme and
                       reminder services
  core/                Theme tokens, motion, formatting, errors, config
  domain/              Pure Dart: entities (Transaction, CreditCard, CardBill,
                       EmiPlan, Money), repository interfaces, analytics and
                       reminder planning
  data/
    sources/           FinanceStore interface; SqliteFinanceStore (app) and
                       InMemoryFinanceStore (tests); key-value preferences
    repositories/      Business rules over the store (validation, derived
                       bill payments, duplicate checks, CSV export)
  features/            One folder per screen: page + GetX controller
  shared/widgets/      Reusable UI (glass, buttons, inputs, sheets, charts)
tool/generate_icons.py Launcher, notification and store graphics
docs/play-store/       Listing, privacy policy, data safety, release steps
```

Dependencies point inwards: `features` → `domain` ← `data`. Controllers use
repository interfaces only. A future automatic data source (for example an
Account Aggregator integration through a regulated partner) would write into
the same repositories; the UI and rules above them would not change.

### Splits

`SplitRepository` stores groups, expenses and settlements, and mirrors the
user's side of each as a transaction so dashboards and insights stay right:
paid by the user → full amount with `share` = the user's part; paid by
someone else → the user's part with method "Paid by someone else";
settlements involving the user → a `settlement` movement. Deleting either
side removes both. Balances and settle-up suggestions come from the pure
`SplitLedger`; `SplitCalculator` splits amounts so they always add up.

### Database

SQLite schema version 2 (`SqliteFinanceStore`; version 2 added splits and
the `share_minor` / `split_id` transaction columns). Amounts are integer minor
units; enums are stored by name with safe fallbacks. To change the schema,
bump `schemaVersion` and add a new `if (from < n)` migration block; never
edit an existing one.

### Visual design

- **Glass:** cards, the navigation bar and sheets are frosted glass. Over the
  app background, glass draws a slice of a pre-blurred copy of the
  background (rendered once) instead of blurring live each frame.
- **Backdrop:** colour fields and finance objects, painted in code.
- **Type:** Manrope (bundled; SIL Open Font License).
- Glass must not sit inside an `Opacity` or `ImageFiltered` layer. Entrance
  animations "frost in" glass via `RevealScope`, and transitions use
  transforms only.
