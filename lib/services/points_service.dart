import 'package:supabase_flutter/supabase_flutter.dart';

class PointsService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getPunti(String userId) async {
    final data = await _client.from('punti').select().eq('utente_id', userId).maybeSingle();
    if (data == null) {
      await _client.from('punti').insert({'utente_id': userId, 'punti_totali': 0, 'punti_usati': 0});
      return {'punti_totali': 0, 'punti_usati': 0};
    }
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
    final data = await _client.from('coupon').select().eq('utente_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> generaCoupon(String userId, int puntiRichiesti) async {
    final punti = await getPunti(userId);
    final disponibili = getPuntiDisponibili(punti);
    if (disponibili < puntiRichiesti) return null;

    double valore = 0;
    if (puntiRichiesti == 3) valore = 3.0;
    if (puntiRichiesti == 5) valore = 5.0;
    if (puntiRichiesti == 10) valore = 15.0;

    final codice = 'TOP-${userId.substring(0, 4).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final scadenza = DateTime.now().add(const Duration(days: 30));

    await _client.from('coupon').insert({
      'utente_id': userId,
      'codice': codice,
      'valore': valore,
      'usato': false,
      'scadenza': scadenza.toIso8601String(),
    });

    final totali = punti['punti_totali'] ?? 0;
    if (totali < puntiRichiesti) return null;
    
    // Controlla se premio già riscattato
    if (puntiRichiesti == 3 && punti['premio_3_riscattato'] == true) return null;
    if (puntiRichiesti == 5 && punti['premio_5_riscattato'] == true) return null;
    
    // A 10 punti si azzera tutto
    if (puntiRichiesti == 10) {
      await _client.from('punti').update({
        'punti_totali': 0, 
        'punti_usati': 0,
        'premio_3_riscattato': false,
        'premio_5_riscattato': false,
      }).eq('utente_id', userId);
    } else if (puntiRichiesti == 3) {
      await _client.from('punti').update({'premio_3_riscattato': true}).eq('utente_id', userId);
    } else if (puntiRichiesti == 5) {
      await _client.from('punti').update({'premio_5_riscattato': true}).eq('utente_id', userId);
    }
    // Punti NON si consumano per 3 e 5

    return codice;
  }

  Future<double?> verificaCoupon(String codice, String userId) async {
    final now = DateTime.now().toIso8601String();
    final data = await _client.from('coupon').select()
      .eq('codice', codice)
      .eq('utente_id', userId)
      .eq('usato', false)
      .gt('scadenza', now)
      .maybeSingle();
    if (data == null) return null;
    return (data['valore'] as num).toDouble();
  }

  Future<void> usaCoupon(String codice) async {
    await _client.from('coupon').update({'usato': true}).eq('codice', codice);
  }
}