# MiPay — Egyptianization, User-Data Isolation Fix, Monochrome UI Redesign

## Context

MiPay is an Egyptian voice-first expense tracker (FastAPI backend + Flutter app), but today it doesn't feel Egyptian, leaks data between users on the same device, and has a generic blue Material theme. Three problems to fix:

1. **Arabic is formal MSA, not Egyptian** — UI strings in `app_ar.arb` read like a bank letter ("يرجى تسجيل الدخول مجدداً"); default currency is **SAR**; the LLM extraction prompt uses Gulf examples ("دفعت خمسين ريال"); only 17 generic categories exist.
2. **Cross-user data leak** — Backend is verified correct (every query filters by `current_user.id`). The leak is client-side: Riverpod providers (`transactionsProvider`, `summaryProvider`) cache user A's data in memory and are never invalidated on logout/login, so user B on the same device sees A's transactions and dashboard totals.
3. **UI/UX** — single blue seed color, no in-app theme toggle (`themeMode: ThemeMode.system` hardcoded), hardcoded `Colors.red/green/amber/white` scattered across screens.

Approach: a premium **monochrome (black & white) design system** with light/dark toggle, full Egyptian-Arabic rewrite + 12 new Egypt-relevant categories, and a structural fix for user isolation (data providers derive from the authenticated user id).

---

## Phase 1 — Fix cross-user data leak (highest priority)

**Primary mechanism: every per-user data provider watches the current user id.** When the id changes (A → null → B), Riverpod destroys and rebuilds the state automatically — stale data is impossible by construction, and future providers inherit safety by following the same one-line pattern. Add `autoDispose` as belt-and-braces. (Rejected alternative: manually `ref.invalidate(...)` in login/logout — it's an allowlist that every future provider must remember to join.)

- **New** [current_user_provider.dart](mipay_app/lib/core/providers/current_user_provider.dart):
  ```dart
  final currentUserIdProvider = Provider<String?>((ref) {
    final auth = ref.watch(authControllerProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  });
  ```
  (`User.id` exists — `mipay_app/lib/features/auth/models/user.dart:10`.)
- [transactions_provider.dart](mipay_app/lib/features/transactions/providers/transactions_provider.dart):
  - `transactionsProvider` → `FutureProvider.autoDispose.family`, watches `currentUserIdProvider`; returns `[]` if null.
  - `transactionFilterProvider` (StateProvider) also watches `currentUserIdProvider` so user B doesn't inherit A's selected month/filter.
  - `categoriesProvider` stays global (reference data, no personal info) — add a comment saying why it's exempt.
- [summary_provider.dart](mipay_app/lib/features/dashboard/providers/summary_provider.dart): same pattern for `summaryProvider` + reset `dashboardMonthProvider`.
- [recording_controller.dart](mipay_app/lib/features/record/providers/recording_controller.dart): make `autoDispose` / watch user id so a pending transcript from A never shows for B.
- **Bonus fix while here**: `summaryProvider` is never invalidated after create/edit/delete → dashboard shows stale totals. Add `ref.invalidate(summaryProvider)` next to the existing `ref.invalidate(transactionsProvider)` calls in `transaction_form.dart:99` and `transactions_screen.dart:49,241`.
- **Backend hardening**: delete [backend/app/api/v1/debug.py](backend/app/api/v1/debug.py) — unauthenticated `/debug/transcribe`, not wired into the router, zero-risk deletion.

## Phase 2 — Backend Egyptianization

### 2.1 New migration `backend/alembic/versions/0003_egyptian_categories_egp.py` (down_revision `0002`)

**a) UPDATE `label_ar` of the existing 17** to Egyptian-friendly labels, e.g.: fuel → **بنزين**, restaurants → **مطاعم وأكل برة**, entertainment → **خروجات وترفيه**, salary → **المرتب**, transfer_in → **فلوس جاتلي**, other → **حاجات تانية**, gifts_donations → **هدايا وصدقة**, shopping → **شوبينج**, clothes-adjacent stay as-is where already natural (مواصلات، فواتير، إيجار، سفر، تعليم). Also `sort_order = 99` for `other` so it stays last.

**b) INSERT 12 new categories** (key / label_en / label_ar / icon / kind / sort):

| key | label_en | label_ar | icon | kind |
|---|---|---|---|---|
| coffee | Coffee & Cafés | قهوة وكافيهات | local_cafe | expense |
| internet_mobile | Internet & Mobile | نت وموبايل | wifi | expense |
| subscriptions | Subscriptions | اشتراكات | subscriptions | expense |
| household | Home & Family | مصاريف البيت والعيلة | family_restroom | expense |
| tuition | Private Lessons | دروس خصوصية | menu_book | expense |
| clothes | Clothes | هدوم ولبس | checkroom | expense |
| pets | Pets | حيوانات أليفة | pets | expense |
| insurance | Insurance | تأمين | shield | expense |
| savings | Savings & Gam'eya | توفير وجمعية | savings | both |
| transfer_out | Transfer Out | فلوس باعتها | arrow_upward | expense |
| freelance | Freelance | شغل فريلانس | laptop_mac | income |
| investments | Investments | استثمارات | trending_up | both |

**c) Currency**: `op.alter_column("users", "default_currency", server_default="EGP")` + `UPDATE users SET default_currency='EGP' WHERE default_currency='SAR'` (existing SAR values are the untouched old default, not user choices; deliberate USD/EUR picks are untouched; documented in migration docstring).

### 2.2 Code defaults
- `backend/app/models/user.py:17` — `default="SAR"` → `"EGP"`.
- `backend/app/schemas/auth.py` — register default `"SAR"` → `"EGP"`.
- `backend/app/schemas/transaction.py` — add 12 new keys to `CATEGORY_KEYS` (17 → 29).
- `backend/app/services/extraction.py` — add 12 keys to `EXTRACTION_SCHEMA` category enum.

### 2.3 Extraction prompt re-tune ([extraction.py](backend/app/services/extraction.py))
⚠️ File header says prompt is verbatim from `MIPAY_SPEC.md` — **update the spec §4.3/§4.4 in the same commit** (check FEATURES.md too).
- Egyptian-first currency rule: bare جنيه/geneh/pound → EGP; keep the full existing dialect map (ريال→SAR etc.) so other dialects still work.
- Category synonyms for the new keys: قهوة/كافيه → coffee; كارت شحن/فودافون/نت/باقة → internet_mobile; نتفليكس/جيم/اشتراك → subscriptions; مصاريف البيت/لماما → household; درس/سنتر → tuition; هدوم/لبس → clothes; جمعية/حوّشت → savings; بعت فلوس لحد → transfer_out; شغل فريلانس → freelance; أسهم/شهادة/دهب → investments.
- Rewrite `FEW_SHOT_EXAMPLES` Egyptian-weighted (7 shots): e.g. «دفعت خمسين جنيه على البقالة من كارفور امبارح», «قبضت المرتب النهارده ١٨ ألف», «شحنت كارت فودافون بخمسة وسبعين جنيه» (exercises new category), keep one Gulf/ريال shot + one English shot + one non-transaction shot.

### 2.4 Dialect date map ([postprocess.py:42-59](backend/app/services/postprocess.py#L42-L59))
Add missing Egyptian forms: `مبارح`, `اول مبارح`, `انهارده/انهاردة` (STT drops ال), `دلوقتي/دلوقتى`, `الاسبوع اللي فات`, `الشهر اللي فات`, `من يومين`, `من اسبوع`.

### 2.5 Tests + eval
- `backend/tests/test_postprocess.py`: cases for the new date words.
- `test_transactions.py`: create with a new key (`coffee`); `test_auth.py`: register without currency → `EGP`.
- Append Egyptian utterances covering new categories to `backend/evaluation/dataset.jsonl`.

## Phase 3 — Flutter Egyptianization

- **[app_ar.arb](mipay_app/lib/l10n/app_ar.arb) full Egyptian rewrite**, friendly app tone: `tapToRecord` → «دوس وسجّل», `transcribing` → «بنكتب اللي قلته…», `extractionFailed` → «معرفناش نستخرج البيانات — دخّلها بنفسك», `errorTokenExpired` → «الجلسة خلصت. سجّل دخولك تاني.», `errorNetwork` → «في مشكلة في النت. اتأكد من الاتصال وجرّب تاني.», `noTransactions` → «لسه مفيش معاملات», `errorMicPermission` → «لازم تسمح للمايك عشان تسجّل.» … Money/finance terms stay formal-neutral where عامية would feel unserious (المبلغ، الرصيد، التاريخ).
- Sync the 17 category label keys with the new DB labels + add 12 new camelCase keys to **both** `app_ar.arb` and `app_en.arb`.
- [category.dart:33-51](mipay_app/lib/features/transactions/models/category.dart#L33-L51): add the 12 new icon names to the `IconData` switch (`local_cafe`, `wifi`, `subscriptions`, `family_restroom`, `menu_book`, `checkroom`, `pets`, `shield`, `savings`, `arrow_upward`, `laptop_mac`, `trending_up`).
- **EGP-first everywhere in the app**: `auth_controller.dart:78` + `auth_repository.dart` default `'SAR'` → `'EGP'`; `register_screen.dart` currency list reordered EGP-first, default EGP; `transaction_form.dart` fallback → EGP; `settings_screen.dart` hint/fallback.
- **Dashboard label fix**: `dashboard_screen.dart:297` shows raw category keys — look up `categoriesProvider` and render `category.labelFor(locale)` + icon so the Egyptian labels actually appear.

## Phase 4 — Monochrome design system + theme toggle

New/changed files under `mipay_app/lib/core/theme/`:

- **`app_colors.dart`** (new) — ink ramp `ink0 #FFFFFF … ink950 #0B0B0D` (zinc-like neutrals) + desaturated semantic hues: income `#1E7F4F`/dark `#7BD8A5`, expense `#B4372F`/dark `#F09A93`, warning amber pair. Monochrome plus a whisper of meaning.
- **`app_semantic_colors.dart`** (new) — `AppSemanticColors extends ThemeExtension` with `income, expense, warning, warningContainer, onWarningContainer, chartPalette` + `context.semantics` accessor. **No more `Colors.*` anywhere.**
- **`app_spacing.dart`** (new) — spacing (4/8/12/16/24/32) and radius (card 16, field 12) tokens.
- **`app_theme.dart`** (rewrite) — hand-built `ColorScheme` (not `fromSeed`):
  - Light: surface white, `primary = ink900` (near-black); Dark: surface `ink950`, `primary = ink50` (near-white). **The accent is inversion** — filled buttons, mic button, selected nav = solid near-black on light / near-white on dark. Green/red appear only on amounts via the ThemeExtension.
  - Custom `TextTheme`: w700 headlines, tabular figures for amounts.
  - Component themes so screens need zero local styling: Card (elev 0, radius 16, outline border), filled InputDecoration (radius 12), FilledButton (52px), NavigationBar (inverted indicator), floating SnackBar, AppBar (no scroll tint), SegmentedButton, Divider.
- **Theme toggle**: add `shared_preferences` dep; new `core/providers/theme_mode_provider.dart` (StateNotifier, matching repo style), prefs loaded before `runApp` via ProviderScope override (no flash); `app.dart` → `themeMode: ref.watch(themeModeProvider)`; Settings gains an "Appearance" section with `SegmentedButton<ThemeMode>` (system/light/dark) + ARB keys («زي الجهاز» / «فاتح» / «غامق»). Local pref (not server) — theme is device-specific and must apply on the login screen pre-auth.
- **Chart strategy for 29 categories**: donut shows **top 7 + aggregated "Other"**; 8-step grayscale ramp (lightness is the distinguishing channel, per-mode ramps); legend rows carry icon + label + amount so color never carries meaning alone.
- **Purge hardcoded colors**: `dashboard_screen.dart:12-23` palette + `:118-135` stat cards, `transaction_tile.dart:28`, `transaction_form.dart:169-178` amber banner + `:105`, red SnackBars in `login_screen.dart:45` / `register_screen.dart:53` / `home_screen.dart:75`, `transactions_screen.dart:218` → all via `context.semantics` / `colorScheme`.

## Phase 5 — Screen polish

- **Login/Register**: flat surface, "MiPay" wordmark, filled fields, full-width 52px ink button, generous whitespace.
- **Home/mic**: mic = hero, 88px solid-ink circle, recolored pulse; status text in `onSurfaceVariant`; typed-input as outlined pill.
- **Transactions**: themed FilterChips (selected = inverted ink); tiles with `surfaceContainerHighest` icon avatars; amounts right-aligned, tabular figures, **+/− sign + w700 weight as the primary income/expense signal** (hue secondary); real empty state with CTA.
- **Dashboard**: outlined stat cards, net balance in donut center, localized category rows with icons.
- **Settings**: grouped outlined cards (Profile / Appearance / Language / Account); section headers mono (`onSurfaceVariant`, drop the `primary` tint at `settings_screen.dart:162`).
- **RTL sweep**: grep for `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft`, `TextAlign.left`; wrap amounts in LTR embedding (`\u200E`) so «\u200E-50.00 EGP» doesn't flip in Arabic.

## Verification

**Backend:**
```bash
docker compose up -d postgres ollama api
docker compose exec api alembic upgrade head   # applies 0003
docker compose exec api pytest -v
```
- `SELECT key, label_ar FROM categories ORDER BY sort_order` → 29 rows, Egyptian labels, `other` last; `users.default_currency` default `EGP`, SAR rows flipped.
- Register via curl without currency → `"default_currency":"EGP"`.
- Extraction: «شحنت كارت فودافون بخمسة وسبعين جنيه امبارح» → `internet_mobile / 75 / EGP / date=yesterday`; a ريال sentence still → SAR. Run `backend/evaluation/run_extraction_eval.py`.

**Flutter:** `flutter pub get && flutter gen-l10n && flutter analyze && flutter run`
1. **Leak test (critical)**: login as A → open Transactions + Dashboard → logout → login as B → must show loading then B's data, never a flash of A's; also test session-expiry and register paths; filters reset.
2. **Arabic**: switch to العربية → Egyptian strings everywhere, new categories with icons in the form, dashboard shows Arabic labels not raw keys.
3. **Theme**: toggle dark/light/system in Settings, kill + relaunch → persists; both modes checked on every screen — no blue, no `Colors.red` snackbars, RTL mirror-checked.

## Notes
- Migration is additive for categories (no transaction backfill needed); SAR→EGP user update is deliberate and documented in the migration docstring.
- Old app versions vs new backend: unknown icons fall back to `more_horiz` — graceful.
- Suggested commit sequence: Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 (each independently reviewable).
