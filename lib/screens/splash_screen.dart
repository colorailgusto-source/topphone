import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/notification_service.dart';
import '../config/app_config.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_cleanup.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/auth_service.dart';
import 'dart:io';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _channel = MethodChannel('com.topphone.topphone/installer');

  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _logoController.forward().then((_) => _textController.forward());
    Future.delayed(const Duration(seconds: 3), _init);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<bool> _canInstall() async {
    try {
      final result = await _channel.invokeMethod<bool>('canInstall');
      return result ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    if (kIsWeb) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final config = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 'config')
          .single();
      final minVersion = config['versione_minima'] ?? '1.0.0';
      final urlAggiornamento = config['url_aggiornamento'] ?? '';
      final messaggio = config['messaggio_aggiornamento'] ??
          'Aggiorna l\'app per continuare.';

      final current = currentVersion.split('.').map(int.parse).toList();
      final min = minVersion.split('.').map(int.parse).toList();

      bool needsUpdate = false;
      for (int i = 0; i < 3; i++) {
        final c = i < current.length ? current[i] : 0;
        final m = i < min.length ? min[i] : 0;
        if (c < m) {
          needsUpdate = true;
          break;
        }
        if (c > m) break;
      }

      if (needsUpdate && mounted) {
        _needsUpdate = true;
        _showUpdateDialog(urlAggiornamento, messaggio);
        return;
      }

      final manutenzione = config['manutenzione'] ?? false;
      final messaggioManutenzione = config['messaggio_manutenzione'] ??
          'App in manutenzione. Torneremo presto!';
      if (manutenzione && mounted) {
        final session = Supabase.instance.client.auth.currentSession;
        bool isAdmin = false;
        if (session != null) {
          final profilo = await Supabase.instance.client
              .from('profili')
              .select('ruolo')
              .eq('id', session.user.id)
              .maybeSingle();
          isAdmin = profilo?['ruolo'] == 'admin';
        }
        if (!isAdmin && mounted) {
          _needsUpdate = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.construction, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Manutenzione',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
                content: Text(messaggioManutenzione),
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("splash check update: $e");
    }
  }

  void _showUpdateDialog(String url, String messaggio) {
    double progress = 0;
    bool downloading = false;
    bool completed = false;
    bool waitingPermission = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> startDownload() async {
              setDialogState(() {
                downloading = true;
                waitingPermission = false;
                error = null;
              });
              try {
                final dir = await getTemporaryDirectory();
                final filePath = '${dir.path}/topphone_update.apk';
                await Dio().download(
                  url,
                  filePath,
                  onReceiveProgress: (received, total) {
                    if (total > 0) {
                      setDialogState(() {
                        progress = received / total;
                      });
                    }
                  },
                );
                setDialogState(() {
                  completed = true;
                  progress = 1.0;
                });
                await Future.delayed(const Duration(milliseconds: 500));
                await OpenFilex.open(filePath);
              } catch (e) {
                setDialogState(() {
                  downloading = false;
                  error = 'Errore download. Riprova.';
                });
                debugPrint('Update download error: $e');
              }
            }

            Future<void> handleUpdateTap() async {
              if (url.isEmpty) return;
              final canInstall = await _canInstall();
              if (!canInstall) {
                await _requestInstallPermission();
                setDialogState(() {
                  waitingPermission = true;
                });
                Timer.periodic(const Duration(milliseconds: 800),
                    (timer) async {
                  final granted = await _canInstall();
                  if (granted) {
                    timer.cancel();
                    startDownload();
                  }
                });
              } else {
                startDownload();
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(
                  completed ? Icons.check_circle : Icons.system_update,
                  color: completed ? Colors.green : const Color(0xFF0288D1),
                ),
                const SizedBox(width: 8),
                Text(
                  completed
                      ? 'Installazione...'
                      : (waitingPermission ? 'Permesso...' : 'Aggiornamento'),
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!downloading &&
                      !completed &&
                      !waitingPermission &&
                      error == null)
                    Text(messaggio),
                  if (waitingPermission && !downloading) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Abilita l\'installazione e torna qui.\nIl download partira automaticamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ],
                  if (downloading || completed) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 14,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completed ? Colors.green : const Color(0xFF0288D1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      completed
                          ? 'Completato! Installazione in corso...'
                          : '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color:
                            completed ? Colors.green : const Color(0xFF0288D1),
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                if (!downloading && !completed && !waitingPermission)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: handleUpdateTap,
                      icon: const Icon(Icons.download),
                      label: const Text('Aggiorna Ora'),
                    ),
                  ),
                if (error != null && !downloading && !waitingPermission)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          error = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _needsUpdate = false;

        Future<void> _init() async {
    await _checkUpdate();
    if (_needsUpdate) return;
    if (!mounted) return;

    // Se c'era un recovery non completato, logout
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final recoveryFile = File('${dir.path}/recovery_pending');
      if (recoveryFile.existsSync()) {
        recoveryFile.deleteSync();
        await AuthCleanup.safeSignOut(reason: 'splash_recovery_pending');
        if (mounted) context.go('/login');
        return;
      }
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await context.read<AuthService>().loadUser();
      if (!kIsWeb) {
        await NotificationService.refreshToken();
      }
      if (!mounted) return;
      if (context.read<AuthService>().isAdmin) {
        _showRoleDialog();
      } else {
        context.go("/home");
      }
    } else {
      if (mounted) context.go("/login");
    }
  }

  void _showRoleDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Scegli modalita',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Come vuoi accedere?'),
        actions: [
          OutlinedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Cliente'),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/home');
              }),
          ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin'),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/admin');
              }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: const Color(0xFF01579B),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF01579B), Color(0xFF0288D1), Color(0xFF29B6F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              const Spacer(flex: 2),
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset('assets/images/logo.png',
                        fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(children: [
                    const Text('TOP PHONE',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 4,
                            fontFamily: 'Poppins')),
                    const Text('TORRE',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: Colors.white70,
                            letterSpacing: 8,
                            fontFamily: 'Poppins')),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Telefoni & Accessori',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 1,
                              fontFamily: 'Poppins')),
                    ),
                  ]),
                ),
              ),
              const Spacer(flex: 2),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Column(children: [
                  SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 3)),
                  SizedBox(height: 16),
                  Text('${AppConfig.shopStreet}, ${AppConfig.shopCity}',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'Poppins')),
                  Text('081 341 7717',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'Poppins')),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

