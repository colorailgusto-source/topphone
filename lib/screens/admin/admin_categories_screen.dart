import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _client.from('categorie').select().order('ordine');
    if (mounted) setState(() { _categories = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<String?> _uploadLogo(File file) async {
    try {
      final fileName = 'cat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('prodotti').upload(fileName, file);
      return _client.storage.from('prodotti').getPublicUrl(fileName);
    } catch (e) { return null; }
  }

  void _showForm({Map<String, dynamic>? cat}) {
    final nome = TextEditingController(text: cat?['nome'] ?? '');
    final ordine = TextEditingController(text: cat?['ordine']?.toString() ?? '0');
    final logoUrl = TextEditingController(text: cat?['immagine_url'] ?? '');
    bool attiva = cat?['attiva'] ?? true;
    File? selectedLogo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(cat == null ? 'Nuova Categoria' : 'Modifica Categoria', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 16),

            // Logo picker
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) setS(() => selectedLogo = File(picked.path));
              },
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: selectedLogo != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(selectedLogo!, fit: BoxFit.cover))
                  : logoUrl.text.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(logoUrl.text, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.add_photo_alternate, color: AppTheme.primary, size: 30)))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate, color: AppTheme.primary, size: 28),
                        SizedBox(height: 4),
                        Text('Logo', style: TextStyle(fontSize: 10, color: AppTheme.grey)),
                      ]),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Tocca per aggiungere logo', style: TextStyle(color: AppTheme.grey, fontSize: 11, fontFamily: 'Poppins')),
            const SizedBox(height: 16),

            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome marca/categoria *')),
            const SizedBox(height: 8),
            TextField(
              controller: logoUrl,
              decoration: InputDecoration(
                labelText: 'URL Logo (opzionale)',
                prefixIcon: const Icon(Icons.link),
                hintText: 'https://...',
                suffixIcon: logoUrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.preview), onPressed: () => setS(() {}))
                  : null,
              ),
              onChanged: (v) => setS(() {}),
            ),
            const SizedBox(height: 8),
            TextField(controller: ordine, decoration: const InputDecoration(labelText: 'Ordine'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Categoria attiva', style: TextStyle(fontFamily: 'Poppins')),
              value: attiva,
              onChanged: (v) => setS(() => attiva = v),
              activeColor: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (nome.text.trim().isEmpty) return;
                String? finalUrl = logoUrl.text.trim();
                if (selectedLogo != null) finalUrl = await _uploadLogo(selectedLogo!) ?? finalUrl;
                final data = {
                  'nome': nome.text.trim(),
                  'ordine': int.tryParse(ordine.text) ?? 0,
                  'attiva': attiva,
                  'immagine_url': finalUrl,
                };
                if (cat == null) {
                  await _client.from('categorie').insert(data);
                } else {
                  await _client.from('categorie').update(data).eq('id', cat['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: Text(cat == null ? 'Aggiungi' : 'Salva'),
            )),
            const SizedBox(height: 20),
          ])),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))), title: const Text('Gestione Categorie')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _categories.isEmpty
          ? const Center(child: Text('Nessuna categoria'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              itemBuilder: (c, i) {
                final cat = _categories[i];
                final logoUrl = cat['immagine_url'] ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: cat['attiva'] == true ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cat['attiva'] == true ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.grey.withValues(alpha: 0.3)),
                      ),
                      child: logoUrl.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.phone_android, color: AppTheme.primary)))
                        : Text(cat['nome'][0].toUpperCase(), style: TextStyle(color: cat['attiva'] == true ? AppTheme.primary : AppTheme.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    title: Text(cat['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                    subtitle: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cat['attiva'] == true ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(cat['attiva'] == true ? 'Attiva' : 'Disattivata',
                          style: TextStyle(color: cat['attiva'] == true ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      if (logoUrl.isEmpty) ...[
                        const SizedBox(width: 6),
                        const Text('Nessun logo', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                      ],
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20), onPressed: () => _showForm(cat: cat)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async {
                        final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('Elimina?'),
                          content: Text('Eliminare "${cat['nome']}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
                          ],
                        ));
                        if (confirm == true) { await _client.from('categorie').delete().eq('id', cat['id']); _load(); }
                      }),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
