import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banner persistente solo-web "Installa l'app".
/// Legge `url_aggiornamento` da `app_config` (id='config') a runtime: se l'admin
/// cambia il valore nel DB, il web lo prende al prossimo caricamento SENZA rebuild.
/// Include un pulsante per chiudere definitivamente il banner (salvato in localStorage).
class WebInstallBanner extends StatefulWidget {
  final VoidCallback? onDismissed;

  const WebInstallBanner({super.key, this.onDismissed});

  @override
  State<WebInstallBanner> createState() => _WebInstallBannerState();
}

class _WebInstallBannerState extends State<WebInstallBanner>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _url;
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;
  bool _pressed = false;
  bool _dismissed = false;

  static const _dismissedKey = 'web_install_banner_dismissed';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnim = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Controlla se l'utente ha già chiuso il banner
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_dismissedKey) ?? false;

    if (dismissed) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('app_config')
          .select('url_aggiornamento')
          .eq('id', 'config')
          .maybeSingle();
      final url = (data?['url_aggiornamento'] as String?)?.trim() ?? '';
      if (mounted) {
        setState(() {
          _url = url.isNotEmpty ? url : null;
          _loading = false;
        });
        if (_url != null) _ctrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (mounted) {
      setState(() => _dismissed = true);
      _ctrl.reverse().then((_) {
        widget.onDismissed?.call();
      });
    }
  }

  Future<void> _open() async {
    if (_url == null) return;
    final uri = Uri.tryParse(_url!);
    if (uri == null) return;
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _pressed = false);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _url == null || _dismissed) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: Opacity(
          opacity: _fadeAnim.value,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _open,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.08),
                child: AnimatedScale(
                  scale: _pressed ? 0.98 : 1.0,
                  duration: const Duration(milliseconds: 80),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.android_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Installa l\'app TopPhone',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                                height: 1.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Scarica l\'APK ufficiale',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                letterSpacing: 0.3,
                                height: 1.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Scarica',
                          style: TextStyle(
                            color: Color(0xFF0D47A1),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            letterSpacing: 0.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _dismiss,
                          borderRadius: BorderRadius.circular(20),
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
