import re

# === 1. PATCH order_chat_screen.dart (cliente) ===
path = 'lib/screens/order_chat_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Aggiungi metodo per notificare admin e marcare letti
old_invia = '''  Future<void> _inviaMessaggio() async {
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
  }'''

new_invia = '''  Future<void> _inviaMessaggio() async {
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

    // Notifica admin
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
  }'''

content = content.replace(old_invia, new_invia)

# Aggiungi chiamata _marcaLettiDaCliente in initState
content = content.replace(
    '_avviaCountdown();',
    '_avviaCountdown();\n    _marcaLettiDaCliente();'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print(f'[OK] {path}')


# === 2. PATCH admin_order_chat_screen.dart ===
path = 'lib/screens/admin_order_chat_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_invia_admin = '''  Future<void> _inviaMessaggio() async {
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
  }'''

new_invia_admin = '''  Future<void> _inviaMessaggio() async {
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

    // Notifica cliente
    try {
      final ordine = await _supabase
          .from('ordini')
          .select('utente_id')
          .eq('id', widget.ordineId)
          .single();
      final profilo = await _supabase
          .from('profili')
          .select('fcm_token')
          .eq('id', ordine['utente_id'])
          .maybeSingle();
      final token = profilo?['fcm_token'];
      if (token != null && token.toString().isNotEmpty) {
        await _supabase.functions.invoke('send-notification', body: {
          'token': token,
          'title': 'Risposta dal negozio',
          'body': testo.length > 50 ? testo.substring(0, 50) + '...' : testo,
        });
      }
    } catch (_) {}
  }

  Future<void> _marcaLettiDaAdmin() async {
    await _supabase
        .from('messaggi_ordine')
        .update({'letto_da_admin': true})
        .eq('ordine_id', widget.ordineId)
        .eq('letto_da_admin', false);
  }'''

content = content.replace(old_invia_admin, new_invia_admin)

# Aggiungi _marcaLettiDaAdmin in initState
content = content.replace(
    '_sottoscriviMessaggi();',
    '_sottoscriviMessaggi();\n    _marcaLettiDaAdmin();'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print(f'[OK] {path}')


# === 3. PATCH orders_screen.dart (badge non letti) ===
path = 'lib/screens/orders/orders_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Aggiungi variabile per conteggio non letti
content = content.replace(
    'List<OrderModel> _orders = [];',
    'List<OrderModel> _orders = [];\n  Map<String, int> _nonLetti = {};'
)

# Aggiungi caricamento non letti dopo _load
old_load_end = "if (mounted) setState(() { _orders = orders; _loading = false; });"
new_load_end = """if (mounted) setState(() { _orders = orders; _loading = false; });
    _caricaNonLetti();"""

content = content.replace(old_load_end, new_load_end)

# Aggiungi metodo _caricaNonLetti dopo _load
content = content.replace(
    '  void _showResoForm',
    '''  Future<void> _caricaNonLetti() async {
    try {
      final userId = context.read<AuthService>().currentUser?.id;
      if (userId == null) return;
      final res = await Supabase.instance.client
          .from('messaggi_ordine')
          .select('ordine_id')
          .eq('letto_da_cliente', false)
          .eq('tipo_mittente', 'admin');
      final Map<String, int> conteggio = {};
      for (final r in res) {
        final id = r['ordine_id'] as String;
        conteggio[id] = (conteggio[id] ?? 0) + 1;
      }
      if (mounted) setState(() => _nonLetti = conteggio);
    } catch (_) {}
  }

  void _showResoForm'''
)

# Aggiungi badge nell'item della lista ordini
content = content.replace(
    "Text('Tocca per vedere i dettagli e il tracking', style: TextStyle(color: AppTheme.grey, fontSize: 11)),",
    """Text('Tocca per vedere i dettagli e il tracking', style: TextStyle(color: AppTheme.grey, fontSize: 11)),
                                if (_nonLetti.containsKey(o.id)) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                    child: Text('\${_nonLetti[o.id]} messaggio/i non letto/i', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],"""
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print(f'[OK] {path}')

print('\\n[DONE] Tutte le patch applicate!')