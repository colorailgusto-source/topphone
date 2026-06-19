import '../../config/app_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../models/variant_model.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _generando = false;
  int _progressoGenerazione = 0;
  int _totaleGenerazione = 0;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty ? _products : _products.where((p) => (p['nome'] ?? '').toString().toLowerCase().contains(q.toLowerCase()) || (p['marca'] ?? '').toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _generaDescrizioneAI(TextEditingController nomeCtrl, TextEditingController marcaCtrl, TextEditingController descCtrl, StateSetter setS, {String? prodottoId}) async {
    final nomeP = nomeCtrl.text.trim();
    final marcaP = marcaCtrl.text.trim();
    if (nomeP.isEmpty || marcaP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci nome e marca prima!'), backgroundColor: Colors.orange));
      return;
    }
    setS(() => descCtrl.text = '⏳ Generazione in corso...');
    String ramInfo = '';
    String memoriaInfo = '';
    try {
      if (prodottoId != null) {
        final varianti = await _client.from('varianti_prodotto').select('ram, memoria').eq('prodotto_id', prodottoId).limit(1);
        if (varianti.isNotEmpty) {
          ramInfo = varianti[0]['ram'] ?? '';
          memoriaInfo = varianti[0]['memoria'] ?? '';
        }
      }
    } catch (e) {}
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AppConfig.groqApiKey},
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [{'role': 'user', 'content': 'Scrivi una descrizione commerciale breve in italiano per questo smartphone: ' + marcaP + ' ' + nomeP + '. Max 2 frasi accattivanti. Solo la descrizione, senza titoli o elenchi.'}],
          'max_tokens': 150,
        }),
      );
      print('GEMINI status: ' + response.statusCode.toString());
      print('GEMINI body: ' + response.body.substring(0, response.body.length > 300 ? 300 : response.body.length));
      if (response.statusCode == 429) {
        setS(() => descCtrl.text = '');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏱️ Troppe richieste. Aspetta 1 minuto!'), backgroundColor: Colors.orange));
        return;
      }
      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] ?? '';
      if (text.isEmpty) {
        setS(() => descCtrl.text = '');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Risposta AI vuota, riprova'), backgroundColor: Colors.orange));
        return;
      }
      setS(() => descCtrl.text = text.trim());
    } catch (e) {
      setS(() => descCtrl.text = '');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore generazione AI'), backgroundColor: Colors.red));
    }
  }

  Future<void> _cancellaDescrizioni() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_rounded, color: Colors.red), SizedBox(width: 8), Text('Cancella descrizioni')]),
        content: const Text('Vuoi cancellare TUTTE le descrizioni di tutti i prodotti?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cancella tutte')),
        ],
      ),
    );
    if (confirm != true) return;
    await _client.from('prodotti').update({'descrizione': ''}).neq('id', '00000000-0000-0000-0000-000000000000');
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Descrizioni cancellate!'), backgroundColor: Colors.green));
  }

  Future<void> _generaTutte() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Text('✨', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Text('Genera descrizioni AI')]),
        content: const Text('Genera descrizioni AI per tutti i prodotti senza descrizione. Potrebbe richiedere qualche minuto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Genera tutte')),
        ],
      ),
    );
    if (confirm != true) return;

    final senzaDesc = _products.where((p) => (p['descrizione'] ?? '').toString().isEmpty).toList();
    if (mounted) setState(() { _generando = true; _progressoGenerazione = 0; _totaleGenerazione = senzaDesc.length; });
    int generati = 0;
    int errori = 0;
    for (final p in senzaDesc) {

      try {
        final nomeP = p['nome'] ?? '';
        final marcaP = p['marca'] ?? '';
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AppConfig.groqApiKey},
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': [{'role': 'user', 'content': 'Scrivi una descrizione commerciale breve in italiano per questo smartphone: ' + marcaP + ' ' + nomeP + '. Max 2 frasi accattivanti. Solo la descrizione, senza titoli o elenchi.'}],
            'max_tokens': 150,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = (data['choices']?[0]?['message']?['content'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            await _client.from('prodotti').update({'descrizione': text}).eq('id', p['id']);
            generati++;
          }
        } else {
          errori++;
        }
        if (mounted) setState(() => _progressoGenerazione++);
        await Future.delayed(const Duration(milliseconds: 2200));
      } catch (e) { errori++; if (mounted) setState(() => _progressoGenerazione++); }
    }
    if (mounted) setState(() => _generando = false);
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Generati: ' + generati.toString() + ' • Errori: ' + errori.toString()),
      backgroundColor: generati > 0 ? Colors.green : Colors.red,
    ));
  }

  Future<void> _completaSpecificheAI() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Text('🔋', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Text('Specifiche AI', style: TextStyle(fontSize: 16))]),
        content: const Text('L\'AI aggiungerà batteria, fotocamera, schermo e processore per tutti i prodotti. Verifica dopo!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Procedi')),
        ],
      ),
    );
    if (confirm != true) return;

    if (mounted) setState(() { _generando = true; _progressoGenerazione = 0; _totaleGenerazione = _products.length; });
    int aggiornati = 0;
    for (final p in _products) {
      try {
        final nomeP = p['nome'] ?? '';
        final marcaP = p['marca'] ?? '';
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + AppConfig.groqApiKey},
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': [{'role': 'user', 'content': 'Per lo smartphone ' + marcaP + ' ' + nomeP + ' dammi SOLO un JSON con questi campi: {"batteria_mah": NUMBER, "fotocamera_mp": NUMBER, "schermo_pollici": NUMBER, "processore": "STRING"}. Solo il JSON, nessun testo.'}],
            'max_tokens': 200,
          }),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = (data['choices']?[0]?['message']?['content'] ?? '').toString().trim();
          try {
            final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
            final specs = jsonDecode(clean);
            final batteria = specs['batteria_mah'];
            final fotocamera = specs['fotocamera_mp'];
            final schermo = specs['schermo_pollici'];
            final processore = specs['processore'];
            if (batteria != null && fotocamera != null) {
              await _client.from('prodotti').update({
                'batteria_mah': batteria,
                'fotocamera_mp': fotocamera,
                if (schermo != null) 'schermo_pollici': schermo,
                if (processore != null) 'processore': processore,
              }).eq('id', p['id']);
              aggiornati++;
            }
          } catch (e) { debugPrint('Errore specifiche $nomeP: $e | testo: $text'); }
        } else { debugPrint('Errore Groq status: ${response.statusCode} body: ${response.body}'); }
        if (mounted) setState(() => _progressoGenerazione++);
        await Future.delayed(const Duration(milliseconds: 2200));
      } catch (e) { if (mounted) setState(() => _progressoGenerazione++); }
    }
    if (mounted) setState(() => _generando = false);
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Specifiche aggiunte: ' + aggiornati.toString()),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _load() async {
    final data = await _client.from('prodotti').select().order('created_at', ascending: false);
    if (mounted) setState(() { _products = List<Map<String, dynamic>>.from(data); _filtered = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('prodotti').upload(fileName, file);
      return _client.storage.from('prodotti').getPublicUrl(fileName);
    } catch (e) { return null; }
  }

  void _showVariantManager(Map<String, dynamic> product) async {
    final variants = await _client.from('varianti_prodotto').select().eq('prodotto_id', product['id']).order('colore');
    List<VariantModel> vList = (variants as List).map((e) => VariantModel.fromJson(e)).toList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          expand: false, initialChildSize: 0.85,
          builder: (ctx, scroll) => SingleChildScrollView(
            controller: scroll, padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Varianti: ${product['nome']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('RAM / Memoria / Colore con stock per variante', style: TextStyle(color: AppTheme.grey, fontSize: 13), textAlign: TextAlign.center),
              const Divider(height: 16),
              ...vList.map((v) => Card(child: ListTile(
                title: Text(v.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Stock: ${v.stock}${v.prezzoExtra > 0 ? ' • +€${v.prezzoExtra}' : ''}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
                    onPressed: () => _showVariantForm(ctx, product['id'], variant: v, onSaved: () async {
                      final updated = await _client.from('varianti_prodotto').select().eq('prodotto_id', product['id']).order('colore');
                      setS(() => vList = (updated as List).map((e) => VariantModel.fromJson(e)).toList());
                    })),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () async {
                      await _client.from('varianti_prodotto').delete().eq('id', v.id);
                      final updated = await _client.from('varianti_prodotto').select().eq('prodotto_id', product['id']).order('colore');
                      setS(() => vList = (updated as List).map((e) => VariantModel.fromJson(e)).toList());
                    }),
                ]),
              ))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _showVariantForm(ctx, product['id'], onSaved: () async {
                  final updated = await _client.from('varianti_prodotto').select().eq('prodotto_id', product['id']).order('colore');
                  setS(() => vList = (updated as List).map((e) => VariantModel.fromJson(e)).toList());
                }),
                icon: const Icon(Icons.add), label: const Text('Aggiungi Variante'),
              )),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }

  void _showVariantForm(BuildContext ctx, String productId, {VariantModel? variant, required VoidCallback onSaved}) {
    final ram = TextEditingController(text: variant?.ram ?? '');
    final memoria = TextEditingController(text: variant?.memoria ?? '');
    final colore = TextEditingController(text: variant?.colore ?? '');
    final stock = TextEditingController(text: variant?.stock.toString() ?? '0');
    final prezzoExtra = TextEditingController(text: variant?.prezzoExtra.toString() ?? '0');
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      title: Text(variant == null ? 'Nuova Variante' : 'Modifica Variante'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ram, decoration: const InputDecoration(labelText: 'RAM (es. 8GB)', hintText: 'Lascia vuoto se non applicabile')),
        const SizedBox(height: 8),
        TextField(controller: memoria, decoration: const InputDecoration(labelText: 'Memoria (es. 256GB)')),
        const SizedBox(height: 8),
        TextField(controller: colore, decoration: const InputDecoration(labelText: 'Colore (es. Nero)')),
        const SizedBox(height: 8),
        TextField(controller: stock, decoration: const InputDecoration(labelText: 'Stock *'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        TextField(controller: prezzoExtra, decoration: const InputDecoration(labelText: 'Prezzo extra €'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Annulla')),
        ElevatedButton(onPressed: () async {
          final data = {
            'prodotto_id': productId, 'ram': ram.text.trim(),
            'memoria': memoria.text.trim(), 'colore': colore.text.trim(),
            'stock': int.tryParse(stock.text) ?? 0,
            'prezzo_extra': double.tryParse(prezzoExtra.text) ?? 0,
          };
          if (variant == null) {
            await _client.from('varianti_prodotto').insert(data);
          } else {
            await _client.from('varianti_prodotto').update(data).eq('id', variant.id);
          }
          Navigator.pop(dCtx);
          onSaved();
        }, child: const Text('Salva')),
      ],
    ));
  }

  void _showForm({Map<String, dynamic>? product}) {
    final nome = TextEditingController(text: product?['nome'] ?? '');
    final batteria = TextEditingController(text: product?['batteria_mah']?.toString() ?? '');
    final fotocamera = TextEditingController(text: product?['fotocamera_mp']?.toString() ?? '');
    final schermo = TextEditingController(text: product?['schermo_pollici']?.toString() ?? '');
    final processore = TextEditingController(text: product?['processore']?.toString() ?? '');
    final desc = TextEditingController(text: product?['descrizione'] ?? '');
    final marca = TextEditingController(text: product?['marca'] ?? '');
    final prezzo = TextEditingController(text: product?['prezzo']?.toString() ?? '');
    final stock = TextEditingController(text: product?['stock']?.toString() ?? '0');
    final immagineUrl = TextEditingController(text: product?['immagine'] ?? '');
    File? selectedImage;
    bool uploading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(product == null ? 'Nuovo Prodotto' : 'Modifica Prodotto', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) setS(() => selectedImage = File(picked.path));
              },
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.grey.withValues(alpha: 0.3))),
                child: selectedImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(selectedImage!, fit: BoxFit.cover))
                  : immagineUrl.text.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(immagineUrl.text, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.add_photo_alternate, size: 48, color: AppTheme.grey)))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate, size: 48, color: AppTheme.grey),
                        SizedBox(height: 8),
                        Text('Tocca per aggiungere foto', style: TextStyle(color: AppTheme.grey)),
                      ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome *')),
            const SizedBox(height: 8),
            TextField(controller: marca, decoration: const InputDecoration(labelText: 'Marca *')),
            const SizedBox(height: 8),
            TextField(controller: prezzo, decoration: const InputDecoration(labelText: 'Prezzo base €'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: stock, decoration: const InputDecoration(labelText: 'Stock (0 se usi varianti)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrizione'), maxLines: 3),
            const SizedBox(height: 12),
            const Text('⚡ Specifiche tecniche', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.grey)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: batteria, decoration: const InputDecoration(labelText: '🔋 Batteria (mAh)', prefixIcon: Icon(Icons.battery_charging_full)), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: fotocamera, decoration: const InputDecoration(labelText: '�� Fotocamera (MP)', prefixIcon: Icon(Icons.camera_alt)), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: schermo, decoration: const InputDecoration(labelText: '📺 Schermo (pollici)', prefixIcon: Icon(Icons.phone_android)), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: processore, decoration: const InputDecoration(labelText: '⚡ Processore', prefixIcon: Icon(Icons.memory)))),
            ]),
            const SizedBox(height: 4),
            StatefulBuilder(builder: (ctx2, setSS) => SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _generaDescrizioneAI(nome, marca, desc, setSS, prodottoId: product?['id']),
                icon: const Text('✨', style: TextStyle(fontSize: 16)),
                label: const Text('✨ Genera con AI'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple)),
              ),
            )),
            const SizedBox(height: 8),
            TextField(
              controller: immagineUrl,
              decoration: InputDecoration(
                labelText: 'URL Foto (alternativa alla galleria)',
                prefixIcon: const Icon(Icons.link),
                hintText: 'https://...',
                suffixIcon: immagineUrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { immagineUrl.clear(); setS(() {}); })
                  : null,
              ),
              onChanged: (v) => setS(() {}),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: uploading ? null : () async {
                setS(() => uploading = true);
                String? finalUrl = immagineUrl.text.trim();
                if (selectedImage != null) finalUrl = await _uploadImage(selectedImage!) ?? finalUrl;
                final data = {
                  'nome': nome.text.trim(), 'marca': marca.text.trim(),
                  'prezzo': double.tryParse(prezzo.text) ?? 0,
                  'stock': int.tryParse(stock.text) ?? 0,
                  'immagine': finalUrl, 'descrizione': desc.text.trim(),
                  'batteria_mah': batteria.text.trim().isNotEmpty ? int.tryParse(batteria.text.trim()) : null,
                  'fotocamera_mp': fotocamera.text.trim().isNotEmpty ? int.tryParse(fotocamera.text.trim()) : null,
                  'schermo_pollici': schermo.text.trim().isNotEmpty ? double.tryParse(schermo.text.trim()) : null,
                  'processore': processore.text.trim().isNotEmpty ? processore.text.trim() : null,
                };
                if (product == null) {
                  await _client.from('prodotti').insert(data);
                } else {
                  await _client.from('prodotti').update(data).eq('id', product['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: uploading ? const CircularProgressIndicator(color: Colors.white) : Text(product == null ? 'Aggiungi Prodotto' : 'Salva Modifiche'),
            )),
            const SizedBox(height: 16),
          ])),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))), title: const Text('Gestione Prodotti')),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), backgroundColor: AppTheme.primary, child: const Icon(Icons.add, color: Colors.white)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Cerca prodotto o marca...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _filter(''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            Expanded(child: _generando ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.purple), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text('⏳ ' + _progressoGenerazione.toString() + '/' + _totaleGenerazione.toString(), style: const TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _totaleGenerazione > 0 ? _progressoGenerazione / _totaleGenerazione : 0, backgroundColor: Colors.purple.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Colors.purple)),
              ]),
            ) : OutlinedButton.icon(
              onPressed: _generaTutte,
              icon: const Text('✨', style: TextStyle(fontSize: 14)),
              label: const Text('Genera tutte', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
            const SizedBox(width: 8),
            const SizedBox(width: 4),
            Expanded(child: OutlinedButton.icon(
              onPressed: _completaSpecificheAI,
              icon: const Text('🔋', style: TextStyle(fontSize: 14)),
              label: const Text('Specifiche AI', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
            const SizedBox(width: 4),
            Expanded(child: OutlinedButton.icon(
              onPressed: _cancellaDescrizioni,
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: const Text('Cancella tutte', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
          ]),
        ),
        Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _filtered.length,
            itemBuilder: (c, i) {
              final p = _filtered[i];
              return Card(child: Column(children: [
                ListTile(
                  leading: p['immagine'] != null && p['immagine'].toString().isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['immagine'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.phone_android)))
                    : const Icon(Icons.phone_android, size: 40, color: AppTheme.primary),
                  title: Text(p['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p['marca']} • €${p['prezzo']} • Stock: ${p['stock']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary), onPressed: () => _showForm(product: p)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('Conferma'),
                        content: Text('Eliminare ${p['nome']}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
                        ],
                      ));
                      if (confirm == true) { await _client.from('prodotti').delete().eq('id', p['id']); _load(); }
                    }),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _showVariantManager(p),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Gestisci Varianti (RAM/Memoria/Colore)'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                  )),
                ),
              ]));
            },
          ),
        ),
      ]),
    );
  }
}
