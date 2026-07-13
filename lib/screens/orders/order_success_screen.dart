import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _loading = true;
  bool _rimborsato = false;
  bool _accessoValido = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  bool _arrivaDaStripeUrl() {
    final fragment = Uri.base.fragment;
    final query = Uri.base.query;

    return fragment.contains('stripe=1') ||
        query.contains('stripe=1') ||
        fragment.contains('payment_intent=') ||
        query.contains('payment_intent=') ||
        fragment.contains('payment_intent_client_secret=') ||
        query.contains('payment_intent_client_secret=');
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final fromStripeUrl = _arrivaDaStripeUrl();
    final fromStripePrefs = prefs.getBool('from_stripe') ?? false;
    final fromRitiro = prefs.getBool('from_ritiro') ?? false;

    final fromStripe = fromStripePrefs || fromStripeUrl;

    await prefs.remove('from_stripe');
    await prefs.remove('from_ritiro');

    if (!fromStripe && !fromRitiro) {
      if (mounted) {
        context.go('/home');
      }
      return;
    }

    _accessoValido = true;

    if (fromStripe) {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      Map<String, dynamic>? ultimoOrdine;

      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(seconds: 2));

        final ordini = await Supabase.instance.client
            .from('ordini')
            .select('id, stato')
            .eq('utente_id', userId)
            .order('data', ascending: false)
            .limit(1);

        if (ordini.isNotEmpty) {
          ultimoOrdine = Map<String, dynamic>.from(ordini.first as Map);
          break;
        }
      }

      if (!mounted) return;

      context.read<CartService>().clear();

      final isRimborsato = ultimoOrdine != null &&
          ultimoOrdine['stato']?.toString() == 'rimborsato';

      setState(() {
        _loading = false;
        _rimborsato = isRimborsato;
      });

      return;
    }

    if (fromRitiro) {
      if (!mounted) return;

      context.read<CartService>().clear();

      setState(() {
        _loading = false;
        _rimborsato = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessoValido && !_loading) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Verifica pagamento in corso...',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    if (_rimborsato) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.replay,
                    color: Colors.orange,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Pagamento Rimborsato',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ci dispiace! Il prodotto non e\' piu\' disponibile.\nIl pagamento verra\' rimborsato entro 5-10 giorni lavorativi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Contattaci per assistenza',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '081 341 7717',
                        style: TextStyle(color: AppTheme.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.home),
                    label: const Text('Torna alla Home'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Ordine Completato!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Grazie per il tuo acquisto!\nRiceverai una notifica quando il tuo ordine sara\' pronto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.grey,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text(
                          'Top Phone Torre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${AppConfig.shopStreet}, ${AppConfig.shopCity}',
                      style: TextStyle(color: AppTheme.grey),
                    ),
                    Text(
                      '081 341 7717',
                      style: TextStyle(color: AppTheme.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/orders'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Vedi i miei ordini'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Torna alla Home'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
