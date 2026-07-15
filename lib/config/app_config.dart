import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurazione centralizzata dell'app.
/// Produzione: usa --dart-define.
/// Sviluppo: usa .env.
class AppConfig {

  static String get supabaseUrl {
    const value = String.fromEnvironment('SUPABASE_URL');
    return value.isNotEmpty ? value : _env('SUPABASE_URL');
  }


  static String get supabasePublishableKey {
    const value = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    return value.isNotEmpty ? value : _env('SUPABASE_PUBLISHABLE_KEY');
  }


  static String get stripePublishableKey {
    const value = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    return value.isNotEmpty ? value : _env('STRIPE_PUBLISHABLE_KEY');
  }


  static String get functionsBaseUrl {
    const value = String.fromEnvironment('FUNCTIONS_BASE_URL');
    return value.isNotEmpty ? value : _env('FUNCTIONS_BASE_URL');
  }


  static String _env(String key) {

    final value = dotenv.env[key];

    if (value != null && value.isNotEmpty) {
      return value;
    }

    throw Exception(
      'Configurazione mancante: $key'
    );
  }



  // Info negozio

  static const shopPhone = '081 341 7717';

  static const shopPhoneInternational = '390813417717';

  static const shopStreet = 'Via Nazionale 68';

  static const shopCity = 'Torre del Greco';

  static const shopProvince = '(NA)';

  static const shopPiva = '07466281214';

  static const shopAddress =
      '$shopStreet, $shopCity $shopProvince';

  static const shopEmail =
      'topphonetorre@gmail.com';
}