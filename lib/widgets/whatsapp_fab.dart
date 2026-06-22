import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppFab extends StatefulWidget {
  final String? messaggioPersonalizzato;
  const WhatsAppFab({super.key, this.messaggioPersonalizzato});
  @override
  State<WhatsAppFab> createState() => _WhatsAppFabState();
}

class _WhatsAppFabState extends State<WhatsAppFab> {
  bool _espanso = false;

  @override
  void initState() {
    super.initState();
    _avviaCiclo();
  }

  void _avviaCiclo() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _espanso = true);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _espanso = false);
    await Future.delayed(const Duration(seconds: 18));
    if (!mounted) return;
    _avviaCiclo();
  }

  Future<void> _apri() async {
    final testo = widget.messaggioPersonalizzato ?? 'Ciao Top Phone Torre, ho bisogno di assistenza';
    final uri = Uri.parse('https://wa.me/390813417717?text=' + Uri.encodeComponent(testo));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final uri2 = Uri.parse('https://wa.me/390813417717');
      await launchUrl(uri2, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _apri,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: _espanso ? 18 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 28),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _espanso
                ? const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Text('Scrivici su WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  )
                : const SizedBox(width: 0),
            ),
          ],
        ),
      ),
    );
  }
}
