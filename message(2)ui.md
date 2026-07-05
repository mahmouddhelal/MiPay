# MiPay UI Redesign — Fintech Dark/Light Restyle

## Context

MiPay is a **voice-first AI expense tracker** (income/expense, categories, voice capture,
en/ar with RTL). Its current UI is stock Material 3 — a blue seed color, default
`NavigationBar`, plain `Card`/`ListTile`, and basic `AppBar`s. The user provided a
reference design in `ui ux ref/` (17 frames) of a polished dark **fintech wallet**:

- A **blue→purple gradient "balance" hero card** with a large balance number and an
  eye/hide toggle.
- A row of **translucent circular action buttons** with labels under the balance.
- **Pill-style segmented tabs** (Crypto/Fiat/… in the ref).
- A **"spending this month" card** with a colorful **donut chart** and a Spending/Income toggle.
- A **category breakdown list** with **colored circular category icons**, amount + percentage.
- A **minimal bottom nav** with outline icons (Home / Card / Accounts / Savings), only the
  active label/icon in full white.
- Rounded surfaces (~20–28px radius), generous spacing, large display typography.

**Goal:** port this *visual language* onto MiPay's real screens across the whole app, in
**both light and dark themes** — keeping MiPay's actual features (no crypto/mock wallet data).
The data maps cleanly: the dashboard already has a donut + category list, `Category` already
exposes `iconData`, and there's a net/income/expense summary.

## Design principles for the mapping

| Reference element | MiPay adaptation |
|---|---|
| "Total balance" gradient hero | **"Net this month"** (or balance) hero on Dashboard, with income/expense underneath |
| 4 circular action buttons | Real actions: **Add**, **Record (voice)**, **Income filter**, **Expense filter** |
| Crypto asset cards | *Dropped* — replaced by MiPay's category breakdown (real data) |
| Donut + Spending/Income toggle | Existing dashboard donut, restyled; toggle drives income vs expense breakdown |
| Colored category rows | Existing `_CategoryList`, restyled with colored circular icons + % + amount |
| Outline bottom nav | Custom nav replacing Material `NavigationBar` (Home/Transactions/Dashboard/Settings) |

## 1. Design system (foundation — do this first)

Create a small token + widget layer so every screen shares one look and both themes stay in sync.

**`lib/core/theme/app_colors.dart`** (new)
- Dark palette: `bg #0E0E12`, `surface #17171C`, `surfaceElevated #212128`, `outline #2A2A31`,
  muted text `#8A8A93`. Light palette: `bg #F5F5F8`, `surface #FFFFFF`, `surfaceElevated #FFFFFF`,
  outline `#E6E6EC`, muted `#6B6B75`.
- Brand gradient: `#2B2BE0 → #6D6BF5` (the royal-blue→indigo of the hero). Expose as a
  `LinearGradient` (top-left dark → bottom-right bright, matching the frames).
- Semantic: `positive #22C55E`, `negative #EF4444`, `accent #6366F1`.
- Move the existing 12-color `_kPalette` here as `categoryPalette`, and add
  `Color categoryColor(String key)` — deterministic hash of the category key → palette color,
  so a category shows the **same** color in the donut, the breakdown list, the transaction
  tiles, and the filter chips. This is the key reuse point (dashboard, transaction_tile,
  transactions_screen filter chips all consume it).

**`lib/core/theme/app_theme.dart`** (rewrite)
- Keep `light()` / `dark()` signatures (consumed by `app.dart`, no call-site change).
- Build full `ColorScheme`s from `AppColors` (not just `fromSeed`) so surfaces/gradients are
  exact. Set `scaffoldBackgroundColor`, `cardTheme` (radius 24, no elevation, `surface` color),
  `navigationBarTheme`, `inputDecorationTheme` (filled, radius 16/pill, subtle fill),
  `appBarTheme` (transparent, no elevation, large title), `textTheme` (bump weights; large
  display for balance ~40/bold, tabular-ish numerals), `filledButtonTheme`/`segmentedButtonTheme`
  (pill radius). Keep `useMaterial3: true`.
- *(Optional polish, not required):* bundle an Inter font as an asset for the exact ref feel;
  otherwise system font with the tuned weights is fine. Note only — avoid `google_fonts`
  (runtime network fetch).

**`lib/core/widgets/` (new shared widgets):**
- `gradient_balance_card.dart` — `GradientBalanceCard`: the hero. Props: title, amount,
  currency, optional income/expense subvalues, a hide-balance toggle, and a `List<CircleAction>`.
  Renders the gradient, large number, and the circular-action row.
- `circle_action_button.dart` — `CircleActionButton`: translucent circular icon + label under it.
- `segmented_pills.dart` — `SegmentedPills<T>`: the pill tab selector (reused on Dashboard +
  Transactions type toggle). Thin wrapper styled to the ref; can back onto `SegmentedButton`.
- `category_avatar.dart` — `CategoryAvatar`: colored circle (from `categoryColor`) + white
  `iconData`. Reused in transaction tiles, category list, filter chips.
- `section_card.dart` — `SectionCard`: rounded `surface` container with consistent padding
  (the wrapper used by the donut card, settings sections, etc.).
- `app_bottom_nav.dart` — `AppBottomNav`: custom nav bar matching the ref (outline icons,
  active = full-white icon+label, inactive = muted, transparent/blurred bg, safe-area padded).

## 2. Per-screen changes

**Bottom nav shell — `lib/core/router/app_router.dart` (`_MainShell`)**
Replace the Material `NavigationBar` with `AppBottomNav`. Keep the 4 existing tabs and routing
logic (Home / Transactions / Dashboard / Settings). Icons: `home_outlined`/`home`,
`receipt_long_outlined`/`receipt_long`, `pie_chart_outline`/`pie_chart`,
`settings_outlined`/`settings`.

**Dashboard — `lib/features/dashboard/ui/dashboard_screen.dart`**
- Replace `AppBar` with an in-body header: `CategoryAvatar`-style circle with user initials +
  display name (from `authControllerProvider`) + a bell/settings icon button.
- Add `GradientBalanceCard` showing **balance / net** for the month with income & expense
  beneath, plus the 4 `CircleActionButton`s (Add → transaction form; Record → go `/home`;
  Income/Expense → set dashboard filter). Wire a hide-balance toggle (local state; masks the number).
- Restyle the month stepper as a compact pill row.
- Wrap donut + toggle in a `SectionCard` titled "Spending this month" with the transaction count
  ("You've made N transactions"). Add a Spending/Income `SegmentedPills` toggle that switches the
  donut/list between expense categories and income categories (data already in `summary.byCategory`
  for expense; income breakdown may need the toggle to show total income vs expense split if the
  API only returns expense categories — if so, keep the toggle but note income view shows the
  income total card). Restyle `_DonutChart` (thicker ring, center total label) and `_CategoryList`
  rows to use `CategoryAvatar` + amount + `%` like the ref.

**Home/Record — `lib/features/record/ui/home_screen.dart` + `mic_button.dart`**
- Add a small gradient greeting strip / header ("Hi, {name}") for consistency.
- Restyle `MicButton`: gradient fill + soft glow ring (reuse `AppColors.brandGradient`); keep the
  pulse/processing animation logic untouched.
- Restyle the "type instead" `TextField` as a filled pill (via `inputDecorationTheme`).
- Restyle the "Recent transactions" section header + list using the new `TransactionTile`.

**Transactions — `lib/features/transactions/ui/transactions_screen.dart`**
- Filter bar: month stepper as pill; expense/income `SegmentedButton` → `SegmentedPills`;
  category `FilterChip`s restyled (use `CategoryAvatar` mini + `categoryColor`).
- Day headers: uppercase muted label style.
- Restyle FAB as a gradient rounded button; keep dismissible swipe + confirm dialog behavior.

**Transaction tile — `lib/features/transactions/ui/transaction_tile.dart`**
- Swap the `CircleAvatar`(secondaryContainer) for `CategoryAvatar` (per-category color). Keep the
  voice `mic` badge, name/category, and colored signed amount (`positive`/`negative` tokens).

**Settings — `lib/features/settings/ui/settings_screen.dart`**
- Profile header (avatar initials + name + email). Wrap Profile / Language / Account groups in
  `SectionCard`s; restyle inputs (theme-driven), language `SegmentedPills`, and a full-width
  gradient Save button. Keep the outlined destructive Logout.

**Auth — `lib/features/auth/ui/login_screen.dart` + `register_screen.dart`**
- Dark/light branded background, centered logo/wordmark, pill inputs, full-width **gradient**
  primary button, subtle link styling. (Read these two files during implementation — not yet
  inspected; keep all form/validation/controller logic intact, restyle only.)

## Constraints to preserve

- **i18n/RTL:** use `EdgeInsetsDirectional` / `AlignmentDirectional` and existing `l10n` strings
  everywhere (app supports en + ar). No hardcoded English.
- **No behavior/logic changes** to Riverpod providers, routing redirects, recording controller,
  or repositories — this is a presentation-layer restyle.
- Both themes must be styled; `themeMode` stays `ThemeMode.system` in `app.dart`.

## Key files

- New: `lib/core/theme/app_colors.dart`, `lib/core/widgets/{gradient_balance_card,
  circle_action_button,segmented_pills,category_avatar,section_card,app_bottom_nav}.dart`
- Rewrite: `lib/core/theme/app_theme.dart`
- Edit: `lib/core/router/app_router.dart`, `features/dashboard/ui/dashboard_screen.dart`,
  `features/record/ui/home_screen.dart`, `features/record/ui/mic_button.dart`,
  `features/transactions/ui/{transactions_screen,transaction_tile}.dart`,
  `features/settings/ui/settings_screen.dart`,
  `features/auth/ui/{login_screen,register_screen}.dart`

## Verification

1. `cd mipay_app && flutter analyze` — no new warnings/errors.
2. Run the app (via `/run` or `flutter run -d chrome` / device). If the backend isn't up,
   `docker compose up` per `docker-compose.yml`, or drive the auth/dashboard screens with the
   existing dev flow.
3. Visually confirm each screen against the frames: Dashboard hero + donut + category rows,
   custom bottom nav, restyled Home/mic, Transactions list, Settings, Login/Register.
4. Toggle device dark/light — verify both themes read correctly (surfaces, gradient contrast,
   muted text legibility).
5. Switch to Arabic in Settings — verify RTL layout and mirrored paddings hold.
