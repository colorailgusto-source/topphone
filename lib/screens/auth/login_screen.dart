import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    setState(() => _loading = true);
    final err = await context.read<AuthService>().login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      String msg = 'Errore di accesso. Riprova.';
      if (err.toString().contains('invalid_credentials') || err.toString().contains('Invalid login')) {
        msg = 'Email o password errati. Riprova.';
      } else if (err.toString().contains('email')) {
        msg = 'Email non valida.';
      } else if (err.toString().contains('network')) {
        msg = 'Errore di connessione. Controlla la rete.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } else {
      final isAdmin = context.read<AuthService>().isAdmin;
      context.go(isAdmin ? '/admin' : '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 150, height: 150,
                decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(8),
                child: Image.asset("assets/images/logo.png", fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              const Text('Top Phone Torre', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Accedi al tuo account', style: TextStyle(color: AppTheme.grey)),
              const SizedBox(height: 40),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl, obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _showResetDialog(), child: const Text('Password dimenticata?'))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Accedi', style: TextStyle(fontSize: 16)),
                )),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Non hai un account? '),
                TextButton(onPressed: () => context.go('/register'), child: const Text('Registrati')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  int _resetCooldown = 0;

  void _showResetDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Email')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        ElevatedButton(onPressed: () async {
          await context.read<AuthService>().resetPassword(ctrl.text.trim());
          if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email inviata!'))); }
        }, child: const Text('Invia')),
      ],
    ));
  }
}
