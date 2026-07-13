import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});
  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _client
        .from('profili')
        .select()
        .order('created_at', ascending: false);
    setState(() {
      _customers = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
        title: const Text('Clienti'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(child: Text('Nessun cliente'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _customers.length,
                  itemBuilder: (c, i) {
                    final customer = _customers[i];
                    final nome = (customer['nome'] ?? '').toString();
                    final cognome = (customer['cognome'] ?? '').toString();
                    final iniziale =
                        nome.isNotEmpty ? nome[0].toUpperCase() : '?';
                    final isAdmin = customer['ruolo'] == 'admin';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isAdmin ? Colors.orange : AppTheme.primary,
                          child: Text(iniziale,
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Row(children: [
                          Expanded(
                              child: Text('$nome $cognome',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'Cliente',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isAdmin ? Colors.orange : Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                        subtitle: Text(customer['email'] ?? ''),
                        trailing: IconButton(
                          icon: Icon(
                            isAdmin
                                ? Icons.person_rounded
                                : Icons.admin_panel_settings_rounded,
                            color: isAdmin ? Colors.red : Colors.orange,
                          ),
                          tooltip: isAdmin ? 'Rimuovi admin' : 'Rendi admin',
                          onPressed: () async {
                            final newRole = isAdmin ? 'cliente' : 'admin';
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                    isAdmin ? 'Rimuovi admin' : 'Rendi admin'),
                                content: Text(isAdmin
                                    ? 'Vuoi rimuovere i permessi admin a $nome?'
                                    : 'Vuoi rendere admin $nome?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Annulla')),
                                  ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                          isAdmin ? 'Rimuovi' : 'Rendi Admin')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _client.from('profili').update(
                                  {'ruolo': newRole}).eq('id', customer['id']);
                              await _load();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
