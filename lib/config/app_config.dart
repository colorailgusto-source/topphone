import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurazione centralizzata dell'app.
/// In produzione usa --dart-define.
/// In sviluppo locale usa .env.
class AppConfig {

  static String get supabaseUrl =>
      _value('SUPABASE_URL');

  static String get supabasePublishableKey =>
      _value('SUPABASE_PUBLISHABLE_KEY');

  static String get stripePublishableKey =>
      _value('STRIPE_PUBLISHABLE_KEY');

  static String get functionsBaseUrl =>
      _value('FUNCTIONS_BASE_URL');


  static String _value(String key) {

    // Produzione Flutter Web
    const dartValue = String.fromEnvironment(key);

    if (dartValue.isNotEmpty) {
      return dartValue;
    }


    // Sviluppo locale
    final envValue = dotenv.env[key];

    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
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