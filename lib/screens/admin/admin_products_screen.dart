import 'package:flutter/material.dart';
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
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _client.from('prodotti').select().order('created_at', ascending: false);
    if (mounted) setState(() { _products = List<Map<String, dynamic>>.from(data); _loading = false; });
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
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _products.length,
            itemBuilder: (c, i) {
              final p = _products[i];
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
    );
  }
}
