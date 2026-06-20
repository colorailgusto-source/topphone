import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _client = Supabase.instance.client;
  String _budget = 'Non importa';
  String _uso = 'Uso quotidiano';
  String _marca = 'Nessuna preferenza';
  bool _loading = false;
  String? _errore;
  List<Map<String, dynamic>> _risultati = [];

  final List<String> _budgetOptions = ['Fino a 200€', '200-400€', 'Oltre 400€', 'Non importa'];
  final List<String> _usoOptions = ['Foto e selfie', 'Gaming', 'Batteria lunga', 'Uso quotidiano'];
  final List<String> _marcaOptions = ['Nessuna preferenza', 'Apple', 'Samsung', 'Xiaomi', 'Oppo', 'Honor', 'Motorola'];

  Future<void> _trovaTelefono() async {
    setState(() { _loading = true; _errore = null; _risultati = []; });
    try {
      var query = _client.from('prodotti').select();
      if (_budget == 'Fino a 200€') query = query.lte('prezzo', 200);
      if (_budget == '200-400€') query = query.gte('prezzo', 200).lte('prezzo', 400);
      if (_budget == 'Oltre 400€') query = query.gte('prezzo', 400);
      if (_marca != 'Nessuna preferenza') query = query.eq('marca', _marca);
      final candidatiGrezzi = await query.limit(30);
      final listaGrezza = (candidatiGrezzi as List).cast<Map<String, dynamic>>();
      if (listaGrezza.isEmpty) {
        setState(() { _loading = false; _errore = 'Nessun telefono disponibile con questi criteri. Prova ad ampliare la ricerca.'; });
        return;
      }
      final idsGrezzi = listaGrezza.map((p) => p['id'].toString()).toList();
      final variantiDisponibili = await _client.from('varianti_prodotto').select('prodotto_id').inFilter('prodotto_id', idsGrezzi).gt('stock', 0);
      final idsConStock = (variantiDisponibili as List).map((v) => v['prodotto_id'].toString()).toSet();
      final lista = listaGrezza.where((p) => idsConStock.contains(p['id'].toString())).take(12).toList();
      if (lista.isEmpty) {
        setState(() { _loading = false; _errore = 'Nessun telefono disponibile con questi criteri. Prova ad ampliare la ricerca.'; });
        return;
      }
      final elencoTesto = lista.map((p) =>
        '{"id":"' + p['id'].toString() + '","nome":"' + (p['marca'] ?? '') + ' ' + (p['nome'] ?? '') + '","prezzo":' + (p['prezzo'] ?? 0).toString() +
        ',"batteria":' + (p['batteria_mah']?.toString() ?? 'null') +
        ',"fotocamera":' + (p['fotocamera_mp']?.toString() ?? 'null') +
        ',"schermo":' + (p['schermo_pollici']?.toString() ?? 'null') +
        ',"processore":"' + (p['processore'] ?? '') + '"}'
      ).join(',');
      final prompt = 'Sei un commesso esperto in un negozio di smartphone. Il cliente cerca: budget ' + _budget + ', uso principale: ' + _uso + ', marca preferita: ' + _marca + '. Scegli MASSIMO 3 telefoni dalla lista seguente, quelli più adatti. Scegli SOLO tra questi id, non inventare altro. Rispondi SOLO con JSON in questo formato esatto senza testo aggiuntivo: {"consigli":[{"id":"...","motivo":"breve motivo in italiano max 15 parole"}]}. Lista: [' + elencoTesto + ']';

      final risposta = await _chiamaAI(prompt);
      if (risposta == null) {
        setState(() { _loading = false; _errore = 'Il nostro assistente AI è momentaneamente occupato. Riprova in qualche secondo.'; });
        return;
      }
      final clean = risposta.replaceAll('```json', '').replaceAll('```', '').trim();
      final jStart = clean.indexOf('{');
      final jEnd = clean.lastIndexOf('}');
      final parsed = jsonDecode(jStart != -1 && jEnd > jStart ? clean.substring(jStart, jEnd + 1) : clean);
      final consigli = (parsed['consigli'] as List?) ?? [];
      final risultati = <Map<String, dynamic>>[];
      for (final c in consigli) {
        final id = c['id'].toString();
        final prodotto = lista.firstWhere((p) => p['id'].toString() == id, orElse: () => {});
        if (prodotto.isNotEmpty) {
          risultati.add({...prodotto, 'motivo': c['motivo'] ?? ''});
        }
      }
      setState(() { _loading = false; _risultati = risultati; });
    } catch (e) {
      setState(() { _loading = false; _errore = 'Qualcosa è andato storto. Riprova.'; });
    }
  }

  Future<String?> _chiamaAI(String prompt, {int tentativo = 0}) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.functionsBaseUrl + '/groq-proxy'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AppConfig.supabaseAnonKey},
        body: jsonEncode({
          'prompt': prompt,
          'max_tokens': 400,
          'model': 'llama-3.1-8b-instant',
        }),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = (data['choices']?[0]?['message']?['content'] ?? '').toString().trim();
        return text;
      }
      if (response.statusCode == 429 && tentativo < 1) {
        await Future.delayed(const Duration(seconds: 3));
        return _chiamaAI(prompt, tentativo: tentativo + 1);
      }
      return null;
    } catch (e) {
      if (tentativo < 1) {
        await Future.delayed(const Duration(seconds: 3));
        return _chiamaAI(prompt, tentativo: tentativo + 1);
      }
      return null;
    }
  }

  Widget _chipGroup(String titolo, List<String> opzioni, String selezionato, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opzioni.map((o) => ChoiceChip(
            label: Text(o),
            selected: selezionato == o,
            selectedColor: AppTheme.primary,
            labelStyle: TextStyle(color: selezionato == o ? Colors.white : AppTheme.textDark),
            onSelected: (_) => onSelect(o),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Row(children: [Text('✨', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Assistente AI')]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dimmi cosa cerchi e ti consiglio il telefono giusto 📱', style: TextStyle(fontSize: 16, color: AppTheme.textMedium)),
            const SizedBox(height: 20),
            _chipGroup('💰 Budget', _budgetOptions, _budget, (v) => setState(() => _budget = v)),
            _chipGroup('🎯 Uso principale', _usoOptions, _uso, (v) => setState(() => _uso = v)),
            _chipGroup('📱 Marca preferita', _marcaOptions, _marca, (v) => setState(() => _marca = v)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _trovaTelefono,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('🔍 Trova il telefono per me', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_errore != null) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_errore!, style: const TextStyle(color: Colors.red)),
            ),
            if (_risultati.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('I telefoni perfetti per te:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              ..._risultati.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text((p['marca'] ?? '') + ' ' + (p['nome'] ?? ''), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(p['motivo'] ?? '', style: const TextStyle(color: AppTheme.textMedium)),
                  trailing: Text((p['prezzo'] ?? '').toString() + '€', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  onTap: () => context.push('/product/' + p['id'].toString()),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
