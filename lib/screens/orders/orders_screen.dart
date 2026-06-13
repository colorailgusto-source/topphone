import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../models/order_model.dart';
import '../../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthService>().loadUser();
      _load();
    });
  }

  Future<void> _load() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;
    final orders = await _orderService.getUserOrdersDetailed(userId);
    if (mounted) setState(() { _orders = orders; _loading = false; });
  }

  void _showResoForm(OrderModel order) {
    final motivoCtrl = TextEditingController();
    String motivoSelezionato = '';
    bool loading = false;
    final motivi = ['Prodotto difettoso', 'Prodotto non conforme', 'Ho cambiato idea', 'Taglia/modello errato', 'Altro'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24, left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.assignment_return_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Richiedi Reso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            ]),
            const SizedBox(height: 4),
            Text('Ordine #${order.id.substring(0, 8)}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Motivo del reso *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: motivi.map((m) => ChoiceChip(
              label: Text(m),
              selected: motivoSelezionato == m,
              selectedColor: Colors.orange,
              labelStyle: TextStyle(color: motivoSelezionato == m ? Colors.white : AppTheme.textDark, fontSize: 12),
              onSelected: (_) => setS(() => motivoSelezionato = m),
            )).toList()),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Note aggiuntive (opzionale)',
                hintText: 'Descrivi il problema...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Le spese di spedizione per il reso sono a tuo carico. Il prodotto deve essere sigillato e non attivato.', style: TextStyle(fontSize: 11, color: Colors.red))),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: loading || motivoSelezionato.isEmpty ? null : () async {
                setS(() => loading = true);
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  final motivo = motivoSelezionato + (motivoCtrl.text.isNotEmpty ? ': ' + motivoCtrl.text : '');
                  await Supabase.instance.client.from('resi').insert({
                    'ordine_id': order.id,
                    'utente_id': userId,
                    'motivo': motivo,
                    'stato': 'richiesto',
                  });
                  // Aggiorna stato ordine
                  await Supabase.instance.client.from('ordini').update({'stato': 'reso_richiesto'}).eq('id', order.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    _load();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ Richiesta reso inviata! Ti contatteremo presto.'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  setS(() => loading = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: ' + e.toString()), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Invia Richiesta Reso', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Color _statoColor(String stato) {
    switch (stato) {
      case 'ricevuto': return Colors.blue;
      case 'in_preparazione': return Colors.orange;
      case 'confermato': return Colors.indigo;
      case 'pronto_ritiro': return Colors.teal;
      case 'spedito': return Colors.purple;
      case 'consegnato': return Colors.green;
      case 'reso_richiesto': return Colors.orange;
      case 'reso_approvato': return Colors.purple;
      case 'reso_rifiutato': return Colors.red;
      case 'annullato': return Colors.red;
      case 'rimborsato': return Colors.orange;
      default: return AppTheme.grey;
    }
  }

  IconData _statoIcon(String stato) {
    switch (stato) {
      case 'ricevuto': return Icons.inbox;
      case 'in_preparazione': return Icons.inventory;
      case 'confermato': return Icons.thumb_up;
      case 'pronto_ritiro': return Icons.store;
      case 'spedito': return Icons.local_shipping;
      case 'consegnato': return Icons.check_circle;
      case 'reso_richiesto': return Icons.assignment_return_rounded;
      case 'reso_approvato': return Icons.assignment_turned_in_rounded;
      case 'reso_rifiutato': return Icons.assignment_late_rounded;
      case 'annullato': return Icons.cancel;
      case 'rimborsato': return Icons.replay;
      default: return Icons.help;
    }
  }

  String _statoLabel(String stato) {
    switch (stato) {
      case 'ricevuto': return 'Ricevuto';
      case 'in_preparazione': return 'In Preparazione';
      case 'confermato': return 'Confermato';
      case 'pronto_ritiro': return '✅ Pronto per il Ritiro!';
      case 'spedito': return 'Spedito';
      case 'consegnato': return 'Consegnato';
      case 'reso_richiesto': return '↩️ Reso Richiesto';
      case 'reso_approvato': return '✅ Reso Approvato';
      case 'reso_rifiutato': return '❌ Reso Rifiutato';
      case 'annullato': return 'Annullato';
      case 'rimborsato': return '💸 Rimborsato';
      default: return stato;
    }
  }

  // Restituisce gli step della timeline in base al tipo di consegna
  List<Map<String, dynamic>> _getSteps(String tipoConsegna, String statoAttuale) {
    final steps = tipoConsegna == 'spedizione'
      ? [
          {'stato': 'ricevuto', 'label': 'Ordine Ricevuto', 'icon': Icons.inbox_rounded, 'desc': 'Il tuo ordine è stato ricevuto'},
          {'stato': 'confermato', 'label': 'Confermato', 'icon': Icons.thumb_up_rounded, 'desc': 'Ordine confermato dal negozio'},
          {'stato': 'spedito', 'label': 'Spedito', 'icon': Icons.local_shipping_rounded, 'desc': 'Il pacco è in viaggio'},
          {'stato': 'consegnato', 'label': 'Consegnato', 'icon': Icons.check_circle_rounded, 'desc': 'Ordine consegnato'},
        ]
      : [
          {'stato': 'ricevuto', 'label': 'Ordine Ricevuto', 'icon': Icons.inbox_rounded, 'desc': 'Il tuo ordine è stato ricevuto'},
          {'stato': 'confermato', 'label': 'Confermato', 'icon': Icons.thumb_up_rounded, 'desc': 'Ordine confermato dal negozio'},
          {'stato': 'pronto_ritiro', 'label': 'Pronto al Ritiro', 'icon': Icons.store_rounded, 'desc': 'Vieni a ritirare in negozio!'},
          {'stato': 'consegnato', 'label': 'Ritirato', 'icon': Icons.check_circle_rounded, 'desc': 'Ordine ritirato'},
        ];

    // Indice dello stato attuale
    final statiInOrdine = steps.map((s) => s['stato'] as String).toList();
    final currentIndex = statiInOrdine.indexOf(statoAttuale);

    return steps.map((s) {
      final stepIndex = statiInOrdine.indexOf(s['stato'] as String);
      return {
        ...s,
        'completed': currentIndex >= stepIndex,
        'active': currentIndex == stepIndex,
      };
    }).toList();
  }

  void _showDetail(OrderModel order) {
    final isAnnullato = order.stato == 'annullato' || order.stato == 'rimborsato';
    final steps = isAnnullato ? <Map<String, dynamic>>[] : _getSteps(order.tipoConsegna ?? 'ritiro', order.stato);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 1.0,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Ordine #${order.id.substring(0, 8)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statoColor(order.stato).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(_statoIcon(order.stato), size: 14, color: _statoColor(order.stato)),
                  const SizedBox(width: 4),
                  Text(_statoLabel(order.stato), style: TextStyle(color: _statoColor(order.stato), fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${order.data.day}/${order.data.month}/${order.data.year}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),

            // ── TIMELINE ANIMATA ──────────────────────────────────
            if (!isAnnullato && steps.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('STATO ORDINE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(height: 16),
              _buildTimeline(steps, order),
            ],

            // Annullato/Rimborsato
            if (isAnnullato) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(order.stato == 'rimborsato' ? Icons.replay : Icons.cancel, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order.stato == 'rimborsato' ? 'Pagamento Rimborsato' : 'Ordine Annullato',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    if (order.stato == 'rimborsato')
                      const Text('Il rimborso arriverà entro 5-10 giorni lavorativi.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ])),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            const Text('PRODOTTI', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            if (order.righe != null && order.righe!.isNotEmpty)
              ...order.righe!.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (r['immagine'] != null && r['immagine'].toString().isNotEmpty)
                        ? Image.network(r['immagine'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 50, height: 50, color: AppTheme.primary.withValues(alpha: 0.1), child: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20)))
                        : Container(width: 50, height: 50, color: AppTheme.primary.withValues(alpha: 0.1), child: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['nome_prodotto'] ?? 'Prodotto', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                      if (r['variante_label'] != null && r['variante_label'].toString().isNotEmpty)
                        Text(r['variante_label'], style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                      Text('Qtà: ${r['quantita']}', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                    ])),
                    Text('€${(r["prezzo"] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ]),
                ),
              ))
            else
              const Text('Nessun dettaglio disponibile', style: TextStyle(color: AppTheme.grey)),

            const Divider(height: 24),
            if (order.tipoConsegna == 'spedizione') ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Prodotti:', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                Text('€${(order.totale - 10).toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Spese spedizione:', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                Text('€10.00', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              const Divider(height: 16),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTALE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('€${order.totale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ]),
            const SizedBox(height: 16),
            if (order.stato == 'consegnato' && (order.tipoConsegna ?? '') == 'spedizione' && DateTime.now().difference(order.data).inDays <= 14) ...[
              const Divider(height: 8),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.assignment_return_rounded, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text('Politica di Reso', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Hai 14 giorni per richiedere il reso. Il prodotto deve essere sigillato, non attivato e nelle condizioni originali. Le spese di spedizione per il reso sono a tuo carico.', style: TextStyle(fontSize: 12, color: AppTheme.grey, height: 1.5)),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showResoForm(order); },
                    icon: const Icon(Icons.undo_rounded, color: Colors.orange),
                    label: const Text('↩️ Richiedi Reso', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
              ),
            ],
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> steps, OrderModel order) {
    return Column(children: List.generate(steps.length, (i) {
      final step = steps[i];
      final completed = step['completed'] as bool;
      final active = step['active'] as bool;
      final isLast = i == steps.length - 1;
      final icon = step['icon'] as IconData;
      final label = step['label'] as String;
      final desc = step['desc'] as String;

      // Mostra tracking se spedito
      String? extraInfo;
      if (step['stato'] == 'spedito' && order.tracking != null && order.tracking!.isNotEmpty && !order.tracking!.startsWith('Spedizione') && !order.tracking!.startsWith('Ritiro') && completed) {
        extraInfo = order.tracking;
      }
      if (step['stato'] == 'pronto_ritiro' && completed) {
        extraInfo = 'Via Nazionale 68, Torre del Greco\n081 341 7717';
      }

      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icona + linea verticale
        Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: completed ? _getStepColor(step['stato'] as String) : Colors.grey.shade200,
              shape: BoxShape.circle,
              boxShadow: active ? [BoxShadow(color: _getStepColor(step['stato'] as String).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : [],
            ),
            child: Icon(icon, color: completed ? Colors.white : Colors.grey.shade400, size: 20),
          ),
          if (!isLast) AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 2, height: 50,
            color: completed && !(active && isLast) ? _getStepColor(step['stato'] as String).withValues(alpha: 0.5) : Colors.grey.shade200,
          ),
        ]),
        const SizedBox(width: 12),
        // Testo
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: completed ? AppTheme.textDark : Colors.grey,
              fontFamily: 'Poppins',
              fontSize: 14,
            )),
            Text(desc, style: TextStyle(
              fontSize: 12,
              color: completed ? AppTheme.grey : Colors.grey.shade400,
            )),
            if (extraInfo != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStepColor(step['stato'] as String).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _getStepColor(step['stato'] as String).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(step['stato'] == 'spedito' ? Icons.local_shipping : Icons.store, size: 14, color: _getStepColor(step['stato'] as String)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(extraInfo, style: TextStyle(fontSize: 12, color: _getStepColor(step['stato'] as String), fontWeight: FontWeight.w500))),
                ]),
              ),
            ],
            if (active) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _getStepColor(step['stato'] as String), borderRadius: BorderRadius.circular(20)),
                child: const Text('Stato attuale', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        )),
      ]);
    }));
  }

  Color _getStepColor(String stato) {
    switch (stato) {
      case 'ricevuto': return Colors.blue;
      case 'confermato': return Colors.indigo;
      case 'spedito': return Colors.purple;
      case 'pronto_ritiro': return Colors.teal;
      case 'consegnato': return Colors.green;
      case 'reso_richiesto': return Colors.orange;
      case 'reso_approvato': return Colors.purple;
      case 'reso_rifiutato': return Colors.red;
      default: return AppTheme.primary;
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
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/profile')),
                  const Text('I Miei Ordini', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ]),
              ),
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_outlined, size: 80, color: AppTheme.grey),
                    SizedBox(height: 16),
                    Text('Nessun ordine ancora', style: TextStyle(fontSize: 18, color: AppTheme.grey, fontFamily: 'Poppins')),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      itemBuilder: (c, i) {
                        final o = _orders[i];
                        final isProntoRitiro = o.stato == 'pronto_ritiro';
                        final isAnnullato = o.stato == 'annullato' || o.stato == 'rimborsato';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isProntoRitiro
                              ? const BorderSide(color: Colors.teal, width: 2)
                              : isAnnullato
                                ? const BorderSide(color: Colors.red, width: 1)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _showDetail(o),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text('Ordine #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _statoColor(o.stato).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Row(children: [
                                      Icon(_statoIcon(o.stato), size: 12, color: _statoColor(o.stato)),
                                      const SizedBox(width: 4),
                                      Text(_statoLabel(o.stato), style: TextStyle(color: _statoColor(o.stato), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text('${o.data.day}/${o.data.month}/${o.data.year}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                                  Text('€${o.totale.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                ]),
                                if (isProntoRitiro) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(8)),
                                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.store, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Vieni a ritirare!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ]),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                const Text('Tocca per vedere i dettagli e il tracking', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
// AGGIUNGI QUESTO METODO ALLA CLASSE _OrdersScreenState

// AGGIUNGI QUESTO METODO ALLA CLASSE _OrdersScreenState

// AGGIUNGI QUESTO METODO ALLA CLASSE _OrdersScreenState
