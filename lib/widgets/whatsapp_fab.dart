import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppFab extends StatelessWidget {
  final String? messaggioPersonalizzato;
  const WhatsAppFab({super.key, this.messaggioPersonalizzato});

  Future<void> _apri() async {
    final testo = messaggioPersonalizzato ?? 'Ciao Top Phone Torre, ho bisogno di assistenza';
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
    return FloatingActionButton(
      onPressed: _apri,
      backgroundColor: const Color(0xFF25D366),
      child: const Icon(Icons.chat, color: Colors.white, size: 28),
    );
  }
}
