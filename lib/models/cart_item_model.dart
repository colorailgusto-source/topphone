import 'product_model.dart';
import 'variant_model.dart';

class CartItemModel {
  final String? id;
  final ProductModel product;
  final VariantModel? variant;
  final int quantita;
  final DateTime scadenza;

  CartItemModel({
    this.id,
    required this.product,
    this.variant,
    required this.quantita,
    required this.scadenza,
  });

  bool get isExpired => DateTime.now().isAfter(scadenza);

  Duration get remaining {
    final now = DateTime.now().toUtc();
    final scadenzaUtc = scadenza.toUtc();
    final diff = scadenzaUtc.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  void resetTimer() {}
}
