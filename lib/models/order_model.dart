class OrderModel {
  final String id;
  final String utente_id;
  final double totale;
  final String stato;
  final String? tracking;
  final String? note;
  final DateTime data;
  final String? tipoConsegna;
  List<Map<String, dynamic>>? righe;

  OrderModel({
    required this.id,
    required this.utente_id,
    required this.totale,
    required this.stato,
    this.tracking,
    this.note,
    required this.data,
    this.tipoConsegna,
    this.righe,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      utente_id: json['utente_id'] ?? '',
      totale: (json['totale'] ?? 0).toDouble(),
      stato: json['stato'] ?? 'ricevuto',
      tracking: json['tracking'],
      note: json['note'],
      tipoConsegna: json['tipo_consegna'],
      data: DateTime.tryParse(json['data'] ?? '') ?? DateTime.now(),
    );
  }
}