import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nomeCtrl.text = user?.nome ?? '';
    _cognomeCtrl.text = user?.cognome ?? '';
    // Carica telefono dal DB
    _loadTelefono();
  }

  Future<void> _loadTelefono() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;
    final data = await Supabase.instance.client.from('profili').select('telefono').eq('id', userId).single();
    if (mounted && data['telefono'] != null) {
      _telefonoCtrl.text = data['telefono'];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client.from('profili').update({
        'nome': _nomeCtrl.text.trim(),
        'cognome': _cognomeCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      }).eq('id', userId);
      await context.read<AuthService>().loadUser();
    }
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvato!'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: Color(0x660288D1), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                  const Text('Impostazioni', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ]),
              ),
            ),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                const Text('DATI PERSONALI', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome *', prefixIcon: Icon(Icons.person_outlined)),
                  validator: (v) => v!.trim().isEmpty ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cognomeCtrl,
                  decoration: const InputDecoration(labelText: 'Cognome *', prefixIcon: Icon(Icons.person_outlined)),
                  validator: (v) => v!.trim().isEmpty ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(
                    labelText: 'Numero di Telefono *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Es. 3331234567',
                    helperText: 'Usato per contattarti su WhatsApp',
                  ),
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Campo obbligatorio';
                    if (v.trim().length < 9) return 'Numero non valido';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salva Modifiche'),
                )),
              ]),
            ),
          )),
        ]),
      ),
    );
  }
}
