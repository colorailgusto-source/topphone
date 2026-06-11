import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const faqs = [
    {'q': 'Come posso effettuare un ordine?', 'a': 'Scegli il prodotto, seleziona la variante, aggiungilo al carrello e completa il pagamento tramite carta di credito o debito.'},
    {'q': 'Quanto tempo ci vuole per la spedizione?', 'a': 'Le spedizioni vengono effettuate tramite Poste Italiane. I tempi di consegna sono solitamente 2-4 giorni lavorativi.'},
    {'q': 'Posso ritirare il prodotto in negozio?', 'a': 'Sì! Puoi scegliere il ritiro in negozio presso Top Phone Torre, Via Nazionale 68, Torre del Greco. Il ritiro è gratuito.'},
    {'q': 'Come funziona il sistema di cashback?', 'a': 'Ad ogni acquisto accumuli punti cashback. I punti possono essere convertiti in coupon sconto da utilizzare nei prossimi acquisti.'},
    {'q': 'Posso restituire un prodotto?', 'a': 'Sì, hai 14 giorni di tempo per restituire il prodotto. Il prodotto deve essere sigillato, non attivato e nelle condizioni originali. Le spese di spedizione per il reso sono a carico del cliente. Contattaci al numero 081 341 7717 per avviare la procedura.'},
    {'q': 'Quanto costano le spedizioni?', 'a': 'Le spedizioni tramite Poste Italiane hanno un costo fisso di 10 euro. Il ritiro in negozio è gratuito.'},
    {'q': 'I pagamenti sono sicuri?', 'a': 'Sì! Utilizziamo Stripe, uno dei sistemi di pagamento più sicuri al mondo. I tuoi dati della carta non vengono mai salvati sui nostri server.'},
    {'q': 'Cosa succede se il prodotto è esaurito?', 'a': 'Se un prodotto si esaurisce durante il checkout, il pagamento viene automaticamente rimborsato entro 5-10 giorni lavorativi.'},
    {'q': 'Come posso contattarvi?', 'a': 'Puoi contattarci al numero 081 341 7717, via WhatsApp o visitarci in negozio a Via Nazionale 68, Torre del Greco.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('FAQ', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, i) {
          final faq = faqs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.help_outline_rounded, color: Colors.indigo, size: 18),
              ),
              title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')),
              children: [
                Text(faq['a']!, style: const TextStyle(fontSize: 13, color: AppTheme.grey, fontFamily: 'Poppins', height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
