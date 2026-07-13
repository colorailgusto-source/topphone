class VariantModel {
  final String id;
  final String prodottoId;
  final String ram;
  final String memoria;
  final String colore;
  int stock;
  final double prezzoExtra;
  VariantModel(
      {required this.id,
      required this.prodottoId,
      required this.ram,
      required this.memoria,
      required this.colore,
      required this.stock,
      required this.prezzoExtra});
  factory VariantModel.fromJson(Map<String, dynamic> json) => VariantModel(
        id: json['id'],
        prodottoId: json['prodotto_id'],
        ram: json['ram'] ?? '',
        memoria: json['memoria'] ?? '',
        colore: json['colore'] ?? '',
        stock: json['stock'] ?? 0,
        prezzoExtra: (json['prezzo_extra'] ?? 0).toDouble(),
      );
  String get label {
    final parts = <String>[];
    if (ram.isNotEmpty) parts.add(ram);
    if (memoria.isNotEmpty) parts.add(memoria);
    if (colore.isNotEmpty) parts.add(colore);
    return parts.join(' / ');
  }
}
