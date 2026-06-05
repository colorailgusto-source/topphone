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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;
    final orders = await _orderService.getUserOrdersDetailed(userId);
    if (mounted) setState(() { _orders = orders; _loading = false; });
  }

  Color _statoColor(String stato) {
    switch (stato) {
      case 'ricevuto': return Colors.blue;
      case 'in_preparazione': return Colors.orange;
      case 'pronto_ritiro': return Colors.teal;
      case 'spedito': return Colors.purple;
      case 'consegnato': return Colors.green;
      default: return AppTheme.grey;
    }
  }

  IconData _statoIcon(String stato) {
    switch (stato) {
      case 'ricevuto': return Icons.inbox;
      case 'in_preparazione': return Icons.inventory;
      case 'pronto_ritiro': return Icons.store;
      case 'spedito': return Icons.local_shipping;
      case 'consegnato': return Icons.check_circle;
      default: return Icons.help;
    }
  }

  String _statoLabel(String stato) {
    switch (stato) {
      case 'ricevuto': return 'Ricevuto';
      case 'in_preparazione': return 'In Preparazione';
      case 'pronto_ritiro': return '✅ Pronto per il Ritiro!';
      case 'spedito': return 'Spedito';
      case 'consegnato': return 'Consegnato';
      case 'annullato': return 'Annullato';
      default: return stato;
    }
  }

  void _showDetail(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
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
            if (order.stato == 'pronto_ritiro') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withValues(alpha: 0.3))),
                child: const Row(children: [
                  Icon(Icons.store, color: Colors.teal),
                  SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Il tuo ordine è pronto!', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    Text('Via Nazionale 68, Torre del Greco\n081 341 7717', style: TextStyle(color: Colors.teal, fontSize: 12)),
                  ])),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            const Text('PRODOTTI', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            if (order.righe != null && order.righe!.isNotEmpty)
              ...order.righe!.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['nome_prodotto'] ?? 'Prodotto', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                      if (r['variante_label'] != null && r['variante_label'].toString().isNotEmpty)
                        Text(r['variante_label'], style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                      Text('Qtà: ${r['quantita']}', style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                    ])),
                    Text('€${r['prezzo']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ]),
                ),
              ))
            else
              const Text('Nessun dettaglio disponibile', style: TextStyle(color: AppTheme.grey)),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTALE', style: TextStyle(color: AppTheme.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('€${order.totale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ]),
            if (order.tracking != null && order.tracking!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('📅 ${order.tracking}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
            ],
            const SizedBox(height: 20),
          ]),
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
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/home')),
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
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _orders.length,
                    itemBuilder: (c, i) {
                      final o = _orders[i];
                      final isProntoRitiro = o.stato == 'pronto_ritiro';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isProntoRitiro ? const BorderSide(color: Colors.teal, width: 2) : BorderSide.none,
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
                              const Text('Tocca per vedere i dettagli', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
