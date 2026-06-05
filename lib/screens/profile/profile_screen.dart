import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/390813417717?text=Ciao%20Top%20Phone%20Torre%2C%20ho%20bisogno%20di%20assistenza');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final uri2 = Uri.parse('https://wa.me/390813417717');
      await launchUrl(uri2, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse('https://maps.google.com/?q=Via+Nazionale+68+Torre+del+Greco+NA');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone() async {
    final uri = Uri.parse('tel:0813417717');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final nome = user?.nome ?? '';
    final cognome = user?.cognome ?? '';
    final iniziale = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                child: Column(children: [
                  const Align(alignment: Alignment.centerLeft,
                    child: Text('Profilo', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Text(iniziale, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Text('$nome $cognome'.trim().isEmpty ? 'Utente' : '$nome $cognome',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
                  Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const SizedBox(height: 8),
              _section('Il Mio Account', [
                _tile(Icons.receipt_long_rounded, 'I Miei Ordini', 'Storico acquisti', AppTheme.primary, () => context.push('/orders')),
                _divider(),
                _tile(Icons.location_on_rounded, 'I Miei Indirizzi', 'Gestisci indirizzi', Colors.orange, () => context.push('/addresses')),
                _divider(),
                _tile(Icons.settings_rounded, 'Impostazioni', 'Modifica profilo', Colors.purple, () => context.push('/settings')),
              ]),
              const SizedBox(height: 16),
              _section('Supporto & Contatti', [
                _tileAction(
                  Icons.chat_rounded, 'Assistenza WhatsApp', 'Scrivici ora su WhatsApp',
                  const Color(0xFF25D366),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Chat', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  onTap: _openWhatsApp,
                ),
                _divider(),
                _tileAction(Icons.phone_rounded, 'Chiama il Negozio', '081 341 7717', Colors.blue, onTap: _callPhone),
                _divider(),
                _tileAction(Icons.location_on_rounded, 'Come Raggiungerci', 'Via Nazionale 68, Torre del Greco', Colors.teal, onTap: _openMaps),
              ]),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  ),
                  title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontFamily: 'Poppins')),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () async {
                    await context.read<AuthService>().logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text('Top Phone Torre', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontFamily: 'Poppins')),
              const Text('Via Nazionale 68 • Torre del Greco • 081 341 7717', style: TextStyle(color: AppTheme.grey, fontSize: 11, fontFamily: 'Poppins')),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey, fontFamily: 'Poppins')),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
        ),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _divider() => const Divider(height: 1, indent: 70);

  Widget _tile(IconData icon, String label, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.grey, fontFamily: 'Poppins')),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.grey, size: 18),
      onTap: onTap,
    );
  }

  Widget _tileAction(IconData icon, String label, String subtitle, Color color, {required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins', fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.grey, fontFamily: 'Poppins')),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.grey, size: 18),
      onTap: onTap,
    );
  }
}
