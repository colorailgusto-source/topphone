import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/auth_cleanup.dart';

class AuthService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> loadUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data =
          await _client.from('profili').select().eq('id', userId).single();
      _currentUser = UserModel.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('loadUser error: $e');
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await loadUser();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(
      String nome, String cognome, String email, String password,
      {String telefono = '',
      String via = '',
      String civico = '',
      String cap = '',
      String citta = '',
      String provincia = ''}) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        final existing = await _client
            .from('profili')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();

        if (existing == null) {
          await _client.from('profili').insert({
            'id': res.user!.id,
            'nome': nome,
            'cognome': cognome,
            'email': email,
            'ruolo': 'cliente',
            'telefono': telefono,
            'via': via,
            'civico': civico,
            'cap': cap,
            'citta': citta,
            'provincia': provincia
          });
        } else {
          await _client
              .from('profili')
              .update({'nome': nome, 'cognome': cognome})
              .eq('id', res.user!.id);
        }

        if (via.isNotEmpty && cap.isNotEmpty && citta.isNotEmpty) {
          await _client.from('indirizzi').insert({
            'utente_id': res.user!.id,
            'nome_destinatario': '$nome $cognome'.trim(),
            'telefono': telefono,
            'via': via,
            'civico': civico,
            'citta': citta,
            'cap': cap,
            'provincia': provincia.toUpperCase(),
            'indirizzo':
                '$via $civico, $cap $citta (${provincia.toUpperCase()})',
            'predefinito': true,
          });
        }

        await loadUser();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await AuthCleanup.safeSignOut(reason: 'auth_service_logout');
    _currentUser = null;
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      final redirectUrl = kIsWeb
          ? 'https://topphoneweb.vercel.app/'
          : 'topphone://reset-password';

      debugPrint('RESET PASSWORD redirectTo: $redirectUrl');

      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
