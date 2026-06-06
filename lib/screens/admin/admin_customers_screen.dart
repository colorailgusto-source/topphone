import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _client.from('profili').select().eq('ruolo', 'cliente').order('created_at', ascending: false);
    if (mounted) setState(() { _customers = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))), title: const Text('Clienti')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _customers.isEmpty
          ? const Center(child: Text('Nessun cliente'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _customers.length,
              itemBuilder: (c, i) {
                final customer = _customers[i];
                final iniziale = (customer['nome'] ?? '?').toString().isNotEmpty ? customer['nome'][0].toUpperCase() : '?';
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppTheme.primary, child: Text(iniziale, style: const TextStyle(color: Colors.white))),
                  title: Text('${customer['nome'] ?? ''} ${customer['cognome'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(customer['email'] ?? ''),
                ));
              },
            ),
    );
  }
}
