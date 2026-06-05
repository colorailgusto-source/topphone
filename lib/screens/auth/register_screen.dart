import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _register() async {
    if (_nomeCtrl.text.isEmpty || _cognomeCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compila tutti i campi'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthService>().register(_nomeCtrl.text.trim(), _cognomeCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $err'), backgroundColor: Colors.red));
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Registrazione'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 20),
          TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outlined))),
          const SizedBox(height: 16),
          TextField(controller: _cognomeCtrl, decoration: const InputDecoration(labelText: 'Cognome', prefixIcon: Icon(Icons.person_outlined))),
          const SizedBox(height: 16),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl, obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Registrati', style: TextStyle(fontSize: 16)),
            )),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Hai già un account? '),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Accedi')),
          ]),
        ]),
      ),
    );
  }
}
