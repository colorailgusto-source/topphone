import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) { if (mounted) setState(() => _loading = false); return; }
    final data = await _client.from('indirizzi').select().eq('utente_id', userId).order('predefinito', ascending: false);
    final addresses = List<Map<String, dynamic>>.from(data);
    
    // Se nessun indirizzo, pre-popola dal profilo
    if (addresses.isEmpty) {
      final profilo = await _client.from('profili').select().eq('id', userId).maybeSingle();
      if (profilo != null && (profilo['via'] ?? '').isNotEmpty) {
        await _client.from('indirizzi').insert({
          'utente_id': userId,
          'nome_destinatario': '${profilo['nome'] ?? ''} ${profilo['cognome'] ?? ''}'.trim(),
          'telefono': profilo['telefono'] ?? '',
          'via': profilo['via'] ?? '',
          'civico': profilo['civico'] ?? '',
          'citta': profilo['citta'] ?? '',
          'cap': profilo['cap'] ?? '',
          'provincia': profilo['provincia'] ?? '',
          'predefinito': true,
        });
        final newData = await _client.from('indirizzi').select().eq('utente_id', userId).order('predefinito', ascending: false);
        if (mounted) setState(() { _addresses = List<Map<String, dynamic>>.from(newData); _loading = false; });
        return;
      }
    }
    if (mounted) setState(() { _addresses = List<Map<String, dynamic>>.from(addresses); _loading = false; });
    } catch (e) {
      print('Errore indirizzi: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFallback() async {
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCittaFromCap(String cap, StateSetter setS, TextEditingController cittaCtrl, TextEditingController provinciaCtrl) async {
    if (cap.length != 5) return;
    try {
      final res = await http.get(Uri.parse('https://api.zippopotam.us/it/' + cap));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final places = data['places'] as List;
        if (places.isNotEmpty) {
          final place = places[0];
          setS(() {
            cittaCtrl.text = place['place name'] ?? '';
            provinciaCtrl.text = place['state-abbreviation'] ?? '';
          });
        }
      }
    } catch (e) { print('CAP error: ' + e.toString()); }
  }

  void _showForm({Map<String, dynamic>? address}) {
    final nomeCtrl = TextEditingController(text: address?['nome_destinatario'] ?? '');
    final telefonoCtrl = TextEditingController(text: address?['telefono'] ?? '');
    final viaCtrl = TextEditingController(text: address?['via'] ?? '');
    final civicoCtrl = TextEditingController(text: address?['civico'] ?? '');
    final cittaCtrl = TextEditingController(text: address?['citta'] ?? '');
    final capCtrl = TextEditingController(text: address?['cap'] ?? '');
    final provinciaCtrl = TextEditingController(text: address?['provincia'] ?? '');
    bool predefinito = address?['predefinito'] ?? false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(address == null ? 'Nuovo Indirizzo' : 'Modifica Indirizzo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome e Cognome *', prefixIcon: Icon(Icons.person_outlined)),
                  validator: (v) => v!.trim().isEmpty ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono *', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => v!.trim().isEmpty ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(flex: 3, child: TextFormField(
                    controller: viaCtrl,
                    decoration: const InputDecoration(labelText: 'Via/Piazza *', prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => v!.trim().isEmpty ? 'Obbligatorio' : null,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: TextFormField(
                    controller: civicoCtrl,
                    decoration: const InputDecoration(labelText: 'N°*'),
                    validator: (v) => v!.trim().isEmpty ? 'N°' : null,
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(flex: 1, child: TextFormField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                    onChanged: (v) => _loadCittaFromCap(v, setS, cittaCtrl, provinciaCtrl),
                    decoration: const InputDecoration(labelText: 'CAP *', hintText: '80059'),
                    validator: (v) => v!.trim().length != 5 ? 'CAP non valido' : null,
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextFormField(
                    controller: cittaCtrl,
                    decoration: const InputDecoration(labelText: 'Città *'),
                    validator: (v) => v!.trim().isEmpty ? 'Obbligatorio' : null,
                  )),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: provinciaCtrl,
                  inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(2)],
                  decoration: const InputDecoration(labelText: 'Provincia (es. NA) *', prefixIcon: Icon(Icons.map_outlined)),
                  validator: (v) => v!.trim().length != 2 ? 'Es: NA' : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Imposta come predefinito', style: TextStyle(fontFamily: 'Poppins')),
                  subtitle: const Text('Usato per default al checkout', style: TextStyle(fontSize: 11)),
                  value: predefinito,
                  onChanged: (v) => setS(() => predefinito = v),
                  activeColor: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final userId = context.read<AuthService>().currentUser?.id;
                    if (userId == null) return;
                    if (predefinito) {
                      await _client.from('indirizzi').update({'predefinito': false}).eq('utente_id', userId);
                    }
                    final indirizzo = '${viaCtrl.text.trim()} ${civicoCtrl.text.trim()}, ${capCtrl.text.trim()} ${cittaCtrl.text.trim()} (${provinciaCtrl.text.trim().toUpperCase()})';
                    final data = {
                      'utente_id': userId,
                      'nome_destinatario': nomeCtrl.text.trim(),
                      'telefono': telefonoCtrl.text.trim(),
                      'via': viaCtrl.text.trim(),
                      'civico': civicoCtrl.text.trim(),
                      'citta': cittaCtrl.text.trim(),
                      'cap': capCtrl.text.trim(),
                      'provincia': provinciaCtrl.text.trim().toUpperCase(),
                      'indirizzo': indirizzo,
                      'predefinito': predefinito,
                    };
                    if (address == null) {
                      await _client.from('indirizzi').insert(data);
                    } else {
                      await _client.from('indirizzi').update(data).eq('id', address['id']);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Text(address == null ? 'Salva Indirizzo' : 'Aggiorna Indirizzo'),
                )),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    );
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
                  const Text('I Miei Indirizzi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ]),
              ),
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _addresses.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.location_off, size: 80, color: AppTheme.grey),
                    const SizedBox(height: 16),
                    const Text('Nessun indirizzo salvato', style: TextStyle(color: AppTheme.grey, fontSize: 16, fontFamily: 'Poppins')),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Aggiungi indirizzo')),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _addresses.length,
                    itemBuilder: (c, i) {
                      final a = _addresses[i];
                      final isPredefinito = a['predefinito'] == true;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 38, height: 38,
                                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.location_on, color: AppTheme.primary, size: 20)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Nome e badge predefinito su righe separate se non ci sta
                                Text(a['nome_destinatario'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', fontSize: 14)),
                                if (isPredefinito)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Predefinito', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                const SizedBox(height: 2),
                                Text(a['telefono'] ?? '', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                              ])),
                              // Bottoni edit/delete compatti
                              Column(children: [
                                InkWell(
                                  onTap: () => _showForm(address: a),
                                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit, color: AppTheme.primary, size: 18)),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    await _client.from('indirizzi').delete().eq('id', a['id']);
                                    _load();
                                  },
                                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, color: Colors.red, size: 18)),
                                ),
                              ]),
                            ]),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.home_outlined, size: 14, color: AppTheme.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(
                                '${a['via'] ?? ''} ${a['civico'] ?? ''}, ${a['cap'] ?? ''} ${a['citta'] ?? ''} (${a['provincia'] ?? ''})',
                                style: const TextStyle(color: AppTheme.textMedium, fontSize: 13),
                              )),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
        floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Aggiungi', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            )
          : null,
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
