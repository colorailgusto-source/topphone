import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});
  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _client.from('banner').select().order('ordine');
    if (mounted) {
      setState(() {
        _banners = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppTheme.primary;
    }
  }

  void _showForm({Map<String, dynamic>? banner}) {
    final titolo = TextEditingController(text: banner?['titolo'] ?? '');
    final sottotitolo =
        TextEditingController(text: banner?['sottotitolo'] ?? '');
    final colore1 =
        TextEditingController(text: banner?['colore1'] ?? '#0288D1');
    final colore2 =
        TextEditingController(text: banner?['colore2'] ?? '#01579B');
    final ordine =
        TextEditingController(text: banner?['ordine']?.toString() ?? '0');
    bool attivo = banner?['attivo'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(banner == null ? 'Nuovo Banner' : 'Modifica Banner',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins')),
            const SizedBox(height: 16),

            // Anteprima banner
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _hexToColor(colore1.text),
                    _hexToColor(colore2.text)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(titolo.text.isEmpty ? 'Titolo banner' : titolo.text,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins')),
                      Text(
                          sottotitolo.text.isEmpty
                              ? 'Sottotitolo'
                              : sottotitolo.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Poppins')),
                    ]),
              ),
            ),

            TextField(
                controller: titolo,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'Titolo *')),
            const SizedBox(height: 8),
            TextField(
                controller: sottotitolo,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(labelText: 'Sottotitolo')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: colore1,
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  labelText: 'Colore 1 (hex)',
                  prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: _hexToColor(colore1.text),
                          borderRadius: BorderRadius.circular(6))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                controller: colore2,
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  labelText: 'Colore 2 (hex)',
                  prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: _hexToColor(colore2.text),
                          borderRadius: BorderRadius.circular(6))),
                ),
              )),
            ]),
            const SizedBox(height: 8),
            TextField(
                controller: ordine,
                decoration:
                    const InputDecoration(labelText: 'Ordine visualizzazione'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Banner attivo',
                  style: TextStyle(fontFamily: 'Poppins')),
              value: attivo,
              onChanged: (v) => setS(() => attivo = v),
              activeThumbColor: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titolo.text.trim().isEmpty) return;
                    final data = {
                      'titolo': titolo.text.trim(),
                      'sottotitolo': sottotitolo.text.trim(),
                      'colore1': colore1.text.trim(),
                      'colore2': colore2.text.trim(),
                      'ordine': int.tryParse(ordine.text) ?? 0,
                      'attivo': attivo,
                    };
                    if (banner == null) {
                      await _client.from('banner').insert(data);
                    } else {
                      await _client
                          .from('banner')
                          .update(data)
                          .eq('id', banner['id']);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Text(
                      banner == null ? 'Aggiungi Banner' : 'Salva Modifiche'),
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
      appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight))),
          title: const Text('Gestione Banner')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _banners.isEmpty
              ? const Center(child: Text('Nessun banner'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _banners.length,
                  itemBuilder: (c, i) {
                    final b = _banners[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _hexToColor(b['colore1'] ?? '#0288D1'),
                                _hexToColor(b['colore2'] ?? '#01579B')
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                    Text(b['titolo'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            fontFamily: 'Poppins')),
                                    Text(b['sottotitolo'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ])),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: b['attivo'] == true
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    b['attivo'] == true ? 'Attivo' : 'Off',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Modifica'),
                                    onPressed: () => _showForm(banner: b)),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  label: const Text('Elimina',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                              title:
                                                  const Text('Elimina banner?'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child:
                                                        const Text('Annulla')),
                                                ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child:
                                                        const Text('Elimina')),
                                              ],
                                            ));
                                    if (confirm == true) {
                                      await _client
                                          .from('banner')
                                          .delete()
                                          .eq('id', b['id']);
                                      _load();
                                    }
                                  },
                                ),
                              ]),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
