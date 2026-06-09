import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/points_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  List<String> _getStati(String tipoConsegna) {
    if (tipoConsegna == 'spedizione') return ['ricevuto', 'confermato', 'spedito', 'consegnato'];
    return ['ricevuto', 'confermato', 'pronto_ritiro', 'consegnato'];
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _client.from('ordini')
      .select('*, profili(nome, cognome, email, telefono), righe_ordine(*, prodotti(nome))')
      .order('data', ascending: false);
    if (mounted) setState(() { _orders = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Color _statoColor(String stato) {
    switch (stato) {
      case 'ricevuto': return Colors.blue;
      case 'in_preparazione': return Colors.orange;
      case 'spedito': return Colors.purple;
      case 'confermato': return Colors.indigo;
      case 'pronto_ritiro': return Colors.teal;
      case 'consegnato': return Colors.green;
      case 'annullato': return Colors.red;
      default: return AppTheme.grey;
    }
  }

  Future<void> _annullaOrdine(Map<String, dynamic> order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Annulla Ordine', style: TextStyle(fontFamily: 'Poppins')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Annullare l\'ordine #${order['id'].toString().substring(0, 8)}?'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Lo stock verrà ripristinato automaticamente.', style: TextStyle(fontSize: 12, color: Colors.orange))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Indietro')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annulla Ordine'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.rpc('annulla_ordine', params: {'p_ordine_id': order['id']});
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ordine annullato e stock ripristinato!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showDetail(Map<String, dynamic> order) {
    final profilo = order['profili'] as Map<String, dynamic>?;
    final righe = (order['righe_ordine'] as List?) ?? [];
    String stato = order['stato'] ?? 'ricevuto';
    final trackingCtrl = TextEditingController(text: order['tracking'] ?? '');
    final isAnnullato = stato == 'annullato';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 1.0,
          builder: (ctx, scroll) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            controller: scroll,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Ordine #${order['id'].toString().substring(0, 8)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statoColor(stato).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(stato.replaceAll('_', ' '), style: TextStyle(color: _statoColor(stato), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ]),
              const Divider(height: 24),

              const Text('CLIENTE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${profilo?['nome'] ?? ''} ${profilo?['cognome'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              Text(profilo?['email'] ?? '', style: const TextStyle(color: AppTheme.grey)),
              const SizedBox(height: 16),

              const Text('PRODOTTI', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...righe.map((r) {
                final prodotto = r['prodotti'] as Map<String, dynamic>?;
                final varLabel = r['variante_label'] ?? '';
                final noteCliente = r['note_cliente'] ?? '';
                return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(prodotto?['nome'] ?? 'Prodotto', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  if (varLabel.isNotEmpty) Row(children: [
                    const Icon(Icons.tune, size: 14, color: AppTheme.primary), const SizedBox(width: 4),
                    Text(varLabel, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ]),
                  Text('Qtà: ${r['quantita']} • €${r['prezzo']} cad.', style: const TextStyle(color: AppTheme.grey)),
                  if (noteCliente.isNotEmpty) Row(children: [
                    const Icon(Icons.note, size: 14, color: Colors.orange), const SizedBox(width: 4),
                    Expanded(child: Text(noteCliente, style: const TextStyle(color: Colors.orange, fontSize: 13))),
                  ]),
                ])));
              }),

              const SizedBox(height: 8),
              if (order['tracking'] != null && order['tracking'].toString().isNotEmpty) ...[
                const Text('INFO RITIRO', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(order['tracking'], style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTALE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('€${order['totale']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ]),
              const Divider(height: 24),

              if (!isAnnullato) ...[
                const Text('AGGIORNA STATO', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: stato,
                  items: _getStati(order['tipo_consegna'] ?? 'ritiro').map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                  onChanged: (v) => setS(() => stato = v!),
                  decoration: const InputDecoration(labelText: 'Stato ordine'),
                ),
                const SizedBox(height: 8),
                if ((order['tipo_consegna'] ?? 'ritiro') == 'spedizione') ...[
                  StatefulBuilder(builder: (ctx2, setTracking) => Column(children: [
                    TextField(
                      controller: trackingCtrl,
                      onChanged: (_) => setTracking(() {}),
                      decoration: InputDecoration(
                        labelText: stato == 'spedito' ? 'Tracking obbligatorio *' : 'Tracking',
                        prefixIcon: const Icon(Icons.local_shipping),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (trackingCtrl.text.isNotEmpty)
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366), side: const BorderSide(color: Color(0xFF25D366))),
                        onPressed: () async {
                          final profilo = order['profili'] as Map<String, dynamic>?;
                          final tel = (profilo?['telefono'] ?? '').toString().replaceAll('+39', '').replaceAll('+', '').trim();
                          if (tel.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Numero cliente non disponibile'), backgroundColor: Colors.red));
                            return;
                          }
                          final msg = Uri.encodeComponent('Ciao! Siamo Top Phone Torre. Il tuo ordine e in arrivo! Codice tracking: ${trackingCtrl.text}. Per qualsiasi info chiamaci al 081 341 7717.');
                          final uri = Uri.parse('https://wa.me/39$tel?text=$msg');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Invia Tracking su WhatsApp'),
                      )),
                  ])),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if ((order['tipo_consegna'] ?? 'ritiro') == 'spedizione' && stato == 'spedito' && trackingCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci il tracking prima.'), backgroundColor: Colors.red));
                      return;
                    }
                    final Map<String, dynamic> update = {'stato': stato};
                    if (trackingCtrl.text.trim().isNotEmpty) update['tracking'] = trackingCtrl.text.trim();
                    await _client.from('ordini').update(update).eq('id', order['id']);
                    // Se consegnato e spedizione -> aggiungi punto
                    final tipoConsegna = order['tipo_consegna'] ?? '';
                    if (stato == 'consegnato') {
                      final userId = order['utente_id'];
                      if (userId != null) {
                        try {
                          final existing = await _client.from('punti').select('punti_totali').eq('utente_id', userId).maybeSingle();
                          if (existing == null) {
                            await _client.from('punti').insert({'utente_id': userId, 'punti_totali': 1, 'punti_usati': 0});
                          } else {
                            final nuovi = (existing['punti_totali'] as int) + 1;
                            await _client.from('punti').update({'punti_totali': nuovi}).eq('utente_id', userId);
                          }
                        } catch (e) { print('Errore punti: $e'); }
                      }
                    }
                    Navigator.pop(ctx);
                    _load();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stato aggiornato!'), backgroundColor: Colors.green));
                  },
                  child: const Text('Salva Stato'),
                )),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _annullaOrdine(order);
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annulla Ordine', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Ordine Annullato', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  ]),
                ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))), title: const Text('Gestione Ordini')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _orders.isEmpty
          ? const Center(child: Text('Nessun ordine'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              itemBuilder: (c, i) {
                final o = _orders[i];
                final profilo = o['profili'] as Map<String, dynamic>?;
                final stato = o['stato'] ?? 'ricevuto';
                final righe = (o['righe_ordine'] as List?) ?? [];
                return Card(
                  child: ListTile(
                    onTap: () => _showDetail(o),
                    title: Text('Ordine #${o['id'].toString().substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${profilo?['nome'] ?? ''} ${profilo?['cognome'] ?? ''} • €${o['totale']}'),
                      Text('${righe.length} prodotto/i', style: const TextStyle(fontSize: 12, color: AppTheme.grey)),
                      if (o['tracking'] != null && o['tracking'].toString().isNotEmpty)
                        Text(o['tracking'].toString().split('|').first.trim(), style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ]),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _statoColor(stato).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(stato.replaceAll('_', ' '), style: TextStyle(color: _statoColor(stato), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}