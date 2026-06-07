import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/order_service.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Stripe.publishableKey = 'pk_test_51S3PnZ2HVMlh4j78UQRBj4UW759TjIzV2icwrFrO08hZqbGqP4wk6rtW4bmk7ovW0lLpI3dRwyspaYoiX65FFq8C00K7WBwa0T';
  await Supabase.initialize(
    url: 'https://ehjcqxjspwedqihjjkjf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoamNxeGpzcHdlZHFpaGpqa2pmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1OTAwMjMsImV4cCI6MjA5NjE2NjAyM30.XLebw0DH33-HFhkPOwnBg7v06sBTl_uQ6uistj5Sg6s',
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
    // Gestisci deep link globalmente
    // Ascolta deep links
    // Ascolta cambio stato auth per recovery password
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        AppRouter.router.go('/reset-password');
      }
    });
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'topphone' && uri.host == 'payment-success') {
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        // Ordine creato dal webhook Stripe - qui solo pulizia carrello e navigazione
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_righe');
        await prefs.remove('pending_note');
        await prefs.remove('pending_tipo');
        await prefs.remove('pending_total');
        await Supabase.instance.client.from('carrelli').delete().eq('utente_id', userId);
        Future.delayed(const Duration(milliseconds: 800), () => AppRouter.router.go('/order-success'));

      } else if (uri.scheme == 'topphone' && uri.host == 'reset-password') {
        AppRouter.router.go('/reset-password');
      } else if (uri.scheme == 'topphone' && uri.host == 'payment-cancel') {
        // Nessun ordine da annullare - non era stato creato
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
