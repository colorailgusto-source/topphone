import 'product_model.dart';
import 'variant_model.dart';

class CartItemModel {
  final String id;
  final ProductModel product;
  final VariantModel? variant;
  int quantita;
  DateTime scadenza;
  CartItemModel({required this.id, required this.product, this.variant, required this.quantita, required this.scadenza});
  bool get isExpired => DateTime.now().isAfter(scadenza);
  Duration get remaining => scadenza.difference(DateTime.now());
  void resetTimer() { scadenza = DateTime.now().add(const Duration(minutes: 10)); }
  double get prezzoTotale => (product.prezzo + (variant?.prezzoExtra ?? 0)) * quantita;
  String get variantLabel => variant?.label ?? '';
}
