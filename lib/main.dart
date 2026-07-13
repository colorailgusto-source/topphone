import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'services/deep_link/deep_link_service.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'firebase_options_web.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseOptionsWeb);
  } else {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  runApp(const TopPhoneApp());

  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.init(
        onLink: (path) {
          AppRouter.router.go(path);
        },
      );
    });
  }
}

class TopPhoneApp extends StatelessWidget {
  const TopPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: MaterialApp.router(
        title: 'TopPhone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          if (kIsWeb) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Container(
                    color: const Color(0xFFF0F4F8),
                    child: Center(
                      child: Container(
                        width: 430,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: child,
                      ),
                    ),
                  );
                }
                return child ?? const SizedBox.shrink();
              },
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
