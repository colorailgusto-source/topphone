import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurazione centralizzata dell'app.
/// Legge i segreti da variabili d'ambiente (file .env in dev, env vars in prod/CI).
/// I valori non sensibili (info negozio) restano costanti qui.
class AppConfig {
  // --- Segreti (da .env / env vars) ---
  static String get supabaseUrl => _env('SUPABASE_URL');
  static String get supabasePublishableKey => _env('SUPABASE_PUBLISHABLE_KEY');
  static String get stripePublishableKey => _env('STRIPE_PUBLISHABLE_KEY');
  static String get functionsBaseUrl => _env('FUNCTIONS_BASE_URL');

  // --- Info negozio (costanti, non sensibili) ---
  static const shopPhone = '081 341 7717';
  static const shopPhoneInternational = '390813417717';
  static const shopStreet = 'Via Nazionale 68';
  static const shopCity = 'Torre del Greco';
  static const shopProvince = '(NA)';
  static const shopPiva = '07466281214';
  static const shopAddress = '$shopStreet, $shopCity $shopProvince';
  static const shopEmail = 'topphonetorre@gmail.com';

  static String _env(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw AssertionError('Variabile d\'ambiente mancante: $key. '
          'Copia .env.example in .env e riempilo, oppure imposta la env var in CI/prod.');
    }
    return value;
  }
}