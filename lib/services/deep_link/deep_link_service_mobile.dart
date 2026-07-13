import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _sub;

  static Future<void> init({
    required void Function(String path) onLink,
  }) async {
    await _sub?.cancel();

    _appLinks ??= AppLinks();

    _sub = _appLinks!.uriLinkStream.listen(
      (uri) => _dispatch(uri, onLink),
    );

    final initialLink = await _appLinks!.getInitialLink();

    if (initialLink != null) {
      _dispatch(initialLink, onLink);
    }
  }

  static void _dispatch(
    Uri uri,
    void Function(String path) onLink,
  ) {
    final route = _routeForUri(uri);

    if (route != null && route.isNotEmpty) {
      onLink(route);
    }
  }

  static String? _routeForUri(Uri uri) {
    var path = uri.path.trim();

    // topPhone://orders mette "orders" nell'host.
    // topPhone:///orders mette "/orders" nel path.
    if (path.isEmpty || path == '/') {
      final host = uri.host.trim();

      if (host.isNotEmpty) {
        path = '/$host';
      }
    }

    if (path.endsWith('/payment-request-success.html')) {
      return '/orders?payment_request=success';
    }

    if (path.endsWith('/payment-request-cancel.html')) {
      return '/orders?payment_request=cancel';
    }

    if (path.isEmpty) {
      return null;
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    final query = uri.hasQuery ? '?${uri.query}' : '';

    return '$path$query';
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
