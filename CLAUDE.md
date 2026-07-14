# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**TopPhone** — Flutter e-commerce app for a smartphone shop (catalog, cart, orders, admin dashboard, customer/admin order chat). Ships as **Android APK** and as a **web app on Vercel** from the same codebase. Platform behavior is switched at runtime with `kIsWeb` (see `lib/main.dart`).

Backend is **Supabase** (Postgres + Auth + Realtime + Storage + Edge Functions). Payments use **Stripe** via a server-side checkout Edge Function. Push notifications use **Firebase Cloud Messaging** (mobile only). Routing is **go_router**; app state is **Provider**.

## Common commands

```bash
# Static analysis (repo has ~970 findings, mostly style `info` + a few real warnings)
flutter analyze

# Tests
flutter test                      # all tests in test/
flutter test test/cart_service_test.dart   # single file

# Dev
flutter run                      # device/emulator
flutter run -d chrome            # web dev

# Production builds
flutter build apk --release      # -> build/app/outputs/flutter-apk/app-release.apk
flutter build web --release      # -> build/web/

# Clean
flutter clean
```

Vercel deploy (web output is a static site; `build/web/vercel.json` has SPA rewrites):
```bash
vercel deploy --prod --token=<TOKEN> build/web
```
Account: `xboxtrio99-sudo`, project: `topphoneweb`.

## Architecture

### Entry point & platform branching — `lib/main.dart`
- Initializes `Firebase` (web uses `firebaseOptionsWeb`, mobile uses default), `Supabase.initialize` (creds from `AppConfig`), and `NotificationService` (mobile only).
- Wraps the app in `MultiProvider` with **`AuthService`** and **`CartService`** at the root; everything else reads them via `context.read/watch`.
- `MaterialApp.router` uses the singleton `AppRouter.router`.
- Web-only: a `LayoutBuilder` centers content in a 430px phone-frame for viewports > 600px. Deep-link handling and notifications are gated behind `!kIsWeb`.

### Routing — `lib/router/app_router.dart`
- Single exported singleton `AppRouter.router` (go_router). Do **not** create new GoRouter instances; add routes here.
- `redirect` enforces auth: unauthenticated users hitting a non-guest/non-auth route go to `/login`. Guest-allowed routes: `/welcome`, `/faq`, `/legal`, `/home`, `/catalog`, `/product`, `/compare`.
- Customer routes are wrapped in **`MainScaffold`** (bottom navigation). Admin routes are wrapped in **`AdminGuard`**.
- `initialLocation` is `/splash`.

### State — Provider (`lib/services/`)
- `AuthService` (ChangeNotifier): current `UserModel`, `isAdmin`, login/register/logout/resetPassword, `loadUser()`.
- `CartService` (ChangeNotifier): cart contents.
- Other services (`OrderService`, `ProductService`, `PointsService`, `NotificationService`, `StripeService`) are **plain classes**, not providers — instantiate them directly; they expose static methods where stateless (e.g. `NotificationService.notificaNuovoOrdine`).
- `AuthService` is the source of truth for role; `AdminGuard` independently re-checks `profili.ruolo == 'admin'` on every app resume (WidgetsBindingObserver) and redirects non-admins to `/home`.

### Data layer — Supabase
- Services query Supabase directly: `_client.from('tabella').select(...).eq(...)`. Table names are Italian (`ordini`, `prodotti`, `profili`, `righe_ordine`, `carrelli`, `indirizzi`, `categorie`, `varianti`).
- **Custom Postgres RPCs** are called via `_client.rpc(...)`: `annulla_ordine`, `assegna_punto_cashback`, `marca_abbandoni_recuperati`, `admin_reset_dati_transazionali`. When adding RPC calls, the function must exist in `supabase/migrations`.
- **Supabase Edge Functions** are invoked via `_client.functions.invoke(...)` or HTTP POST to `AppConfig.functionsBaseUrl`: `create-checkout-session` (Stripe), `send-notification`, `send-order-email`, `notifica-admin-ordine`. Function source lives in `supabase/functions` — implement backend logic there, not in Dart.
- DB schema and RLS are defined in `supabase/migrations` (SQL).

### Models — `lib/models/`
Plain classes with `fromJson` factories: `UserModel`, `OrderModel`, `ProductModel`, `VariantModel`, `CartItemModel`. Note the Italian-to-Dart key mapping (e.g. `json['tipo_consegna']` → `tipoConsegna`).

**Order status** is a string state machine (no enum): `ricevuto` → `confermato` → (`spedito` | `pronto_ritiro`) → `consegnato`, plus `annullato` and `reso_richiesto`/`reso_approvato`/`reso_rifiutato`. Status options depend on `tipo_consegna` (`spedizione` vs `ritiro`) — see `AdminOrdersScreen._getStati`.

### Payments — `lib/services/stripe_service.dart`
- Uses **conditional import** to split platforms: `stripe_mobile_helper.dart` (mobile) vs `stripe_web_helper.dart` (web, selected via `if (dart.library.html)`).
- `StripeService.openPaymentSheet` posts to the `create-checkout-session` Edge Function with the user's Supabase access token; returns `'paid'` | `'cancelled'` | `'redirected'`. Klarna/Scalapay produce a `checkoutUrl` → web redirect (payment not yet confirmed).

### Admin — `lib/screens/admin/`
`AdminDashboardScreen` is a 5-tab bottom-nav (home/stats, products, orders, customers, stats). Management cards push other admin screens (`AdminProductsScreen`, `AdminOrdersScreen`, `AdminCustomersScreen`, `AdminStatsScreen`, `AdminBannersScreen`, `AdminCategoriesScreen`, `AdminAppConfigScreen`, `AdminAnalyticsScreen`, `AdminResiScreen`, `AdminPaymentRequestsScreen`). All reachable only through `AdminGuard`.

### Notifications & deep links
- `NotificationService` (mobile) wires FCM via `firebase_messaging` + `flutter_local_notifications`; broadcasts use the `send-notification` Edge Function.
- `DeepLinkService` (`lib/services/deep_link/`, platform-split) opens order-chat deep links: `AppRouter.router.go(path)` is called from `main.dart`.

### Web Install Banner — `lib/widgets/web_install_banner.dart`
Persistent web-only banner "Installa l'app TopPhone" shown at the top of the web app.
- Reads `url_aggiornamento` from `app_config` (id='config') at runtime — admin can change the APK download URL in Supabase without a rebuild.
- Includes a **close button (X)** that dismisses the banner with a slide-up/fade-out animation.
- **Persists dismissal** in `shared_preferences` (localStorage on web) — once closed, it never shows again across sessions/reloads.
- Parent (`TopPhoneApp` in `main.dart`) conditionally renders the banner via a `_showBanner` state flag; when dismissed, the parent removes it from the `Column` and the `Expanded` child takes full height.

## Build & deploy specifics (important)

### Android signing
- Keystore: `android/app/topphone.keystore`. Config in `android/key.properties` (`storeFile=topphone.keystore` — resolved relative to `android/app/`). `android/app/build.gradle.kts` `signingConfigs.release` reads these props. `release` build has `minifyEnabled` + `shrinkResources` (R8) enabled.
- `flutter build apk --release` is the command; output is `build/app/outputs/flutter-apk/app-release.apk`.

### `android/build.gradle.kts` build-dir redirect (required for `flutter build apk` to succeed)
The root `build.gradle.kts` redirects Gradle's build output to the Flutter project root so Flutter can find the APK:
```kotlin
val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(newBuildDir)
subprojects {
    project.layout.buildDirectory.set(newBuildDir.dir(project.name))
    project.evaluationDependsOn(":app")
}
```
Using `buildDirectory.dir("../build")` instead of `projectDirectory.dir("../build")` is a **no-op** (stays under `android/build`) and makes `flutter build apk` fail with *"Gradle build failed to produce an .apk file"*. Keep the `projectDirectory` form.

### Web / Vercel
- `flutter build web --release` → `build/web/`. `build/web/vercel.json` rewrites all paths to `index.html` so go_router deep links work.
- Web Firebase config is `lib/firebase_options_web.dart`; web assets include `web/index.html`, `web/firebase-messaging-sw.js`, `web/manifest.json`.

## Gotchas & conventions

- **Secrets in source**: `lib/config/app_config.dart` holds config as Dart `const`s — Supabase URL, **Supabase anon key**, **Stripe LIVE publishable key**, shop details, `functionsBaseUrl`. The anon key is by design client-side (RLS protects data), but the Stripe key is a **live** key and `admin_dashboard_screen.dart` also hardcodes a Supabase JWT bearer token to call functions directly. Do **not** add service-role/secret keys here; rotate the Stripe key if it ever leaks.
- **`.bak` files in `lib/`** (e.g. `lib/screens/admin/admin_products_screen.dart.bak`) are stale copies; they are ignored by `flutter analyze` because of the extension. However, **backup folders at the repo root containing real `.dart` files** (e.g. `backup_admin_payment_ui_*`) ARE analyzed and produce `uri_does_not_exist` errors (broken imports). Keep such folders out of the analyzed tree or delete them.
- **`flutter analyze` noise**: ~970 findings, overwhelmingly style lints (`curly_braces_in_flow_control_structures`, `prefer_interpolation_to_compose_strings`, `prefer_const_constructors`). The few real `warning`s worth fixing: unused imports (`order_service.dart`), unused local variables (`notification_service.dart`), and `avoid_web_libraries_in_flutter` in `browser_redirect_web.dart`.
- **Italian strings & UI**: user-facing copy, DB columns, and many identifiers are Italian. Match existing naming when adding features.
- **`AppTheme`** (`lib/theme/app_theme.dart`) is the single source of colors: `primary`, `primaryDark`, `primaryGradient`, `grey`, `background`, `success`, `textDark`, `textMedium`. Use these, not raw `Colors.*`, in new widgets.

## Background jobs & cron

- **Abandoned cart recovery cron** (`marca_abbandoni_recuperati` RPC) runs on a schedule (configured in Supabase Dashboard → Database → Extensions → pg_cron, or via external scheduler like GitHub Actions / Vercel Cron). It marks pending abandoned carts as "recovered" so the recovery flow doesn't send reminders to users who just placed an order.
- When a new order is created (`OrderService.createOrder`), it calls `marca_abbandoni_recuperati` for the user to immediately suppress any pending recovery reminder.

## Recent changes (2025-07-14)

### Web Install Banner with dismiss
- Added close button (X) to `WebInstallBanner` with slide-up + fade-out animation.
- Dismissal persisted via `shared_preferences` (localStorage on web) — key `web_install_banner_dismissed`.
- Parent `TopPhoneApp` now stateful (`_TopPhoneAppState`) with `_showBanner` flag; callback `onDismissed` sets it to `false`, causing the banner to be removed from the widget tree and the app content to expand full-screen.
- Banner reads `url_aggiornamento` from `app_config` at runtime (no rebuild needed when admin changes the APK URL).

### Supabase `anonKey` → `publishableKey` migration (2025-07-14)
- `supabase_flutter` v2+ deprecated `anonKey` parameter in favor of `publishableKey`.
- **Files updated:**
  - `lib/config/app_config.dart`: constant renamed `supabaseAnonKey` → `supabasePublishableKey`
  - `lib/main.dart`: `Supabase.initialize(anonKey: ...)` → `publishableKey: ...`
  - `lib/main_web.dart`: same parameter rename
  - `lib/screens/catalog/ai_assistant_screen.dart`: Authorization header
  - `lib/screens/admin/admin_products_screen.dart`: 3× Authorization headers
  - `pubspec.yaml`: added `web: ^1.0.0` dependency
  - `lib/services/browser_redirect/browser_redirect_web.dart`: migrated from `dart:html` to `package:web` (fixes `avoid_web_libraries_in_flutter` warning)
- **Cleanup:** removed 20+ stale `.bak` files from `lib/` and `supabase/` root.
- **Fixed real analyze warnings:**
  - `notification_service.dart:77` — removed unused `profilo` variable
  - `orders_screen.dart:939-950` — fixed `dead_null_aware_expression` (removed redundant `?? ''`) + null-safe `split`
- **Verification:** `flutter analyze` → 0 errors, 0 warnings (only pre-existing style infos); `flutter test` → 15/15 pass; `flutter build web --release` ✅; `flutter build apk --release` ✅ (71.2 MB, signed); **Deployed to Vercel** → https://topphoneweb-9qspsiqv1-xboxtrio99-sudos-projects.vercel.app

### Supabase publishableKey migration (2025-07-14)
- **Deprecation fix**: `supabase_flutter` v2+ deprecated `anonKey` parameter in favor of `publishableKey`.
- Files updated:
  - `lib/config/app_config.dart`: constant renamed `supabaseAnonKey` → `supabasePublishableKey`
  - `lib/main.dart`: `Supabase.initialize(publishableKey: ...)`
  - `lib/main_web.dart`: same param change
  - `lib/screens/catalog/ai_assistant_screen.dart`: Authorization header
  - `lib/screens/admin/admin_products_screen.dart`: 3x Authorization headers
- Added `web: ^1.0.0` dependency to `pubspec.yaml` for `package:web` migration.

### Warning fixes & cleanup (2025-07-14)
- **Fixed 3 real `flutter analyze` warnings** (was ~970 findings, now 0 errors/warnings):
  - `lib/services/notification_service.dart:77` — removed unused `profilo` local variable
  - `lib/screens/orders/orders_screen.dart:939-950` — removed dead `?? ''` null-aware expressions, added null-safe `extraInfo!.split(':')` inside guarded block
  - `lib/services/browser_redirect/browser_redirect_web.dart` — migrated `dart:html` → `package:web` (fixes `avoid_web_libraries_in_flutter` + `deprecated_member_use`)
- **Removed 20+ stale `.bak` files** from `lib/`, `lib/screens/`, `lib/services/`, `supabase/functions/` (were polluting repo root, not ignored by analyze)

### Verified builds & deploy
- `flutter analyze` → 0 errors, 0 warnings (45 style `info` only)
- `flutter test` → 15/15 pass
- `flutter build web --release` → `build/web/` (3.6 MB)
- `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (71.2 MB, signed)
- **Deployed to Vercel**: https://topphoneweb-9qspsiqv1-xboxtrio99-sudos-projects.vercel.app