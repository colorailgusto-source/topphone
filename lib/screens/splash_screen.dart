import '../services/notification_service.dart';
import '../config/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
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
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _logoController.forward().then((_) => _textController.forward());
    Future.delayed(const Duration(seconds: 3), _init);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }
  Future<void> _checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final config = await Supabase.instance.client.from('app_config').select().eq('id', 'config').single();
      final minVersion = config['versione_minima'] ?? '1.0.0';
      final urlAggiornamento = config['url_aggiornamento'] ?? '';
      final messaggio = config['messaggio_aggiornamento'] ?? 'Aggiorna l app per continuare.';
      
      // Confronta versioni
      final current = currentVersion.split('.').map(int.parse).toList();
      final min = minVersion.split('.').map(int.parse).toList();
      
      bool needsUpdate = false;
      for (int i = 0; i < 3; i++) {
        final c = i < current.length ? current[i] : 0;
        final m = i < min.length ? min[i] : 0;
        if (c < m) { needsUpdate = true; break; }
        if (c > m) break;
      }
      
      // Check aggiornamento PRIMA di manutenzione
      if (needsUpdate && mounted) {
        _needsUpdate = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.system_update, color: Color(0xFF0288D1)),
                SizedBox(width: 8),
                Text('Aggiornamento', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              content: Text(messaggio),
              actions: [
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () async {
                    if (urlAggiornamento.isNotEmpty) {
                      await launchUrl(Uri.parse(urlAggiornamento), mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Aggiorna Ora'),
                )),
              ],
            ),
          ),
        );
        return;
      }

      // Check manutenzione
    final manutenzione = config['manutenzione'] ?? false;
    final messaggioManutenzione = config['messaggio_manutenzione'] ?? 'App in manutenzione. Torneremo presto!';
    if (manutenzione && mounted) {
      // Controlla se è admin
      final session = Supabase.instance.client.auth.currentSession;
      bool isAdmin = false;
      if (session != null) {
        final profilo = await Supabase.instance.client.from('profili').select('ruolo').eq('id', session.user.id).maybeSingle();
        isAdmin = profilo?['ruolo'] == 'admin';
      }
      if (!isAdmin) {
        _needsUpdate = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [
                Icon(Icons.construction, color: Colors.orange),
                SizedBox(width: 8),
                Text('Manutenzione', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              content: Text(messaggioManutenzione),
            ),
          ),
        );
        return;
      }
    }


    } catch (e) {
    }
  }

  bool _needsUpdate = false;

  Future<void> _init() async {
    await _checkUpdate();
    if (_needsUpdate) return;
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await context.read<AuthService>().loadUser();
      await NotificationService.refreshToken();
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
        title: const Text('Scegli modalità', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Come vuoi accedere?'),
        actions: [
          OutlinedButton.icon(icon: const Icon(Icons.person), label: const Text('Cliente'), onPressed: () { Navigator.pop(ctx); context.go('/home'); }),
          ElevatedButton.icon(icon: const Icon(Icons.admin_panel_settings), label: const Text('Admin'), onPressed: () { Navigator.pop(ctx); context.go('/admin'); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
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
                    width: 150, height: 150,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(children: [
                    const Text('TOP PHONE', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 4, fontFamily: 'Poppins')),
                    const Text('TORRE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white70, letterSpacing: 8, fontFamily: 'Poppins')),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Telefoni & Accessori', style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 1, fontFamily: 'Poppins')),
                    ),
                  ]),
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(children: [
                  const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 3)),
                  const SizedBox(height: 16),
                  Text(AppConfig.shopStreet + ', ' + AppConfig.shopCity, style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Poppins')),
                  const Text('081 341 7717', style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Poppins')),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
