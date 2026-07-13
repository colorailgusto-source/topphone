import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentRequestsScreen extends StatefulWidget {
  const AdminPaymentRequestsScreen({super.key});

  @override
  State<AdminPaymentRequestsScreen> createState() =>
      _AdminPaymentRequestsScreenState();
}

class _AdminPaymentRequestsScreenState
    extends State<AdminPaymentRequestsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  List<Map<String, dynamic>> _requests = [];

  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final result = await _client
          .from('richieste_pagamento')
          .select(
            'id, utente_id, email_cliente, importo_centesimi, '
            'valuta, descrizione, riferimento, stato, '
            'metodo_pagamento, created_at, pagato_at',
          )
          .order('created_at', ascending: false);

      final requests = (result as List)
          .map(
            (item) => Map<String, dynamic>.from(item as Map),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _createRequest() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amountText = _amountController.text.trim().replaceAll(',', '.');

    final amount = double.tryParse(amountText);

    if (amount == null || amount < 0.50) {
      _showMessage(
        'Inserisci un importo valido di almeno €0,50.',
        isError: true,
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final response = await _client.functions.invoke(
        'admin-create-payment-request',
        body: {
          'email': _emailController.text.trim().toLowerCase(),
          'importo_centesimi': (amount * 100).round(),
          'descrizione': _descriptionController.text.trim(),
          'riferimento': _referenceController.text.trim(),
        },
      );

      final data = response.data;

      if (data is! Map || data['success'] != true) {
        final message = data is Map ? data['message'] ?? data['error'] : null;

        throw Exception(
          message?.toString() ?? 'Creazione richiesta non riuscita',
        );
      }

      final customerRegistered = data['cliente_registrato'] == true;

      _emailController.clear();
      _amountController.clear();
      _descriptionController.clear();
      _referenceController.clear();

      await _loadRequests();

      if (!mounted) return;

      _showMessage(
        customerRegistered
            ? 'Richiesta creata. Il cliente la vedrà nei suoi ordini.'
            : 'Richiesta creata. Sarà collegata quando il cliente '
                'si registrerà con questa email.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('non_autorizzato')) {
      return 'Il tuo account non ha i permessi amministratore.';
    }

    if (text.contains('email_non_valida')) {
      return 'L’indirizzo email non è valido.';
    }

    if (text.contains('importo_non_valido')) {
      return 'L’importo inserito non è valido.';
    }

    if (text.contains('errore_creazione_richiesta')) {
      return 'Errore durante la creazione della richiesta.';
    }

    return 'Errore: $text';
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Inserisci l’email del cliente';
    }

    final valid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);

    if (!valid) {
      return 'Inserisci un indirizzo email valido';
    }

    return null;
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(
      (value ?? '').trim().replaceAll(',', '.'),
    );

    if (amount == null || amount < 0.50) {
      return 'Importo minimo €0,50';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final description = value?.trim() ?? '';

    if (description.isEmpty) {
      return 'Inserisci una descrizione';
    }

    if (description.length > 500) {
      return 'Massimo 500 caratteri';
    }

    return null;
  }

  String _formatAmount(dynamic centsValue) {
    final cents = centsValue is num
        ? centsValue.toInt()
        : int.tryParse(centsValue?.toString() ?? '') ?? 0;

    return '€${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) {
      return '-';
    }

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pagato':
        return 'Pagato';
      case 'pagamento_in_corso':
        return 'Pagamento in corso';
      case 'annullato':
        return 'Annullato';
      case 'da_pagare':
      default:
        return 'Da pagare';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pagato':
        return Colors.green;
      case 'pagamento_in_corso':
        return Colors.orange;
      case 'annullato':
        return Colors.red;
      case 'da_pagare':
      default:
        return const Color(0xFF0288D1);
    }
  }

  Widget _buildCreateForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuova richiesta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Il cliente troverà l’importo da saldare '
                'nella sezione I miei ordini.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email cliente',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateAmount,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9,.]'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Importo da saldare',
                  prefixText: '€ ',
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                textInputAction: TextInputAction.next,
                maxLength: 500,
                maxLines: 2,
                validator: _validateDescription,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  hintText: 'Es. iPhone acquistato in negozio',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _referenceController,
                textInputAction: TextInputAction.done,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Riferimento interno (facoltativo)',
                  hintText: 'Es. pratica 2026-001',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _createRequest,
                  icon: _sending
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _sending
                        ? 'Creazione in corso...'
                        : 'Crea richiesta di pagamento',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    final status = request['stato']?.toString() ?? '';

    if (requestId.isEmpty) {
      return;
    }

    if (status == 'pagato') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le richieste pagate non possono essere eliminate.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminare la richiesta?'),
          content: const Text(
            'La richiesta verrà eliminata definitivamente e non sarà '
            'più visibile al cliente. Questa azione non può essere '
            'annullata.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final response = await _client.functions.invoke(
        'admin-delete-payment-request',
        body: {'richiesta_id': requestId},
      );

      final rawData = response.data;
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ?? 'Eliminazione non riuscita.',
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Richiesta eliminata.')),
      );

      await _loadRequests();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione: $error')),
      );
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['stato']?.toString() ?? 'da_pagare';
    final color = _statusColor(status);
    final registered = request['utente_id'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    request['email_cliente']?.toString() ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatAmount(request['importo_centesimi']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF01579B),
                  ),
                ),
                if (status != 'pagato') ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _deleteRequest(request),
                    tooltip: 'Elimina richiesta',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request['descrizione']?.toString() ?? '',
            ),
            if ((request['riferimento']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Riferimento: ${request['riferimento']}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: registered
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    registered
                        ? 'Cliente registrato'
                        : 'In attesa di registrazione',
                    style: TextStyle(
                      color: registered ? Colors.green : Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Creata il ${_formatDate(request['created_at'])}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            if (status == 'pagato' && request['pagato_at'] != null)
              Text(
                'Pagata il ${_formatDate(request['pagato_at'])}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              const Text(
                'Impossibile caricare le richieste.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.request_quote_outlined,
                  size: 54,
                  color: Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  'Nessuna richiesta di pagamento',
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _requests.map(_buildRequestCard).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Richieste di pagamento',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF01579B),
                Color(0xFF0288D1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildCreateForm(),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Richieste create',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _loadRequests,
                  tooltip: 'Aggiorna',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRequestList(),
          ],
        ),
      ),
    );
  }
}
