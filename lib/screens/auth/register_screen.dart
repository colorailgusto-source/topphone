import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'terms_screen.dart';

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
  final _telefonoCtrl = TextEditingController();
  final _viaCtrl = TextEditingController();
  final _civicaCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _cittaCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _termini = false;

  Future<void> _loadCittaFromCap(String cap) async {
    if (cap.length != 5) return;
    try {
      final res = await http.get(Uri.parse('https://api.zippopotam.us/it/' + cap));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final places = data['places'] as List;
        if (places.isNotEmpty) {
          final place = places[0];
          setState(() {
            _cittaCtrl.text = place['place name'] ?? '';
            _provinciaCtrl.text = place['state-abbreviation'] ?? '';
          });
        }
      }
    } catch (e) { print('CAP lookup error: ' + e.toString()); }
  }

  Future<void> _register() async {
    if (_nomeCtrl.text.isEmpty || _cognomeCtrl.text.isEmpty || 
        _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty ||
        _telefonoCtrl.text.isEmpty || _viaCtrl.text.isEmpty ||
        _capCtrl.text.isEmpty || _cittaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compila tutti i campi obbligatori'), backgroundColor: Colors.orange));
      return;
    }
    if (!_termini) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi accettare i termini e condizioni'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _loading = true);
    final err = await context.read<AuthService>().register(
      _nomeCtrl.text.trim(), 
      _cognomeCtrl.text.trim(), 
      _emailCtrl.text.trim(), 
      _passCtrl.text,
      telefono: _telefonoCtrl.text.trim(),
      via: _viaCtrl.text.trim(),
      civico: _civicaCtrl.text.trim(),
      cap: _capCtrl.text.trim(),
      citta: _cittaCtrl.text.trim(),
      provincia: _provinciaCtrl.text.trim(),
    );
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
      appBar: AppBar(
        title: const Text('Registrazione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          const Text('DATI PERSONALI', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome *', prefixIcon: Icon(Icons.person_outlined)))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _cognomeCtrl, decoration: const InputDecoration(labelText: 'Cognome *', prefixIcon: Icon(Icons.person_outlined)))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl, obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password *', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoCtrl, 
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: const InputDecoration(labelText: 'Telefono *', prefixIcon: Icon(Icons.phone_outlined), hintText: 'Es. 3331234567'),
          ),
          const SizedBox(height: 24),
          const Text('INDIRIZZO SPEDIZIONE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _viaCtrl, decoration: const InputDecoration(labelText: 'Via *', prefixIcon: Icon(Icons.location_on_outlined)))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _civicaCtrl, decoration: const InputDecoration(labelText: 'N°'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _capCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)], decoration: const InputDecoration(labelText: 'CAP *'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: TextField(controller: _cittaCtrl, decoration: const InputDecoration(labelText: 'Città *'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _provinciaCtrl, inputFormatters: [LengthLimitingTextInputFormatter(2)], decoration: const InputDecoration(labelText: 'Prov.'))),
          ]),
          const SizedBox(height: 24),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Checkbox(
              value: _termini,
              onChanged: (v) => setState(() => _termini = v ?? false),
              activeColor: AppTheme.primary,
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Accetto i '),
                    TextSpan(
                      text: 'Termini e Condizioni',
                      style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()..onTap = () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => const SizedBox(height: 700, child: TermsScreen()),
                      ),
                    ),
                    const TextSpan(text: ' e la '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()..onTap = () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => const SizedBox(height: 700, child: TermsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _loading ? null : _register,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Crea Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 16),
          Center(child: TextButton(onPressed: () => context.go('/login'), child: const Text('Hai già un account? Accedi'))),
        ]),
      ),
    );
  }
}