import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AdminOrderChatScreen extends StatefulWidget {
  final String ordineId;

  const AdminOrderChatScreen({super.key, required this.ordineId});

  @override
  State<AdminOrderChatScreen> createState() => _AdminOrderChatScreenState();
}

class _AdminOrderChatScreenState extends State<AdminOrderChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messaggi = [];
  List<Map<String, dynamic>> _righeOrdine = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _caricaMessaggi();
    _caricaRigheOrdine();
    _sottoscriviMessaggi();
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

  Future<void> _caricaRigheOrdine() async {
    final res = await _supabase
        .from('righe_ordine')
        .select('*, varianti_prodotto(id, colore, memoria, ram, stock, prodotto_id)')
        .eq('ordine_id', widget.ordineId);
    setState(() => _righeOrdine = List<Map<String, dynamic>>.from(res));
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
    if (testo.isEmpty) return;

    _controller.clear();

    await _supabase.from('messaggi_ordine').insert({
      'ordine_id': widget.ordineId,
      'tipo_mittente': 'admin',
      'mittente_id': _supabase.auth.currentUser!.id,
      'messaggio': testo,
      'tipo_messaggio': 'testo',
    });
  }

  Future<void> _mostraCambioVariante() async {
    if (_righeOrdine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun prodotto nell\'ordine')),
      );
      return;
    }

    final rigaScelta = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quale prodotto cambiare?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _righeOrdine.length,
            itemBuilder: (_, i) {
              final riga = _righeOrdine[i];
              return ListTile(
                title: Text(riga['variante_label'] ?? 'Prodotto'),
                subtitle: Text('Qtà: ${riga['quantita']} - €${riga['prezzo']}'),
                onTap: () => Navigator.pop(ctx, riga),
              );
            },
          ),
        ),
      ),
    );

    if (rigaScelta == null) return;

    final prodottoId = rigaScelta['varianti_prodotto']?['prodotto_id'] ?? rigaScelta['prodotto_id'];
    final varianteAttuale = rigaScelta['variante_id'];

    final varianti = await _supabase
        .from('varianti_prodotto')
        .select()
        .eq('prodotto_id', prodottoId)
        .gt('stock', 0)
        .neq('id', varianteAttuale)
        .order('colore');

    if (varianti.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessuna variante disponibile')),
        );
      }
      return;
    }

    if (!mounted) return;
    final nuovaVariante = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scegli nuova variante'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: varianti.length,
            itemBuilder: (_, i) {
              final v = varianti[i];
              final label = [v['colore'], v['memoria'], v['ram']]
                  .where((e) => e != null)
                  .join(' - ');
              return ListTile(
                title: Text(label),
                subtitle: Text('Stock: ${v['stock']}'),
                onTap: () => Navigator.pop(ctx, v),
              );
            },
          ),
        ),
      ),
    );

    if (nuovaVariante == null) return;

    final richiesta = await _supabase.from('richieste_cambio').insert({
      'ordine_id': widget.ordineId,
      'riga_ordine_id': rigaScelta['id'],
      'vecchia_variante_id': varianteAttuale,
      'nuova_variante_id': nuovaVariante['id'],
      'stato': 'in_attesa',
    }).select().single();

    try {
      await _supabase.functions.invoke('approve-change-request', body: {
        'richiesta_id': richiesta['id'],
        'nuova_variante_id': nuovaVariante['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variante cambiata')),
        );
        _caricaRigheOrdine();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('Chat Ordine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Cambia variante',
            onPressed: _mostraCambioVariante,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messaggi.isEmpty
                ? const Center(
                    child: Text('Nessun messaggio dal cliente.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messaggi.length,
                    itemBuilder: (context, index) {
                      final msg = _messaggi[index];
                      final isAdmin = msg['tipo_mittente'] == 'admin';
                      final isSistema = msg['tipo_messaggio'] == 'sistema' ||
                          msg['tipo_messaggio'] == 'cambio_confermato' ||
                          msg['tipo_messaggio'] == 'cambio_rifiutato';

                      if (isSistema) return _messaggioSistema(msg);
                      return _bolla(msg, isAdmin);
                    },
                  ),
          ),
          Container(
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
                      decoration: InputDecoration(
                        hintText: 'Rispondi al cliente...',
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
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _inviaMessaggio,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolla(Map<String, dynamic> msg, bool isAdmin) {
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isAdmin ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isAdmin ? const Radius.circular(4) : null,
            bottomLeft: !isAdmin ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg['messaggio'],
              style: TextStyle(
                color: isAdmin ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatOra(msg['created_at']),
              style: TextStyle(
                color: isAdmin ? Colors.white70 : Colors.grey,
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
