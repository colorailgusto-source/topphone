import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'firebase_options_web.dart';
import 'theme/app_theme.dart';
import 'widgets/web_install_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica variabili d'ambiente da .env (dev) o --dart-define (build)
  await dotenv.load(fileName: '.env').catchError((_) {
    debugPrint('File .env non trovato, uso variabili d\'ambiente di sistema');
  });

  // Inizializza Sentry (se DSN configurato)
  final sentryDsn = dotenv.env['SENTRY_DSN'];
  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = 1.0;
        // options.profilesSampleRate = 1.0; // experimental, commented to avoid warning
        options.enableAutoSessionTracking = true;
        options.debug = !kReleaseMode;
      },
      appRunner: () async {
        await _initializeApp();
        runApp(const TopPhoneApp());
      },
    );
  } else {
    await _initializeApp();
    runApp(const TopPhoneApp());
  }
}

Future<void> _initializeApp() async {
  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseOptionsWeb);
  } else {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  if (!kIsWeb) {
    await NotificationService.initialize();
  }
}

class TopPhoneApp extends StatefulWidget {
  const TopPhoneApp({super.key});

  @override
  State<TopPhoneApp> createState() => _TopPhoneAppState();
}

class _TopPhoneAppState extends State<TopPhoneApp> {
  bool _showBanner = true;

  void _onBannerDismissed() {
    setState(() => _showBanner = false);
  }

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
                final isDesktop = constraints.maxWidth > 600;
                final webChild = Column(
                  children: [
                    if (_showBanner)
                      WebInstallBanner(onDismissed: _onBannerDismissed),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                );

                if (isDesktop) {
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
                        child: webChild,
                      ),
                    ),
                  );
                }
                return webChild;
              },
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
