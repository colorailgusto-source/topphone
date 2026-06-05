class OrderModel {
  final String id;
  final String utenteId;
  final double totale;
  final String stato;
  final String? tracking;
  final String? note;
  final DateTime data;
  OrderModel({required this.id, required this.utenteId, required this.totale, required this.stato, this.tracking, this.note, required this.data});
  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id: json['id'], utenteId: json['utente_id'],
    totale: (json['totale'] ?? 0).toDouble(), stato: json['stato'] ?? 'ricevuto',
    tracking: json['tracking'], note: json['note'],
    data: DateTime.parse(json['data'] ?? DateTime.now().toIso8601String()),
  );
}
