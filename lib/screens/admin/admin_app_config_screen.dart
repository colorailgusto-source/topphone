import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminAppConfigScreen extends StatefulWidget {
  const AdminAppConfigScreen({super.key});
  @override
  State<AdminAppConfigScreen> createState() => _AdminAppConfigScreenState();
}

class _AdminAppConfigScreenState extends State<AdminAppConfigScreen> {
  final _client = Supabase.instance.client;
  final _versioneMinima = TextEditingController();
  final _versioneAttuale = TextEditingController();
  final _urlAggiornamento = TextEditingController();
  final _messaggioAggiornamento = TextEditingController();
  final _messaggioManutenzione = TextEditingController();
  bool _manutenzione = false;
  bool _ritiroAttivo = true;
  bool _spedizioneAttiva = true;
  bool _klarnaAttivo = false;
  final _klarnaMarkup = TextEditingController(text: "6");
  final _costoSpedizione = TextEditingController(text: "10");
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _client.from('app_config').select().eq('id', 'config').single();
    setState(() {
      _versioneMinima.text = data['versione_minima'] ?? '1.0.0';
      _versioneAttuale.text = data['versione_attuale'] ?? '1.0.0';
      _urlAggiornamento.text = data['url_aggiornamento'] ?? '';
      _messaggioAggiornamento.text = data['messaggio_aggiornamento'] ?? '';
      _messaggioManutenzione.text = data['messaggio_manutenzione'] ?? 'App in manutenzione. Torneremo presto!';
      _manutenzione = data['manutenzione'] ?? false;
      _ritiroAttivo = data['ritiro_attivo'] ?? true;
      _spedizioneAttiva = data['spedizione_attiva'] ?? true;
      _klarnaAttivo = data['klarna_attivo'] ?? false;
      _klarnaMarkup.text = (data['klarna_markup'] ?? 6).toString();
      _costoSpedizione.text = (data['costo_spedizione'] ?? 10).toString();
      _loading = false;
    });
  }

  Future<void> _resetDati() async {
    // Conferma doppia
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Reset Dati Test')]),
        content: const Text('Questa operazione cancellerà TUTTI gli ordini, resi, analytics e resetterà le statistiche. Sei sicuro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Continua')),
        ],
      ),
    );
    if (confirm1 != true) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Conferma finale', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        content: const Text('ULTIMA CONFERMA: tutti i dati verranno eliminati definitivamente. Continuare?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('RESET')),
        ],
      ),
    );
    if (confirm2 != true) return;

    try {
      setState(() => _saving = true);
      final client = Supabase.instance.client;
      await client.rpc('admin_reset_dati_transazionali');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Reset completato!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: ' + e.toString()), backgroundColor: Colors.red));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
    await _client.from('app_config').update({
      'versione_minima': _versioneMinima.text.trim(),
      'versione_attuale': _versioneAttuale.text.trim(),
      'url_aggiornamento': _urlAggiornamento.text.trim(),
      'messaggio_aggiornamento': _messaggioAggiornamento.text.trim(),
      'manutenzione': _manutenzione,
      'ritiro_attivo': _ritiroAttivo,
      'spedizione_attiva': _spedizioneAttiva,
      'klarna_attivo': _klarnaAttivo,
      'klarna_markup': double.tryParse(_klarnaMarkup.text.trim()) ?? 6,
      'costo_spedizione': double.tryParse(_costoSpedizione.text.trim()) ?? 10,

      'messaggio_manutenzione': _messaggioManutenzione.text.trim(),
    }).eq('id', 'config');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Configurazione salvata!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: ' + e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        title: const Text('Configurazione App', style: TextStyle(color: Colors.white)),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Versioni
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('VERSIONE APP', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _versioneAttuale, decoration: const InputDecoration(labelText: 'Versione Attuale', hintText: '1.0.0', prefixIcon: Icon(Icons.new_releases)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _versioneMinima, decoration: const InputDecoration(labelText: 'Versione Minima', hintText: '1.0.0', prefixIcon: Icon(Icons.security_update)))),
            ]),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Se la versione minima è maggiore di quella installata, gli utenti saranno forzati ad aggiornare.', style: TextStyle(fontSize: 12, color: Colors.orange))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: _urlAggiornamento, decoration: const InputDecoration(labelText: 'URL Aggiornamento', prefixIcon: Icon(Icons.link))),
            const SizedBox(height: 8),
            TextField(controller: _messaggioAggiornamento, maxLines: 2, decoration: const InputDecoration(labelText: 'Messaggio Aggiornamento', prefixIcon: Icon(Icons.message))),
          ]))),
          const SizedBox(height: 16),
          // Manutenzione
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MODALITÀ MANUTENZIONE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Attiva Manutenzione', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              subtitle: Text(_manutenzione ? '⚠️ App bloccata per tutti tranne admin' : 'App funzionante normalmente', style: TextStyle(color: _manutenzione ? Colors.red : Colors.green, fontSize: 12)),
              value: _manutenzione,
              onChanged: (v) async {
                if (v) {
                  final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Attiva Manutenzione?', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('Gli utenti non potranno accedere all\'app. Solo gli admin potranno entrare.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Attiva')),
                    ],
                  ));
                  if (confirm == true) setState(() => _manutenzione = true);
                } else {
                  setState(() => _manutenzione = false);
                }
              },
              activeThumbColor: Colors.red,
              tileColor: _manutenzione ? Colors.red.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Ritiro in Negozio', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_ritiroAttivo ? '✅ Ritiro disponibile' : '❌ Ritiro non disponibile', style: TextStyle(color: _ritiroAttivo ? Colors.green : Colors.red, fontSize: 12)),
              value: _ritiroAttivo,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.green,
              onChanged: (v) => setState(() => _ritiroAttivo = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Spedizione a Domicilio', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_spedizioneAttiva ? '✅ Spedizione disponibile' : '❌ Spedizione non disponibile', style: TextStyle(color: _spedizioneAttiva ? Colors.green : Colors.red, fontSize: 12)),
              value: _spedizioneAttiva,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.green,
              onChanged: (v) => setState(() => _spedizioneAttiva = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Pagamento Klarna (a rate)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_klarnaAttivo ? '✅ Klarna disponibile' : '❌ Klarna non disponibile', style: TextStyle(color: _klarnaAttivo ? Colors.green : Colors.red, fontSize: 12)),
              value: _klarnaAttivo,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.purple,
              onChanged: (v) => setState(() => _klarnaAttivo = v),
            ),
            const SizedBox(height: 8),
            TextField(controller: _klarnaMarkup, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maggiorazione Klarna (%)', prefixIcon: Icon(Icons.percent), hintText: '6')),
            const SizedBox(height: 12),
            TextField(controller: _costoSpedizione, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo Spedizione (€)', prefixIcon: Icon(Icons.local_shipping), hintText: '10')),
            const SizedBox(height: 12),
            TextField(controller: _messaggioManutenzione, maxLines: 3, decoration: const InputDecoration(labelText: 'Messaggio Manutenzione', prefixIcon: Icon(Icons.construction), hintText: 'App in manutenzione. Torneremo presto!')),
          ]))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(_saving ? 'Salvataggio...' : 'Salva Configurazione', style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          )),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _saving ? null : _resetDati,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Reset Dati Test', style: TextStyle(color: Colors.red, fontSize: 16)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
