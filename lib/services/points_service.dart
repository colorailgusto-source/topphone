import 'package:supabase_flutter/supabase_flutter.dart';

class PointsService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getPunti(String userId) async {
    final data = await _client
        .from('punti')
        .select()
        .eq('utente_id', userId)
        .maybeSingle();
    if (data == null) return {'punti_totali': 0, 'punti_usati': 0};
    return data;
  }

  int getPuntiDisponibili(Map<String, dynamic> punti) {
    return punti['punti_totali'] ?? 0;
  }

  bool isPremioRiscattato(Map<String, dynamic> punti, int puntiRichiesti) {
    if (puntiRichiesti == 3) return punti['premio_3_riscattato'] == true;
    if (puntiRichiesti == 5) return punti['premio_5_riscattato'] == true;
    return false;
  }

  Future<List<Map<String, dynamic>>> getCoupon(String userId) async {
    final data = await _client
        .from('coupon')
        .select()
        .eq('utente_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> generaCoupon(String userId, int puntiRichiesti) async {
    return await _client
        .rpc('genera_coupon', params: {'p_punti_richiesti': puntiRichiesti});
  }

  Future<double?> verificaCoupon(String codice, String userId) async {
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from('coupon')
        .select()
        .eq('codice', codice)
        .eq('utente_id', userId)
        .eq('usato', false)
        .gt('scadenza', now)
        .maybeSingle();

    if (data == null) return null;
    return (data['valore'] as num).toDouble();
  }

  Future<void> usaCoupon(String codice) async {
    await _client.rpc('usa_coupon', params: {'p_codice': codice});
  }
}
