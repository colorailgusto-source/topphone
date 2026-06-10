class ProductModel {
  final String id;
  final String nome;
  final String descrizione;
  final String marca;
  final double prezzo;
  final int stock;
  final String immagine;
  final int? vendite;
  ProductModel({required this.id, required this.nome, required this.descrizione, required this.marca, required this.prezzo, required this.stock, required this.immagine, this.vendite});
  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'], nome: json['nome'] ?? '', descrizione: json['descrizione'] ?? '',
    marca: json['marca'] ?? '', prezzo: (json['prezzo'] ?? 0).toDouble(),
    stock: json['stock'] ?? 0, immagine: json['immagine'] ?? '', vendite: json['vendite'] as int?,
  );
}
