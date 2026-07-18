import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'firebase_options_web.dart';
import 'theme/app_theme.dart';
import 'widgets/web_install_banner.dart';
import 'utils/auth_cleanup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carica variabili d'ambiente da .env (dev) o --dart-define (build)
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('ENV caricato');
  } catch (e) {
    debugPrint('File .env non trovato, uso dart-define');
  }

  // Inizializza Sentry (se DSN configurato)
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN').isNotEmpty
      ? const String.fromEnvironment('SENTRY_DSN')
      : (dotenv.isInitialized ? (dotenv.env['SENTRY_DSN'] ?? '') : '');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = 1.0;
        options.enableAutoSessionTracking = true;
        options.debug = !kReleaseMode;

        options.beforeSend = (event, hint) {
          final exceptionsText = event.exceptions
                  ?.map((exception) => '${exception.type} ${exception.value}')
                  .join(' ') ??
              '';

          final errorText = [
            event.throwable?.toString() ?? '',
            event.message?.formatted ?? '',
            exceptionsText,
          ].join(' ');

          if (AuthCleanup.isInvalidRefreshTokenText(errorText)) {
            debugPrint('Sentry ignored Supabase invalid refresh token');
            return null;
          }

          return event;
        };
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

  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          File('${dir.path}/recovery_pending').createSync();
        }

        AppRouter.router.go('/reset-password');
      }
    });
  }

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
