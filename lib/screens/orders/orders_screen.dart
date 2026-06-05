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
    final orders = await _orderService.getUserOrders(userId);
    if (mounted) setState(() { _orders = orders; _loading = false; });
  }

  Color _statoColor(String stato) {
    switch (stato) {
      case 'ricevuto': return Colors.blue;
      case 'in_preparazione': return Colors.orange;
      case 'spedito': return Colors.purple;
      case 'consegnato': return Colors.green;
      default: return AppTheme.grey;
    }
  }

  IconData _statoIcon(String stato) {
    switch (stato) {
      case 'ricevuto': return Icons.inbox;
      case 'in_preparazione': return Icons.inventory;
      case 'spedito': return Icons.local_shipping;
      case 'consegnato': return Icons.check_circle;
      default: return Icons.help;
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
                      return Card(child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Ordine #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _statoColor(o.stato).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                Icon(_statoIcon(o.stato), size: 14, color: _statoColor(o.stato)),
                                const SizedBox(width: 4),
                                Text(o.stato.replaceAll('_', ' '), style: TextStyle(color: _statoColor(o.stato), fontSize: 12, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text('Totale: €${o.totale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          Text('Data: ${o.data.day}/${o.data.month}/${o.data.year}', style: const TextStyle(color: AppTheme.grey)),
                          if (o.tracking != null && o.tracking!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.store, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(o.tracking!, style: const TextStyle(color: AppTheme.grey, fontSize: 13))),
                            ]),
                          ],
                        ]),
                      ));
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
