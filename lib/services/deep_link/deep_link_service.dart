export 'deep_link_service_stub.dart'
    if (dart.library.io) 'deep_link_service_mobile.dart'
    if (dart.library.html) 'deep_link_service_web.dart';
