import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class OrderChatScreen extends StatefulWidget {
  final String ordineId;
  final DateTime ordineCreatoAt;

  const OrderChatScreen({
    super.key,
    required this.ordineId,
    required this.ordineCreatoAt,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messaggi = [];
  StreamSubscription? _subscription;
  Timer? _countdownTimer;
  Duration _tempoRimasto = Duration.zero;
  bool _scaduto = false;

  @override
  void initState() {
    super.initState();
    _caricaMessaggi();
    _sottoscriviMessaggi();
    _avviaCountdown();
    _marcaLettiDaCliente();
  }

  void _avviaCountdown() {
    final scadenza = widget.ordineCreatoAt.add(const Duration(hours: 1));
    _aggiornaTempoRimasto(scadenza);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _aggiornaTempoRimasto(scadenza);
    });
  }

  void _aggiornaTempoRimasto(DateTime scadenza) {
    final ora = DateTime.now();
    if (ora.isAfter(scadenza)) {
      setState(() {
        _scaduto = true;
        _tempoRimasto = Duration.zero;
      });
      _countdownTimer?.cancel();
    } else {
      setState(() {
        _tempoRimasto = scadenza.difference(ora);
      });
    }
  }

  Future<void> _caricaMessaggi() async {
    final res = await _supabase
        .from('messaggi_ordine')
        .select()
        .eq('ordine_id', widget.ordineId)
        .order('created_at', ascending: true);
    setState(() => _messaggi = List<Map<String, dynamic>>.from(res));
    _scrollInBasso();
  }

  void _sottoscriviMessaggi() {
    _subscription = _supabase
        .from('messaggi_ordine')
        .stream(primaryKey: ['id'])
        .eq('ordine_id', widget.ordineId)
        .order('created_at', ascending: true)
        .listen((data) {
          setState(() => _messaggi = data);
          _scrollInBasso();
        });
  }

  void _scrollInBasso() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _inviaMessaggio() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _scaduto) return;

    _controller.clear();

    await _supabase.from('messaggi_ordine').insert({
      'ordine_id': widget.ordineId,
      'tipo_mittente': 'cliente',
      'mittente_id': _supabase.auth.currentUser!.id,
      'messaggio': testo,
      'tipo_messaggio': 'testo',
    });

    try {
      final admins = await _supabase
          .from('profili')
          .select('fcm_token')
          .eq('ruolo', 'admin')
          .not('fcm_token', 'is', null);
      for (final admin in admins) {
        final token = admin['fcm_token'];
        if (token != null && token.toString().isNotEmpty) {
          await _supabase.functions.invoke('send-notification', body: {
            'token': token,
            'title': 'Nuovo messaggio ordine',
            'body': testo.length > 50 ? testo.substring(0, 50) + '...' : testo,
            'data': {'ordineId': widget.ordineId, 'type': 'chat_message'},
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _marcaLettiDaCliente() async {
    await _supabase
        .from('messaggi_ordine')
        .update({'letto_da_cliente': true})
        .eq('ordine_id', widget.ordineId)
        .eq('letto_da_cliente', false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        title: const Text('Chat Ordine'),
        actions: [
          if (!_scaduto)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tempoRimasto.inMinutes < 10
                        ? Colors.red.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_tempoRimasto.inMinutes}:${(_tempoRimasto.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _tempoRimasto.inMinutes < 10 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scaduto)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: const Row(
                children: [
                  Icon(Icons.timer_off, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Il tempo per richiedere modifiche è scaduto.',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messaggi.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun messaggio.\nScrivi per richiedere una modifica.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messaggi.length,
                    itemBuilder: (context, index) {
                      final msg = _messaggi[index];
                      final isCliente = msg['tipo_mittente'] == 'cliente';
                      final isSistema = msg['tipo_messaggio'] == 'sistema' ||
                          msg['tipo_messaggio'] == 'cambio_confermato' ||
                          msg['tipo_messaggio'] == 'cambio_rifiutato';

                      if (isSistema) return _messaggioSistema(msg);
                      return _bolla(msg, isCliente);
                    },
                  ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_scaduto,
                decoration: InputDecoration(
                  hintText: _scaduto ? 'Tempo scaduto' : 'Scrivi un messaggio...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _inviaMessaggio(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _scaduto ? Colors.grey : Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _scaduto ? null : _inviaMessaggio,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bolla(Map<String, dynamic> msg, bool isCliente) {
    return Align(
      alignment: isCliente ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCliente ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isCliente ? const Radius.circular(4) : null,
            bottomLeft: !isCliente ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg['messaggio'],
              style: TextStyle(
                color: isCliente ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatOra(msg['created_at']),
              style: TextStyle(
                color: isCliente ? Colors.white70 : Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messaggioSistema(Map<String, dynamic> msg) {
    final confermato = msg['tipo_messaggio'] == 'cambio_confermato';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: confermato ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        msg['messaggio'],
        textAlign: TextAlign.center,
        style: TextStyle(
          color: confermato ? Colors.green.shade800 : Colors.orange.shade800,
          fontSize: 13,
        ),
      ),
    );
  }

  String _formatOra(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
