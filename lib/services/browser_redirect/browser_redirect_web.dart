import 'package:web/web.dart' as web;

class BrowserRedirect {
  static void open(String url) {
    final uri = Uri.tryParse(url);

    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError('URL di pagamento non valido.');
    }

    web.window.location.assign(uri.toString());
  }
}
