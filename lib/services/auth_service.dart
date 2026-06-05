import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final _client = Supabase.instance.client;
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> loadUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _client.from('profili').select().eq('id', userId).single();
      _currentUser = UserModel.fromJson(data);
      notifyListeners();
    } catch (e) { print('loadUser error: $e'); }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await loadUser();
      return null;
    } catch (e) { return e.toString(); }
  }

  Future<String?> register(String nome, String cognome, String email, String password) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        final existing = await _client.from('profili').select().eq('id', res.user!.id).maybeSingle();
        if (existing == null) {
          await _client.from('profili').insert({'id': res.user!.id, 'nome': nome, 'cognome': cognome, 'email': email, 'ruolo': 'cliente'});
        } else {
          await _client.from('profili').update({'nome': nome, 'cognome': cognome}).eq('id', res.user!.id);
        }
        await loadUser();
      }
      return null;
    } catch (e) { return e.toString(); }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } catch (e) { return e.toString(); }
  }
}
