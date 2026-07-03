import '../../services/points_service.dart';
import '../../config/app_config.dart';
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
import '../../services/integrity_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/cart_reservation_timer.dart';

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
  final _couponCtrl = TextEditingController();
  double _scontoCoupon = 0.0;
  String? _couponValidato;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  String _selectedTime = '10:00';
  String _tipoConsegna = 'ritiro';
  bool _ritiroAttivo = true;
  bool _spedizioneAttiva = true;
  bool _configLoaded = false;
  bool _klarnaAttivo = false;
  double _klarnaMarkup = 6;
  bool _scalapayAttivo = false;
  double _scalapayMarkup = 6;
  double _costoSpedizione = 10;

  final List<String> _orari = [
    '09:30','10:00','10:30','11:00','11:30','12:00','12:30','13:00','13:30',
    '16:30','17:00','17:30','18:00','18:30','19:00','19:30','20:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _nomeSpedizioneCtrl.clear();
      _telefonoSpedCtrl.clear();
      _indirizzoCtrl.clear();
      _capCtrl.clear();
      _cittaCtrl.clear();
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
        debugPrint("Errore caricamento profilo: $e");
      }
      if (!mounted) return;
      await context.read<CartService>().loadFromDb();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        // Se qualche item è scaduto, ricarica il carrello
        final cart = context.read<CartService>();
        if (cart.items.any((i) => i.remaining.inSeconds <= 0)) {
          cart.loadFromDb();
        }
      }
    });
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
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _doCheckout(BuildContext sheetCtx, StateSetter setS, {String metodoPagamento = 'carta'}) async {
    final cart = context.read<CartService>();
    final auth = context.read<AuthService>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;
    // ✅ Play Integrity — verifica autenticità app (solo in produzione)
    final integrityOk = await IntegrityService.verifica();
    if (!integrityOk) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifica sicurezza fallita. Aggiorna l app.'), backgroundColor: Colors.red));
      return;
    }
    setS(() => _ordering = true);
    try {
      final righe = cart.items.map((i) => {
        'prodotto_id': i.product.id,
        'nome_prodotto': i.product.nome,
        'quantita': i.quantita,
        'prezzo': i.product.prezzo + (i.variant?.prezzoExtra ?? 0),
        'variante_id': i.variant?.id,
        'variante_label': i.variant?.label ?? '',
        'note_cliente': _noteCtrl.text.trim(),
      }).toList();
      final note = _tipoConsegna == 'ritiro'
        ? 'Ritiro: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} alle $_selectedTime' + (_noteCtrl.text.isNotEmpty ? ' | Note: ${_noteCtrl.text}' : '')
        : 'Spedizione a: ${_nomeSpedizioneCtrl.text.trim()}, ${_indirizzoCtrl.text.trim()}, ${_capCtrl.text.trim()} ${_cittaCtrl.text.trim()} | Tel: ${_telefonoSpedCtrl.text.trim()}' + (_noteCtrl.text.isNotEmpty ? ' | Note: ${_noteCtrl.text}' : '');
      if (_tipoConsegna == 'spedizione') {
        if (_nomeSpedizioneCtrl.text.trim().isEmpty ||
            _indirizzoCtrl.text.trim().isEmpty ||
            _cittaCtrl.text.trim().isEmpty ||
            _capCtrl.text.trim().isEmpty ||
            _telefonoSpedCtrl.text.trim().isEmpty) {
          setS(() => _ordering = false);
          showDialog(context: sheetCtx, builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("Dati mancanti")]),
            content: const Text("Compila tutti i campi obbligatori per la spedizione!"),
            actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ));
          return;
        }
      }
      if (_tipoConsegna == 'spedizione') {
        final righeStripe = cart.items.map((i) => {
          "prodotto_id": i.product.id,
          "quantita": i.quantita,
          "prezzo": i.product.prezzo + (i.variant?.prezzoExtra ?? 0),
          "variante_id": i.variant?.id,
          "variante_label": i.variant != null ? "${i.variant!.ram} ${i.variant!.memoria} ${i.variant!.colore}".trim() : null,
        }).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_user_id', userId);
        await prefs.setDouble('pending_total', cart.total + _costoSpedizione - _scontoCoupon);
        await prefs.setString('pending_righe', jsonEncode(righeStripe));
        await prefs.setString('pending_note', note);
        await prefs.setString('pending_tipo', _tipoConsegna);
        if (!sheetCtx.mounted) return;
        Navigator.pop(sheetCtx);
        await Future.delayed(const Duration(milliseconds: 300));
        final prezzoProdotti = metodoPagamento == 'klarna' ? cart.total * (1 + _klarnaMarkup / 100) : cart.total;
        final totaleDaPagare = (prezzoProdotti + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity);
        final paid = await StripeService.openPaymentSheet(
          totaleDaPagare,
          userId: userId,
          righeJson: jsonEncode(righeStripe),
          note: note,
          tipo: _tipoConsegna,
          couponCode: _couponValidato,
          metodoPagamento: metodoPagamento,
        );
        if (!paid) { if (mounted) setState(() => _ordering = false); return; }
        if (metodoPagamento == 'scalapay') {
          if (mounted) setState(() => _ordering = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa il pagamento ScalaPay nel browser. Il tuo ordine apparira in Ordini una volta confermato.'), backgroundColor: Colors.orange, duration: Duration(seconds: 6)));
          }
          return;
        }
        await prefs.setBool("from_stripe", true);
        await cart.clearAfterOrder();
        if (mounted) setState(() => _ordering = false);
      } else {
        // Fix: verifica carrello ancora valido (non scaduto)
        final carrelliValidi = await Supabase.instance.client.from('carrelli').select('id').eq('utente_id', userId).gt('scadenza', DateTime.now().toUtc().toIso8601String());
        if ((carrelliValidi as List).isEmpty) {
          throw StockEsauritoException('Carrello scaduto');
        }
        await _orderService.createOrder(userId, cart.total, righe, note: note, tipoConsegna: _tipoConsegna);
        await cart.clearAfterOrder();
      }
      if (mounted) {
        if (_tipoConsegna != 'spedizione') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Ordine confermato! Ti aspettiamo in negozio.'), backgroundColor: Colors.green));
        context.go('/order-success');
      }
    } on StockEsauritoException {
      if (mounted) setState(() => _ordering = false);
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.warning_rounded, color: Colors.red), SizedBox(width: 8), Text('Prodotto Esaurito')]),
        content: const Text('Il prodotto non è più disponibile. Il tuo carrello verrà svuotato.'),
        actions: [ElevatedButton(onPressed: () async { Navigator.pop(ctx); await context.read<CartService>().clearAfterOrder(); }, child: const Text('OK'))],
      ));
    } catch (e) {
      if (mounted) setState(() => _ordering = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadConfig() async {
    try {
      final data = await Supabase.instance.client.from('app_config').select('ritiro_attivo, spedizione_attiva, klarna_attivo, klarna_markup, costo_spedizione, scalapay_attivo, scalapay_markup').eq('id', 'config').single();
      if (mounted) setState(() {
        _ritiroAttivo = data['ritiro_attivo'] ?? true;
        _spedizioneAttiva = data['spedizione_attiva'] ?? true;
        _klarnaAttivo = data['klarna_attivo'] ?? false;
        _klarnaMarkup = (data['klarna_markup'] ?? 6).toDouble();
        _scalapayAttivo = data['scalapay_attivo'] ?? false;
        _scalapayMarkup = (data['scalapay_markup'] ?? 6).toDouble();
        _costoSpedizione = (data['costo_spedizione'] ?? 10).toDouble();
        _configLoaded = true;
        if (!_ritiroAttivo && _spedizioneAttiva) _tipoConsegna = 'spedizione';
        if (_ritiroAttivo && !_spedizioneAttiva) _tipoConsegna = 'ritiro';
      });
    } catch (e) { debugPrint("cart load config: $e"); }
  }

  Future<void> _loadProfiloSpedizione() async {
    try {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId != null) {
        final indirizzi = await Supabase.instance.client.from('indirizzi').select().eq('utente_id', userId).eq('predefinito', true).limit(1);
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
      debugPrint("Errore caricamento indirizzo: $e");
    }
  }

  void _showCheckoutSheet() {
    _loadProfiloSpedizione();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final cart = context.read<CartService>();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + MediaQuery.of(sheetCtx).padding.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(physics: const ClampingScrollPhysics(), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                IconButton(icon: const Icon(Icons.close, color: AppTheme.grey), onPressed: () => Navigator.pop(sheetCtx)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
Column(children: [
                  ChoiceChip(
                    label: Row(children: [Icon(Icons.store, size: 16, color: !_ritiroAttivo ? Colors.grey : _tipoConsegna == 'ritiro' ? Colors.white : AppTheme.textDark), const SizedBox(width: 4), Text('Ritiro in Sede', style: TextStyle(color: !_ritiroAttivo ? Colors.grey : _tipoConsegna == 'ritiro' ? Colors.white : AppTheme.textDark))]),
                    selected: _tipoConsegna == 'ritiro',
                    onSelected: _ritiroAttivo ? (_) => setS(() { _tipoConsegna = 'ritiro'; _scontoCoupon = 0; _couponValidato = null; _couponCtrl.clear(); }) : null,
                    selectedColor: AppTheme.primary,
                    disabledColor: Colors.grey.shade200,
                    labelStyle: TextStyle(color: !_ritiroAttivo ? Colors.grey : _tipoConsegna == 'ritiro' ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold),
                  ),
                  if (!_ritiroAttivo) const Text('Non disponibile', style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(width: 12),
Column(children: [
                  ChoiceChip(
                    label: Row(children: [Icon(Icons.local_shipping, size: 16, color: !_spedizioneAttiva ? Colors.grey : _tipoConsegna == 'spedizione' ? Colors.white : AppTheme.textDark), const SizedBox(width: 4), Text('Spedizione', style: TextStyle(color: !_spedizioneAttiva ? Colors.grey : _tipoConsegna == 'spedizione' ? Colors.white : AppTheme.textDark))]),
                    selected: _tipoConsegna == 'spedizione',
                    onSelected: _spedizioneAttiva ? (_) => setS(() => _tipoConsegna = 'spedizione') : null,
                    selectedColor: AppTheme.primary,
                    disabledColor: Colors.grey.shade200,
                    labelStyle: TextStyle(color: !_spedizioneAttiva ? Colors.grey : _tipoConsegna == 'spedizione' ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold),
                  ),
                  if (!_spedizioneAttiva) const Text('Non disponibile', style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 8),
              if (_tipoConsegna == 'ritiro') ...[
                Text('Top Phone Torre — ' + AppConfig.shopStreet + ', ' + AppConfig.shopCity, style: TextStyle(color: AppTheme.grey, fontSize: 13), textAlign: TextAlign.center),
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.access_time, size: 16, color: AppTheme.primary), const SizedBox(width: 8), const Expanded(child: Text('Lun-Sab: 09:30-13:30 / 16:30-20:00', style: TextStyle(fontSize: 13)))]),
                    const SizedBox(height: 6),
                    Row(children: [const Icon(Icons.phone, size: 16, color: AppTheme.primary), const SizedBox(width: 8), const Text('081 341 7717', style: TextStyle(fontSize: 13))]),
                    const SizedBox(height: 6),
                    Row(children: [const Icon(Icons.payment, size: 16, color: AppTheme.primary), const SizedBox(width: 8), const Text("Pagamento in sede al ritiro", style: TextStyle(fontSize: 13))]),
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
              ] else ...[
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
                const Divider(height: 24),
              ],
              const SizedBox(height: 8),
              TextField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Note per il negozio (opzionale)', prefixIcon: Icon(Icons.note_outlined))),
              if (_tipoConsegna == 'spedizione') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _couponCtrl,
                    decoration: InputDecoration(
                      labelText: 'Codice Coupon (opzionale)',
                      prefixIcon: const Icon(Icons.local_offer_outlined),
                      suffixIcon: _couponValidato != null ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    ),
                  )),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = context.read<AuthService>().currentUser?.id;
                      if (userId == null || _couponCtrl.text.trim().isEmpty) return;
                      final ps = PointsService();
                      final sconto = await ps.verificaCoupon(_couponCtrl.text.trim(), userId);
                      if (!sheetCtx.mounted) return;
                      if (sconto != null) {
                        setS(() { _scontoCoupon = sconto; _couponValidato = _couponCtrl.text.trim(); });
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Coupon applicato! €${sconto.toStringAsFixed(0)} di sconto'), backgroundColor: Colors.green));
                      } else {
                        setS(() { _scontoCoupon = 0; _couponValidato = null; });
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(content: Text('Coupon non valido o scaduto'), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Applica'),
                  ),
                ]),
                if (_scontoCoupon > 0) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Sconto applicato: €${_scontoCoupon.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
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
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Spese spedizione:', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                      Text('€${_costoSpedizione.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                    if (_scontoCoupon > 0) ...[
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Coupon sconto:', style: TextStyle(color: Colors.green, fontSize: 13)),
                        Text('-€${_scontoCoupon.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                    const Divider(height: 16),
                  ],
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_tipoConsegna == "spedizione" ? "Totale online:" : "Totale in sede:", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("€${_tipoConsegna == "spedizione" ? (cart.total + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity).toStringAsFixed(2) : cart.total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              if (_tipoConsegna == 'spedizione' && (_klarnaAttivo || _scalapayAttivo) && _spedizioneAttiva && !_ordering) ...[
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () { if (_ordering) return; _doCheckout(sheetCtx, setS, metodoPagamento: 'carta'); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.credit_card_rounded, color: Colors.white, size: 26),
                        const SizedBox(height: 6),
                        const Text('Paga con Carta', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('€${(cart.total + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    ),
                  )),
                  if (_klarnaAttivo) ...[
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(
                      onTap: () { if (_ordering) return; _doCheckout(sheetCtx, setS, metodoPagamento: 'klarna'); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB3C7),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFFFFB3C7).withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                            child: const Text('Klarna.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, fontStyle: FontStyle.italic)),
                          ),
                          const SizedBox(height: 6),
                          const Text('Paga in 3 rate', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('€${(cart.total * (1 + _klarnaMarkup / 100) + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    )),
                  ],
                  if (_scalapayAttivo) ...[
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(
                      onTap: () { if (_ordering) return; _doCheckout(sheetCtx, setS, metodoPagamento: 'scalapay'); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB9F7E8),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFFB9F7E8).withValues(alpha: 0.7), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                            child: const Text('scalapay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                          const SizedBox(height: 6),
                          const Text('Paga in 3 rate', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('€${(cart.total * (1 + _scalapayMarkup / 100) + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    )),
                  ],
                ]),
              const SizedBox(height: 8),
              Center(child: Text(_klarnaAttivo && _scalapayAttivo
                ? 'ℹ️ Con Klarna o ScalaPay il prezzo del prodotto aumenta per i costi del servizio a rate'
                : _klarnaAttivo
                  ? 'ℹ️ Con Klarna il prezzo del prodotto aumenta del ${_klarnaMarkup.toStringAsFixed(0)}% per i costi del servizio a rate'
                  : 'ℹ️ Con ScalaPay il prezzo del prodotto aumenta del ${_scalapayMarkup.toStringAsFixed(0)}% per i costi del servizio a rate',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.grey, fontStyle: FontStyle.italic))),
              const SizedBox(height: 4),
              ] else
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _ordering || (_tipoConsegna == 'ritiro' && !_ritiroAttivo) || (_tipoConsegna == 'spedizione' && !_spedizioneAttiva) ? null : () => _doCheckout(sheetCtx, setS),
                icon: _ordering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.store),
                label: Text(_ordering ? 'Conferma in corso...' : (_tipoConsegna == 'ritiro' && !_ritiroAttivo) ? 'Ritiro non disponibile' : (_tipoConsegna == 'spedizione' && !_spedizioneAttiva) ? 'Spedizione non disponibile' : _tipoConsegna == 'spedizione' ? 'Conferma Spedizione' : 'Conferma Ritiro in Negozio', style: const TextStyle(fontSize: 15)),
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carrello'), backgroundColor: Colors.white, foregroundColor: AppTheme.textDark, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.grey),
              const SizedBox(height: 24),
              const Text('Accedi per acquistare', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              const SizedBox(height: 12),
              const Text('Registrati gratuitamente per aggiungere prodotti al carrello e acquistare online!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.grey, height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/register'), child: const Text('Registrati — è gratis!'))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go('/login'), child: const Text('Accedi'))),
            ]),
          ),
        ),
      );
    }
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
            CartReservationTimer(remaining: items.map((i) => i.remaining).reduce((a, b) => a < b ? a : b)),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final item = items[i];
                return Card(child: ListTile(
                  leading: item.product.immagine.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.product.immagine, width: 50, height: 50, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.phone_android)))
                    : const Icon(Icons.phone_android, size: 40),
                  title: Text(item.product.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((item.variant != null ? "${item.variant!.ram} ${item.variant!.memoria} ${item.variant!.colore}".trim() : "").isNotEmpty)
                      Text((item.variant != null ? "${item.variant!.ram} ${item.variant!.memoria} ${item.variant!.colore}".trim() : ""), style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('€${(item.product.prezzo + (item.variant?.prezzoExtra ?? 0)).toStringAsFixed(2)} x ${item.quantita}'),
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
                      ? '€${(cart.total + _costoSpedizione - _scontoCoupon).clamp(0.0, double.infinity).toStringAsFixed(2)}'
                      : '€${cart.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ]),
                const SizedBox(height: 12),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: (_configLoaded && _ritiroAttivo) ? () { setState(() => _tipoConsegna = 'ritiro'); _showCheckoutSheet(); } : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: (_configLoaded && _ritiroAttivo) ? const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]) : null,
                      color: (_configLoaded && _ritiroAttivo) ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_configLoaded && _ritiroAttivo) ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.storefront_rounded, size: 26, color: (_configLoaded && _ritiroAttivo) ? Colors.white : Colors.grey),
                      const SizedBox(height: 6),
                      Text('Ritira in Negozio', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: (_configLoaded && _ritiroAttivo) ? Colors.white : Colors.grey)),
                      const SizedBox(height: 2),
                      Text(_ritiroAttivo ? 'Pronto in giornata' : 'Non disponibile', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: (_configLoaded && _ritiroAttivo) ? Colors.white70 : Colors.pinkAccent)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: (_configLoaded && _spedizioneAttiva) ? () { setState(() => _tipoConsegna = 'spedizione'); _showCheckoutSheet(); } : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: (_configLoaded && _spedizioneAttiva) ? const LinearGradient(colors: [Colors.indigo, Colors.deepPurple]) : null,
                      color: (_configLoaded && _spedizioneAttiva) ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_configLoaded && _spedizioneAttiva) ? [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_shipping_rounded, size: 26, color: (_configLoaded && _spedizioneAttiva) ? Colors.white : Colors.grey),
                      const SizedBox(height: 6),
                      Text('Effettua Spedizione', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: (_configLoaded && _spedizioneAttiva) ? Colors.white : Colors.grey)),
                      const SizedBox(height: 2),
                      Text(_spedizioneAttiva ? 'Consegna a domicilio' : 'Non disponibile', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: (_configLoaded && _spedizioneAttiva) ? Colors.white70 : Colors.pinkAccent)),
                    ]),
                  ),
                )),
              ]),
              ]),
            ),
          ]),
    );
  }
}
