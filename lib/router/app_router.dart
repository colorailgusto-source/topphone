import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/catalog/product_detail_screen.dart';
import '../screens/catalog/ai_assistant_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_success_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/address_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/cashback_screen.dart';
import '../screens/info/faq_screen.dart';
import '../screens/info/legal_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/admin_guard.dart';
import '../screens/order_chat_screen.dart';
import '../screens/admin_order_chat_screen.dart';
import '../screens/admin/admin_analytics_screen.dart';
import '../screens/admin/admin_resi_screen.dart';
import '../screens/catalog/compare_screen.dart';

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isGuestRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/faq' ||
          state.matchedLocation == '/legal' ||
          state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/catalog') ||
          state.matchedLocation.startsWith('/product') ||
          state.matchedLocation.startsWith('/compare');
      if (!isAuth &&
          !isAuthRoute &&
          !isGuestRoute &&
          state.matchedLocation != '/splash') {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/faq', builder: (c, s) => const FaqScreen()),
      GoRoute(path: '/legal', builder: (c, s) => const LegalScreen()),
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (c, s) => const ResetPasswordScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
          path: '/home',
          builder: (c, s) =>
              const MainScaffold(currentPath: '/home', child: HomeScreen())),
      GoRoute(
          path: '/catalog',
          builder: (c, s) => MainScaffold(
              currentPath: '/catalog',
              child: CatalogScreen(categoriaIniziale: s.extra as String?))),
      GoRoute(
          path: '/ai-assistant',
          builder: (c, s) => const MainScaffold(
              currentPath: '/ai-assistant', child: AiAssistantScreen())),
      GoRoute(
          path: '/product/:id',
          builder: (c, s) {
            final extra = s.extra;
            String? ram;
            String? mem;
            if (extra is Map) {
              ram = extra['ram'] as String?;
              mem = extra['mem'] as String?;
            } else if (extra is String) {
              ram = extra;
            }
            return ProductDetailScreen(
                productId: s.pathParameters['id']!,
                selectedRam: ram,
                selectedMemoria: mem);
          }),
      GoRoute(
          path: '/cart',
          builder: (c, s) =>
              const MainScaffold(currentPath: '/cart', child: CartScreen())),
      GoRoute(
          path: '/orders',
          builder: (c, s) => const MainScaffold(
              currentPath: '/orders', child: OrdersScreen())),
      GoRoute(
          path: '/order-success',
          builder: (c, s) => const OrderSuccessScreen()),
      GoRoute(
          path: '/profile',
          builder: (c, s) => const MainScaffold(
              currentPath: '/profile', child: ProfileScreen())),
      GoRoute(path: '/addresses', builder: (c, s) => const AddressScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/cashback', builder: (c, s) => const CashbackScreen()),
      GoRoute(
          path: '/admin',
          builder: (c, s) => const AdminGuard(child: AdminDashboardScreen())),
      GoRoute(
          path: '/admin/analytics',
          builder: (c, s) => const AdminGuard(child: AdminAnalyticsScreen())),
      GoRoute(
          path: '/admin/resi',
          builder: (c, s) => const AdminGuard(child: AdminResiScreen())),
      GoRoute(
          path: '/order-chat/:ordineId',
          builder: (c, s) => OrderChatScreen(
              ordineId: s.pathParameters['ordineId']!,
              ordineCreatoAt: DateTime.now())),
      GoRoute(
          path: '/admin/order-chat/:ordineId',
          builder: (c, s) =>
              AdminOrderChatScreen(ordineId: s.pathParameters['ordineId']!)),
      GoRoute(
          path: '/compare/:id',
          builder: (c, s) {
            final extra = s.extra as Map?;
            return CompareScreen(
                productId1: s.pathParameters['id']!,
                ram1: extra?['ram'],
                memoria1: extra?['memoria']);
          }),
    ],
  );
}
