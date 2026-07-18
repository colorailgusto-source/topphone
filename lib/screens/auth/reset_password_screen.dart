import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_cleanup.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _passwordChanged = false;

  Future<void> _removeRecoveryFlag() async {
    if (kIsWeb) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recovery_pending');
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('remove recovery flag error: $e');
    }
  }

  Future<void> _save() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Le password non coincidono!'),
          backgroundColor: Colors.red));
      return;
    }

    if (_passCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La password deve essere di almeno 6 caratteri!'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _passCtrl.text));

      _passwordChanged = true;

      await _removeRecoveryFlag();

      if (mounted) {
        await AuthCleanup.safeSignOut(reason: 'password_changed');

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Password aggiornata! Accedi con la nuova password.'),
            backgroundColor: Colors.green));

        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Errore durante il cambio password';

        if (e.toString().contains('different from the old password')) {
          msg = 'La nuova password deve essere diversa da quella precedente';
        }

        if (e.toString().contains('weak')) {
          msg = 'Password troppo debole, usa almeno 8 caratteri';
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    if (!_passwordChanged) {
      AuthCleanup.safeSignOut(reason: 'reset_password_dispose').catchError((e) {
        debugPrint('Ignored signOut error in dispose: $e');
      });
    }

    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!_passwordChanged) {
          await AuthCleanup.safeSignOut(reason: 'reset_password_back');
        }

        if (mounted) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10)
                    ]),
                padding: const EdgeInsets.all(8),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 24),
              const Text('Nuova Password',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Inserisci la tua nuova password',
                  style: TextStyle(color: AppTheme.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Nuova Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                      icon: Icon(
                          _obscure1 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure1 = !_obscure1)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Conferma Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                      icon: Icon(
                          _obscure2 ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure2 = !_obscure2)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Salva Nuova Password'),
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
