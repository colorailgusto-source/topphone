class ProductModel {
  final String id;
  final String nome;
  final String descrizione;
  final String marca;
  final double prezzo;
  final int stock;
  final String immagine;
  final int? vendite;
  final int? batteriaMah;
  final int? fotocameraMp;
  final double? schermoPollici;
  final String? processore;
  ProductModel(
      {required this.id,
      required this.nome,
      required this.descrizione,
      required this.marca,
      required this.prezzo,
      required this.stock,
      required this.immagine,
      this.vendite,
      this.batteriaMah,
      this.fotocameraMp,
      this.schermoPollici,
      this.processore});
  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'],
        nome: json['nome'] ?? '',
        descrizione: json['descrizione'] ?? '',
        marca: json['marca'] ?? '',
        prezzo: (json['prezzo'] ?? 0).toDouble(),
        stock: json['stock'] ?? 0,
        immagine: json['immagine'] ?? '',
        vendite: json['vendite'] as int?,
        batteriaMah: json['batteria_mah'] as int?,
        fotocameraMp: json['fotocamera_mp'] as int?,
        schermoPollici: (json['schermo_pollici'] as num?)?.toDouble(),
        processore: json['processore'] as String?,
      );
}
