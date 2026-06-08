import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/points_service.dart';
import '../../theme/app_theme.dart';

class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key});
  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  final _pointsService = PointsService();
  Map<String, dynamic> _punti = {};
  List<Map<String, dynamic>> _coupon = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;
    final punti = await _pointsService.getPunti(userId);
    final coupon = await _pointsService.getCoupon(userId);
    if (mounted) setState(() { _punti = punti; _coupon = coupon; _loading = false; });
  }

  Future<void> _genera(int puntiRichiesti) async {
    final userId = context.read<AuthService>().currentUser?.id;
    if (userId == null) return;
    try {
    final codice = await _pointsService.generaCoupon(userId, puntiRichiesti);
    if (codice != null) {
      await _load();
      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🎉 Coupon Generato!', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Il tuo codice sconto è:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(codice, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Poppins')),
            ),
            const SizedBox(height: 8),
            const Text('Valido 30 giorni solo su spedizione', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: codice)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Codice copiato!"), backgroundColor: Colors.green, duration: Duration(seconds: 1))); }, icon: const Icon(Icons.copy), label: const Text("Copia"))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))),
            ]),
          ],
        ));
      }
    } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punti insufficienti'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: ' + e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final disponibili = _pointsService.getPuntiDisponibili(_punti);
    final totali = _punti['punti_totali'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(bottom: false, child: SizedBox(
            height: kToolbarHeight,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Text('Cashback & Premi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            ]),
          )),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Card punti
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(children: [
                const Text('I tuoi punti', style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Poppins')),
                const SizedBox(height: 8),
                Text('$disponibili', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const Text('punti disponibili', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                // Barra progressione
                Column(children: [
                  _progressBar(disponibili, 3, '3 punti = €3'),
                  const SizedBox(height: 8),
                  _progressBar(disponibili, 5, '5 punti = €5'),
                  const SizedBox(height: 8),
                  _progressBar(disponibili, 10, '10 punti = €15'),
                ]),
                const SizedBox(height: 8),
                Text('Totale acquistati: $totali telefoni', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 20),
            // Riscatta premi
            const Align(alignment: Alignment.centerLeft, child: Text('Riscatta Premio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins'))),
            const SizedBox(height: 12),
            _premioCard(3, 3.0, disponibili, _punti),
            const SizedBox(height: 8),
            _premioCard(5, 5.0, disponibili, _punti),
            const SizedBox(height: 8),
            _premioCard(10, 15.0, disponibili, _punti),
            const SizedBox(height: 20),
            // Coupon attivi
            if (_coupon.isNotEmpty) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('I tuoi Coupon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins'))),
              const SizedBox(height: 12),
              ..._coupon.map((c) => _couponCard(c)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Come funziona?', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                SizedBox(height: 8),
                Text('📱 Ogni telefono acquistato e consegnato = 1 punto\n🎁 Accumula punti e riscatta sconti\n📦 I coupon sono validi solo su spedizione\n⏰ I coupon scadono dopo 30 giorni', style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87)),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _progressBar(int disponibili, int target, String label) {
    final progress = (disponibili / target).clamp(0.0, 1.0);
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress, backgroundColor: Colors.white24, color: Colors.white, minHeight: 6),
      ])),
      const SizedBox(width: 8),
      Icon(disponibili >= target ? Icons.check_circle : Icons.lock, color: disponibili >= target ? Colors.greenAccent : Colors.white38, size: 20),
    ]);
  }

  Widget _premioCard(int punti, double valore, int disponibili, Map<String, dynamic> puntiData) {
    final giaRiscattato = punti != 10 && _pointsService.isPremioRiscattato(puntiData, punti);
    final abilitato = disponibili >= punti && !giaRiscattato;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        border: abilitato ? Border.all(color: AppTheme.primary, width: 1.5) : null,
      ),
      child: Row(children: [
        Text('🎁', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$punti punti → €${valore.toStringAsFixed(0)} sconto', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          Text(abilitato ? 'Puoi riscattare!' : 'Ti mancano ${punti - disponibili} punti', style: TextStyle(fontSize: 12, color: abilitato ? Colors.green : Colors.grey)),
        ])),
        ElevatedButton(
          onPressed: abilitato ? () => _genera(punti) : null,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Text(giaRiscattato ? 'Riscattato' : 'Riscatta'),
        ),
      ]),
    );
  }

  Widget _couponCard(Map<String, dynamic> c) {
    final usato = c['usato'] == true;
    final scadenza = DateTime.parse(c['scadenza']);
    final scaduto = scadenza.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: usato || scaduto ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        Icon(usato ? Icons.check_circle : scaduto ? Icons.cancel : Icons.local_offer, color: usato ? Colors.grey : scaduto ? Colors.red : Colors.green),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['codice'], style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: usato || scaduto ? Colors.grey : Colors.black)),
          Text('€${(c['valore'] as num).toStringAsFixed(0)} sconto • ${usato ? 'Usato' : scaduto ? 'Scaduto' : 'Valido fino al ${scadenza.day}/${scadenza.month}/${scadenza.year}'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        if (!usato && !scaduto) IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.blue), onPressed: () { Clipboard.setData(ClipboardData(text: c["codice"])); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Codice copiato!"), backgroundColor: Colors.green, duration: Duration(seconds: 1))); }),
      ]),
    );
  }
}