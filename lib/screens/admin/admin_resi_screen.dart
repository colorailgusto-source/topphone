import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminResiScreen extends StatefulWidget {
  const AdminResiScreen({super.key});
  @override
  State<AdminResiScreen> createState() => _AdminResiScreenState();
}

class _AdminResiScreenState extends State<AdminResiScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _resi = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _client
        .from('resi')
        .select('*')
        .order('created_at', ascending: false);
    final List<Map<String, dynamic>> result = [];
    for (final r in data) {
      final profilo = await _client
          .from('profili')
          .select('nome, cognome, email, telefono')
          .eq('id', r['utente_id'])
          .maybeSingle();
      final ordine = await _client
          .from('ordini')
          .select('id, totale, tipo_consegna')
          .eq('id', r['ordine_id'])
          .maybeSingle();
      result.add({...r, 'profili': profilo, 'ordini': ordine});
    }
    setState(() {
      _resi = result;
      _loading = false;
    });
  }

  Color _statoColor(String stato) {
    switch (stato) {
      case 'richiesto':
        return Colors.orange;
      case 'approvato':
        return Colors.green;
      case 'rifiutato':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statoLabel(String stato) {
    switch (stato) {
      case 'richiesto':
        return 'In attesa';
      case 'approvato':
        return 'Approvato';
      case 'rifiutato':
        return 'Rifiutato';
      default:
        return stato;
    }
  }

  void _showDetail(Map<String, dynamic> reso) {
    final noteCtrl = TextEditingController(text: reso['note_admin'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).padding.bottom +
                  32,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gestisci Reso',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins')),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _statoColor(reso['stato'])
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(_statoLabel(reso['stato']),
                            style: TextStyle(
                                color: _statoColor(reso['stato']),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${reso['profili']?['nome'] ?? ''} ${reso['profili']?['cognome'] ?? ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(reso['profili']?['email'] ?? '',
                            style: const TextStyle(
                                color: AppTheme.grey, fontSize: 13)),
                        Text(reso['profili']?['telefono'] ?? '',
                            style: const TextStyle(
                                color: AppTheme.grey, fontSize: 13)),
                      ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Motivo reso:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(reso['motivo'] ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                      ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Note per il cliente (opzionale)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                if (reso['stato'] == 'richiesto')
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                      onPressed: () async {
                        await _client.from('resi').update({
                          'stato': 'rifiutato',
                          'note_admin': noteCtrl.text.trim(),
                          'updated_at': DateTime.now().toIso8601String()
                        }).eq('id', reso['id']);
                        await _client
                            .from('ordini')
                            .update({'stato': 'reso_rifiutato'}).eq(
                                'id', reso['ordine_id']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Rifiuta',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton.icon(
                      onPressed: () async {
                        await _client.from('resi').update({
                          'stato': 'approvato',
                          'note_admin': noteCtrl.text.trim(),
                          'updated_at': DateTime.now().toIso8601String()
                        }).eq('id', reso['id']);
                        await _client
                            .from('ordini')
                            .update({'stato': 'reso_approvato'}).eq(
                                'id', reso['ordine_id']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Reso approvato!'),
                                backgroundColor: Colors.green));
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Approva'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    )),
                  ]),
                const SizedBox(height: 8),
              ]),
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
        title: const Text('Gestione Resi'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _resi.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.assignment_return_rounded,
                          size: 64, color: AppTheme.grey),
                      SizedBox(height: 16),
                      Text('Nessuna richiesta di reso',
                          style: TextStyle(color: AppTheme.grey, fontSize: 16)),
                    ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _resi.length,
                    itemBuilder: (ctx, i) {
                      final reso = _resi[i];
                      final cliente =
                          '${reso['profili']?['nome'] ?? ''} ${reso['profili']?['cognome'] ?? ''}';
                      final dt = DateTime.parse(reso['created_at']).toLocal();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: _statoColor(reso['stato'])
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.assignment_return_rounded,
                                color: _statoColor(reso['stato'])),
                          ),
                          title: Text(cliente,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reso['motivo'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                                Text('${dt.day}/${dt.month}/${dt.year}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.grey)),
                              ]),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: _statoColor(reso['stato'])
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(_statoLabel(reso['stato']),
                                style: TextStyle(
                                    color: _statoColor(reso['stato']),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ),
                          onTap: () => _showDetail(reso),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
