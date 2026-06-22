import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Note Legali', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Termini e Condizioni', Icons.gavel_rounded, Colors.brown, 'Utilizzando questa applicazione, accetti i presenti termini e condizioni. Top Phone Torre si riserva il diritto di modificare i prezzi e la disponibilità dei prodotti in qualsiasi momento. Gli ordini sono soggetti a disponibilità del prodotto al momento del pagamento.'),
          _section('Politica di Reso', Icons.assignment_return_rounded, Colors.orange, 'Hai diritto di recedere dal contratto entro 14 giorni dalla ricezione del prodotto. Il prodotto deve essere restituito nelle condizioni originali, sigillato e non attivato, completo di tutti gli accessori e imballaggio originale. Le spese di spedizione per il reso sono a carico del cliente.'),
          _section('Privacy Policy', Icons.privacy_tip_rounded, Colors.blue, 'I tuoi dati personali vengono raccolti e trattati in conformità con il GDPR (Regolamento UE 2016/679). I dati vengono utilizzati esclusivamente per la gestione degli ordini e non vengono ceduti a terzi. Puoi richiedere la cancellazione dei tuoi dati in qualsiasi momento contattandoci.'),
          _section('Pagamenti', Icons.payment_rounded, AppTheme.primary, 'I pagamenti vengono elaborati in modo sicuro tramite Stripe. I dati della carta di credito non vengono mai salvati sui nostri server. In caso di prodotto non disponibile, il rimborso viene effettuato automaticamente entro 5-10 giorni lavorativi.'),
          _section('Spedizioni', Icons.local_shipping_rounded, Colors.teal, 'Le spedizioni vengono effettuate tramite Poste Italiane con costo fisso di 10 euro. I tempi di consegna sono solitamente 2-4 giorni lavorativi. È possibile anche il ritiro gratuito presso il nostro negozio.'),
          _section('Contatti', Icons.store_rounded, Colors.green, 'Top Phone Torre\n' + AppConfig.shopAddress + '\nTel: ' + AppConfig.shopPhone + '\nP.IVA: ' + AppConfig.shopPiva),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Poppins')),
        ]),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.grey, fontFamily: 'Poppins', height: 1.6)),
      ]),
    );
  }
}
