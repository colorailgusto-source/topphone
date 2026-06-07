import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Termini e Condizioni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF01579B), Color(0xFF0288D1)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('1. Informazioni Generali', 'Top Phone Torre è un negozio di telefonia e accessori con sede in Via Nazionale 68, Torre del Greco (NA). Questi termini e condizioni regolano l\'utilizzo dell\'app e l\'acquisto di prodotti tramite la stessa.'),
          _section('2. Prodotti e Prezzi', 'Tutti i prezzi indicati sono in Euro e includono IVA. Top Phone Torre si riserva il diritto di modificare i prezzi in qualsiasi momento. Il prezzo applicato sarà quello indicato al momento dell\'ordine.'),
          _section('3. Ordini e Pagamenti', 'Gli ordini possono essere effettuati tramite l\'app. I pagamenti vengono processati in modo sicuro tramite Stripe. Accettiamo carte di credito/debito, Google Pay e altri metodi disponibili.'),
          _section('4. Spedizioni', 'Le spedizioni vengono effettuate entro 24-48 ore lavorative dalla conferma del pagamento. Le spese di spedizione sono di €10,00. Top Phone Torre non è responsabile per ritardi causati dal corriere.'),
          _section('5. Ritiro in Negozio', 'È possibile ritirare il prodotto direttamente presso il nostro negozio in Via Nazionale 68, Torre del Greco. Riceverai una notifica quando il prodotto è pronto per il ritiro.'),
          _section('6. Garanzia', 'I prodotti venduti da Top Phone Torre sono coperti da garanzia legale secondo le seguenti modalità:\n\n• Prodotti Android e altri brand: 24 mesi di garanzia legale ai sensi del D.Lgs. 206/2005.\n\n• Prodotti Apple (iPhone, iPad, ecc.): 12 mesi di garanzia. Per assistenza in garanzia su prodotti Apple, il cliente dovrà recarsi direttamente presso un Apple Store o un Centro Assistenza Autorizzato Apple (AASP). Top Phone Torre non effettua riparazioni su prodotti Apple in garanzia.'),
          _section('7. Cambi e Resi', 'Top Phone Torre accetta cambi e resi secondo le seguenti condizioni:\n\n• Malfunzionamento del prodotto: il cambio è accettato esclusivamente per difetti di fabbrica o malfunzionamenti tecnici documentati, previa verifica da parte del nostro personale.\n\n• Prodotti Apple: in caso di malfunzionamento, il cliente deve rivolgersi direttamente a un Centro Assistenza Autorizzato Apple. Top Phone Torre non gestisce cambi o resi per malfunzionamenti di prodotti Apple.\n\n• Cambio per insoddisfazione: è possibile richiedere il cambio del prodotto entro 14 giorni dall\'acquisto, a condizione che il prodotto non sia stato attivato, aperto dalla confezione originale o utilizzato in alcun modo. Il prodotto deve essere restituito integro, nella confezione originale sigillata con tutti gli accessori inclusi.\n\n• Spese di reso: le spese di spedizione per la restituzione del prodotto sono sempre a carico dell\'acquirente, indipendentemente dal motivo del reso.'),
          _section('8. Diritto di Recesso', 'Ai sensi del D.Lgs. 206/2005, hai il diritto di recedere dall\'acquisto entro 14 giorni dalla ricezione del prodotto senza dover fornire alcuna motivazione, a condizione che il prodotto non sia stato attivato, aperto o utilizzato. Le spese di restituzione sono a carico dell\'acquirente.'),
          _section('9. Privacy e Dati Personali', 'I tuoi dati personali vengono trattati nel rispetto del GDPR (Regolamento UE 2016/679). I dati vengono utilizzati esclusivamente per la gestione degli ordini e non vengono ceduti a terzi, ad eccezione dei servizi necessari all\'elaborazione dei pagamenti.'),
          _section('10. Responsabilità', 'Top Phone Torre non è responsabile per danni indiretti o conseguenti derivanti dall\'utilizzo dei prodotti acquistati. La responsabilità massima è limitata al valore del prodotto acquistato.'),
          _section('11. Contatti', 'Per qualsiasi informazione, reclamo o assistenza:\n\nTop Phone Torre\nVia Nazionale 68, Torre del Greco (NA)\nTel: 081 341 7717\nWhatsApp: 081 341 7717\nEmail: topphoneportici@gmail.com'),
          const SizedBox(height: 8),
          const Text('Ultimo aggiornamento: Giugno 2026', style: TextStyle(color: AppTheme.grey, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0288D1), fontFamily: 'Poppins')),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)),
      ]),
    );
  }
}
