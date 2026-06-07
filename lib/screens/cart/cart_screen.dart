import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/cart_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/order_service.dart';
import '../../services/stripe_service.dart';
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
  final _nomeSpedizioneCtrl = TextEditingController();
  final _indirizzoCtrl = TextEditingController();
  final _cittaCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _telefonoSpedCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  String _selectedTime = '10:00';
  String _tipoConsegna = 'ritiro';

  final List<String> _orari = [
    '09:30','10:00','10:30','11:00','11:30','12:00','12:30','13:00','13:30',
    '16:30','17:00','17:30','18:00','18:30','19:00','19:30','20:00'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Carica dati profilo aggiornati ogni volta
      _nomeSpedizioneCtrl.clear();
      _telefonoSpedCtrl.clear();
      _indirizzoCtrl.clear();
      _capCtrl.clear();
      _cittaCtrl.clear();
      // Carica dati profilo per pre-compilare spedizione
      try {
        final userId = context.read<AuthService>().currentUser?.id;
        if (userId != null) {
          final profilo = await Supabase.instance.client.from("profili").select().eq("id", userId).single();
          if (mounted) {
            _nomeSpedizioneCtrl.text = "${profilo["nome"] ?? ""} ${profilo["cognome"] ?? ""}".trim();
            _telefonoSpedCtrl.text = (profilo["telefono"] ?? "").toString();
            _indirizzoCtrl.text = "${profilo["via"] ?? ""} ${profilo["civico"] ?? ""}".trim();
            _capCtrl.text = (profilo["cap"] ?? "").toString();
            _cittaCtrl.text = (profilo["citta"] ?? "").toString();
          }
        }
      } catch (e) {
        print("Errore caricamento profilo: \$e");
      }
      await context.read<CartService>().loadFromDb();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { 
    _timer?.cancel(); 
    _noteCtrl.dispose(); 
    _nomeSpedizioneCtrl.dispose();
    _indirizzoCtrl.dispose();
    _cittaCtrl.dispose();
    _capCtrl.dispose();
    _telefonoSpedCtrl.dispose();
    super.dispose(); 
  }

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
      final note = _tipoConsegna == 'ritiro'
        ? 'Ritiro: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} alle $_selectedTime' + (_noteCtrl.text.isNotEmpty ? ' | Note: ${_noteCtrl.text}' : '')
        : 'Spedizione a: ${_nomeSpedizioneCtrl.text.trim()}, ${_indirizzoCtrl.text.trim()}, ${_capCtrl.text.trim()} ${_cittaCtrl.text.trim()} | Tel: ${_telefonoSpedCtrl.text.trim()}' + (_noteCtrl.text.isNotEmpty ? ' | Note: ${_noteCtrl.text}' : '');
      // Validazione dati spedizione
      if (_tipoConsegna == 'spedizione') {
        if (_nomeSpedizioneCtrl.text.trim().isEmpty || 
            _indirizzoCtrl.text.trim().isEmpty || 
            _cittaCtrl.text.trim().isEmpty || 
            _capCtrl.text.trim().isEmpty ||
            _telefonoSpedCtrl.text.trim().isEmpty) {
          setS(() => _ordering = false);
          showDialog(context: sheetCtx, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("Dati mancanti")]), content: const Text("Compila tutti i campi obbligatori per la spedizione!"), actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
          return;
        }
      }
      // Pagamento Stripe per spedizioni
      if (_tipoConsegna == 'spedizione') {
        final righe = cart.items.map((i) => {"prodotto_id": i.product.id, "quantita": i.quantita, "prezzo": i.product.prezzo + (i.variant?.prezzoExtra ?? 0), "variante_id": i.variant?.id, "variante_label": i.variant?.colore}).toList();
        // Salva dati ordine localmente prima di pagare
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_user_id', userId);
        await prefs.setDouble('pending_total', _tipoConsegna == 'spedizione' ? cart.total + 10 : cart.total);
        await prefs.setString('pending_righe', jsonEncode(righe));
        await prefs.setString('pending_note', note);
        await prefs.setString('pending_tipo', _tipoConsegna);
        
        Navigator.pop(sheetCtx);
        await Future.delayed(const Duration(milliseconds: 300));
        // Apri Stripe direttamente
        await StripeService.openCheckout(
          cart.total + 10,
          userId: userId,
          righeJson: jsonEncode(righe),
          note: note,
          tipo: _tipoConsegna,
        );
        setState(() => _ordering = false);
      } else {
        await _orderService.createOrder(userId, cart.total, righe, note: note, tipoConsegna: _tipoConsegna);
        await cart.clearAfterOrder();
      }
      if (mounted) {
        Navigator.pop(sheetCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tipoConsegna == 'spedizione' ? '✅ Ordine confermato! Procederemo alla spedizione.' : '✅ Ordine confermato! Ti aspettiamo in negozio.'), backgroundColor: Colors.green));
        context.go('/order-success');
      }
    } catch (e) {
      setS(() => _ordering = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadProfiloSpedizione() async {
    try {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId != null) {
        // Prendi indirizzo predefinito
        final indirizzi = await Supabase.instance.client
          .from('indirizzi')
          .select()
          .eq('utente_id', userId)
          .eq('predefinito', true)
          .limit(1);
        
        if (indirizzi.isNotEmpty) {
          final addr = indirizzi[0];
          if (mounted) {
            _nomeSpedizioneCtrl.text = addr['nome_destinatario'] ?? '';
            _telefonoSpedCtrl.text = addr['telefono'] ?? '';
            _indirizzoCtrl.text = '${addr['via'] ?? ''} ${addr['civico'] ?? ''}'.trim();
            _capCtrl.text = addr['cap'] ?? '';
            _cittaCtrl.text = addr['citta'] ?? '';
          }
        } else {
          // Fallback al profilo
          final profilo = await Supabase.instance.client.from('profili').select().eq('id', userId).single();
          if (mounted) {
            _nomeSpedizioneCtrl.text = '${profilo['nome'] ?? ''} ${profilo['cognome'] ?? ''}'.trim();
            _telefonoSpedCtrl.text = (profilo['telefono'] ?? '').toString();
            _indirizzoCtrl.text = '${profilo['via'] ?? ''} ${profilo['civico'] ?? ''}'.trim();
            _capCtrl.text = (profilo['cap'] ?? '').toString();
            _cittaCtrl.text = (profilo['citta'] ?? '').toString();
          }
        }
      }
    } catch (e) {
      print("Errore caricamento indirizzo: \$e");
    }
  }

  void _showCheckoutSheet() {
    _loadProfiloSpedizione();
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
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ChoiceChip(
                  label: const Row(children: [Icon(Icons.store, size: 16), SizedBox(width: 4), Text('Ritiro in Sede')]),
                  selected: _tipoConsegna == 'ritiro',
                  onSelected: (_) => setS(() => _tipoConsegna = 'ritiro'),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _tipoConsegna == 'ritiro' ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Row(children: [Icon(Icons.local_shipping, size: 16), SizedBox(width: 4), Text('Spedizione')]),
                  selected: _tipoConsegna == 'spedizione',
                  onSelected: (_) => setS(() => _tipoConsegna = 'spedizione'),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(color: _tipoConsegna == 'spedizione' ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 8),
              if (_tipoConsegna == 'ritiro')
                const Text('Top Phone Torre — Via Nazionale 68, Torre del Greco', style: TextStyle(color: AppTheme.grey, fontSize: 13), textAlign: TextAlign.center)
              else ...[
                const SizedBox(height: 12),
                TextField(controller: _nomeSpedizioneCtrl, decoration: const InputDecoration(labelText: 'Nome e Cognome *', prefixIcon: Icon(Icons.person_outlined))),
                const SizedBox(height: 8),
                TextField(controller: _telefonoSpedCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefono *', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 8),
                TextField(controller: _indirizzoCtrl, decoration: const InputDecoration(labelText: 'Via e Numero Civico *', prefixIcon: Icon(Icons.location_on_outlined))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _capCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CAP *'))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: _cittaCtrl, decoration: const InputDecoration(labelText: 'Città *'))),
                ]),
              ],
              const Text('Top Phone Torre — Via Nazionale 68, Torre del Greco', style: TextStyle(color: AppTheme.grey, fontSize: 13), textAlign: TextAlign.center),
              const Divider(height: 24),
              if (_tipoConsegna == 'ritiro') Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.access_time, size: 16, color: AppTheme.primary), SizedBox(width: 8), Expanded(child: Text('Lun-Sab: 09:30-13:30 / 16:30-20:00', style: TextStyle(fontSize: 13)))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.phone, size: 16, color: AppTheme.primary), SizedBox(width: 8), Text('081 341 7717', style: TextStyle(fontSize: 13))]),
                  const SizedBox(height: 6),
                  if (_tipoConsegna == "ritiro")
                    Row(children: [Icon(Icons.payment, size: 16, color: AppTheme.primary), SizedBox(width: 8), Text("Pagamento in sede al ritiro", style: TextStyle(fontSize: 13))])
                  else
                    Row(children: [Icon(Icons.local_shipping, size: 16, color: Colors.indigo), SizedBox(width: 8), Text("Pagamento online con Stripe", style: TextStyle(fontSize: 13))])
                ]),
              ),
              if (_tipoConsegna == 'ritiro') const SizedBox(height: 16),
              if (_tipoConsegna == 'ritiro') ListTile(
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
              if (_tipoConsegna == 'ritiro') const SizedBox(height: 8),
              if (_tipoConsegna == 'ritiro') DropdownButtonFormField<String>(
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_tipoConsegna == 'spedizione') ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Prodotti:', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                      Text('€${cart.total.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Spese spedizione:', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                      Text('€10.00', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                    const Divider(height: 16),
                    const Text('Totale da pagare online:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ] else
                    const Text('Totale da pagare in sede:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_tipoConsegna == "spedizione" ? "Totale online:" : "Totale in sede:", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("€${_tipoConsegna == "spedizione" ? (cart.total + 10).toStringAsFixed(2) : cart.total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _ordering ? null : () => _doCheckout(sheetCtx, setS),
                icon: _ordering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.store),
                label: Text(_ordering ? 'Conferma in corso...' : _tipoConsegna == 'spedizione' ? 'Conferma Spedizione' : 'Conferma Ritiro in Negozio', style: const TextStyle(fontSize: 15)),
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
                  Text(
                    _tipoConsegna == 'spedizione' 
                      ? '€${(cart.total + 10).toStringAsFixed(2)}' 
                      : '€${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () { setState(() => _tipoConsegna = 'ritiro'); _showCheckoutSheet(); },
                    icon: const Icon(Icons.store, size: 18),
                    label: const Text('Ritira in Negozio', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () { setState(() => _tipoConsegna = 'spedizione'); _showCheckoutSheet(); },
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: const Text('Spedizione', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.indigo,
                    ),
                  )),
                ]),
              ]),
            ),
          ]),
    );
  }
}
