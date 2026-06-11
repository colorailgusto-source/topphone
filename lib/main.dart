import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await NotificationService.initialize();
  runApp(const TopPhoneApp());
}

class TopPhoneApp extends StatefulWidget {
  const TopPhoneApp({super.key});
  @override
  State<TopPhoneApp> createState() => _TopPhoneAppState();
}

class _TopPhoneAppState extends State<TopPhoneApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go('/reset-password');
      }
    });
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'topphone' && uri.host == 'payment-success') {
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_righe');
        await prefs.remove('pending_note');
        await prefs.remove('pending_tipo');
        await prefs.remove('pending_total');
        await prefs.setBool('from_stripe', true);
        await Supabase.instance.client
            .from('carrelli')
            .delete()
            .eq('utente_id', userId);
        Future.delayed(const Duration(milliseconds: 800),
            () => AppRouter.router.go('/order-success'));
      } else if (uri.scheme == 'topphone' && uri.host == 'reset-password') {
        AppRouter.router.go('/reset-password');
      } else if (uri.scheme == 'topphone' && uri.host == 'payment-cancel') {
        AppRouter.router.go('/cart');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (ctx) {
          final cart = CartService();
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
            if (data.session != null) cart.loadFromDb();
            else cart.clear();
          });
          return cart;
        }),
      ],
      child: MaterialApp.router(
        title: 'TopPhone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
