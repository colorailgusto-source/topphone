import 'package:flutter_test/flutter_test.dart';
import 'package:topphone/services/cart_service.dart';
import 'package:topphone/models/cart_item_model.dart';
import 'package:topphone/models/product_model.dart';
import 'package:topphone/models/variant_model.dart';

ProductModel makeProduct({String id = 'p1', double prezzo = 100, int stock = 10}) {
  return ProductModel(
    id: id,
    nome: 'Prodotto \$id',
    descrizione: '',
    marca: 'TestBrand',
    prezzo: prezzo,
    stock: stock,
    immagine: '',
  );
}

VariantModel makeVariant({String id = 'v1', String prodottoId = 'p1', double prezzoExtra = 0, int stock = 5}) {
  return VariantModel(
    id: id,
    prodottoId: prodottoId,
    ram: '8GB',
    memoria: '256GB',
    colore: 'Nero',
    stock: stock,
    prezzoExtra: prezzoExtra,
  );
}

CartItemModel makeItem({
  required ProductModel product,
  VariantModel? variant,
  int quantita = 1,
}) {
  return CartItemModel(
    id: 'cart_test',
    product: product,
    variant: variant,
    quantita: quantita,
    scadenza: DateTime.now().add(const Duration(minutes: 5)),
  );
}

void main() {
  group('CartService - regole carrello', () {
    test('carrello vuoto: hasItems false, count 0, total 0', () {
      final cart = CartService();
      cart.setItemsForTest([]);
      expect(cart.hasItems, false);
      expect(cart.count, 0);
      expect(cart.total, 0.0);
      expect(cart.isFull, false);
    });

    test('count somma le quantita', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1'), quantita: 2),
        makeItem(product: makeProduct(id: 'p2'), quantita: 3),
      ]);
      expect(cart.count, 5);
    });

    test('total considera prezzo prodotto + prezzoExtra variante', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(
          product: makeProduct(id: 'p1', prezzo: 100),
          variant: makeVariant(id: 'v1', prezzoExtra: 20),
          quantita: 2,
        ),
      ]);
      expect(cart.total, 240.0);
    });

    test('isFull true quando si raggiunge maxItems (3)', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1')),
        makeItem(product: makeProduct(id: 'p2')),
        makeItem(product: makeProduct(id: 'p3')),
      ]);
      expect(cart.isFull, true);
    });
  });

  group('CartService - cannotAddReason', () {
    test('carrello pieno: blocca il quarto prodotto', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1')),
        makeItem(product: makeProduct(id: 'p2')),
        makeItem(product: makeProduct(id: 'p3')),
      ]);
      final reason = cart.cannotAddReason(makeProduct(id: 'p4'));
      expect(reason, contains('pieno'));
    });

    test('duplicato esatto (stesso prodotto, stessa variante): bloccato', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1'), variant: makeVariant(id: 'v1')),
      ]);
      final reason = cart.cannotAddReason(
        makeProduct(id: 'p1'),
        variant: makeVariant(id: 'v1'),
      );
      expect(reason, contains('già nel carrello'));
    });

    test('stesso prodotto, variante diversa: permesso', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1'), variant: makeVariant(id: 'v_nero')),
      ]);
      final reason = cart.cannotAddReason(
        makeProduct(id: 'p1'),
        variant: makeVariant(id: 'v_bianco'),
      );
      expect(reason, isNull);
    });

    test('prodotto diverso: permesso', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1')),
      ]);
      final reason = cart.cannotAddReason(makeProduct(id: 'p2'));
      expect(reason, isNull);
    });

    test('prodotto senza variante gia presente: bloccato come duplicato', () {
      final cart = CartService();
      cart.setItemsForTest([
        makeItem(product: makeProduct(id: 'p1')),
      ]);
      final reason = cart.cannotAddReason(makeProduct(id: 'p1'));
      expect(reason, contains('già nel carrello'));
    });
  });
}
