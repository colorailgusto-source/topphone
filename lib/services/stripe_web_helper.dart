import 'dart:js_interop';

class CancelledException implements Exception {}

@JS('createPaymentOverlay')
external JSPromise<JSString> _createPaymentOverlay(
    JSString publishableKey, JSString clientSecret, JSString amountText);

Future<void> presentPaymentSheet({
  required String clientSecret,
  required String publishableKey,
  double amount = 0,
}) async {
  final amountText = '\u20AC ${amount.toStringAsFixed(2)}';
  final result = await _createPaymentOverlay(
    publishableKey.toJS,
    clientSecret.toJS,
    amountText.toJS,
  ).toDart;

  final resultStr = result.toDart;
  if (resultStr == 'cancelled') {
    throw CancelledException();
  }
}

bool isCancelled(dynamic e) {
  return e is CancelledException;
}
