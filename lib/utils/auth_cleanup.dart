import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCleanup {
  static bool isInvalidRefreshTokenText(String text) {
    return text.contains('refresh_token_not_found') ||
        text.contains('Invalid Refresh Token: Refresh Token Not Found') ||
        text.contains('Refresh Token Not Found');
  }

  static bool isInvalidRefreshTokenError(Object error) {
    return isInvalidRefreshTokenText(error.toString());
  }

  static Future<void> safeSignOut({String reason = ''}) async {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      if (isInvalidRefreshTokenError(e)) {
        debugPrint('Ignored invalid refresh token during signOut. Reason: $reason');
        return;
      }
      rethrow;
    }
  }
}
