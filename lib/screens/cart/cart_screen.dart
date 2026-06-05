import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Timer? _timer;
  final _orderService = OrderService();
  bool _ordering = false;
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  String _selectedTime = '10:00';

  final List<String> _orari = [
    '09:30','10:00','10:30','11:00','11:30','12:00','12:30','13:00','13:30',
    '16:30','17:00','17:30','18:00','18:30','19:00','19:30','20:00'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _timer?.cancel(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _doCheckout(BuildContext sheetCtx, StateSetter setS) async {
    final cart = context.read<CartService>();
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    setS(() => _ordering = true);
    try {
      final righe = cart.items.map((i) => {
        'prodotto_id': i.product.id,
        'quantita': i.quantita,
        'prezzo': i.product.prezzo + (i.variant?.prezzoExtra ?? 0),
        'variante_id': i.variant?.id,
        'variante_label': i.variant?.label ?? '',
        'note_cliente': _noteCtrl.text.trim(),
      }).toList();
      final note = 'Ritiro: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} alle $_selectedTime'
        + (_noteCtrl.text.isNotEmpty ? ' | Note: ${_noteCtrl.text}' : '');
      await _orderService.createOrder(userId, cart.total, righe, note: note);
      cart.clearAfterOrder();
      if (mounted) {
        Navigator.pop(sheetCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ordine confermato! Ti aspettiamo in negozio.'), backgroundColor: Colors.green));
        context.go('/orders');
      }
    } catch (e) {
      setS(() => _ordering = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  void _showCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final cart = context.read<CartService>();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + MediaQuery.of(sheetCtx).padding.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Ritiro in Negozio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Top Phone Torre — Via Nazionale 68, Torre del Greco', style: TextStyle(color: AppTheme.grey, fontSize: 13), textAlign: TextAlign.center),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.access_time, size: 16, color: AppTheme.primary), SizedBox(width: 8), Expanded(child: Text('Lun-Sab: 09:30-13:30 / 16:30-20:00', style: TextStyle(fontSize: 13)))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.phone, size: 16, color: AppTheme.primary), SizedBox(width: 8), Text('081 341 7717', style: TextStyle(fontSize: 13))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.payment, size: 16, color: AppTheme.primary), SizedBox(width: 8), Text('Pagamento in sede al ritiro', style: TextStyle(fontSize: 13))]),
                ]),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: AppTheme.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
                title: const Text('Data ritiro', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx, initialDate: _selectedDate,
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
                    selectableDayPredicate: (day) => day.weekday != DateTime.sunday,
                  );
                  if (picked != null) setS(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTime,
                decoration: const InputDecoration(labelText: 'Ora di ritiro', prefixIcon: Icon(Icons.access_time)),
                items: _orari.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => setS(() => _selectedTime = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Note per il negozio (opzionale)', prefixIcon: Icon(Icons.note_outlined))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Totale da pagare in sede:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('€${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _ordering ? null : () => _doCheckout(sheetCtx, setS),
                icon: _ordering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.store),
                label: Text(_ordering ? 'Conferma in corso...' : 'Conferma Ritiro in Negozio', style: const TextStyle(fontSize: 15)),
              )),
              const SizedBox(height: 20),
            ])),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final items = cart.items;
    return Scaffold(
      appBar: GradientAppBar(title: 'Carrello'),
      body: items.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.grey),
            SizedBox(height: 16),
            Text('Il carrello è vuoto', style: TextStyle(fontSize: 18, color: AppTheme.grey)),
          ]))
        : Column(children: [
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                final remaining = item.remaining;
                final mins = remaining.inMinutes;
                final secs = remaining.inSeconds % 60;
                return Card(child: ListTile(
                  leading: item.product.immagine.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.product.immagine, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.phone_android)))
                    : const Icon(Icons.phone_android, size: 40),
                  title: Text(item.product.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((item.variant != null ? "${item.variant!.ram ?? ""} ${item.variant!.memoria ?? ""} ${item.variant!.colore ?? ""}".trim() : "").isNotEmpty) Text((item.variant != null ? "${item.variant!.ram ?? ""} ${item.variant!.memoria ?? ""} ${item.variant!.colore ?? ""}".trim() : ""), style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('€${(item.product.prezzo + (item.variant?.prezzoExtra ?? 0)).toStringAsFixed(2)} x ${item.quantita}'),
                    Row(children: [
                      const Icon(Icons.timer, size: 14, color: Colors.orange), const SizedBox(width: 4),
                      Text('$mins:${secs.toString().padLeft(2, '0')}', style: TextStyle(color: mins < 2 ? Colors.red : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Text('rimanenti', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                    ]),
                  ]),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => cart.removeItem(item)),
                ));
              },
            )),
            Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Totale:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('€${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ]),
                const SizedBox(height: 4),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.store, size: 14, color: AppTheme.grey), SizedBox(width: 4),
                  Text('Pagamento in sede al ritiro', style: TextStyle(color: AppTheme.grey, fontSize: 12)),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: _showCheckoutSheet,
                  icon: const Icon(Icons.store),
                  label: const Text('Ritira in Negozio', style: TextStyle(fontSize: 16)),
                )),
              ]),
            ),
          ]),
    );
  }
}
