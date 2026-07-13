import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> presentPaymentSheet({
  required String clientSecret,
  required String publishableKey,
  double amount = 0,
}) async {
  Stripe.publishableKey = publishableKey;
  await Stripe.instance.applySettings();
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: 'Top Phone Torre',
      style: ThemeMode.light,
      googlePay: const PaymentSheetGooglePay(
        merchantCountryCode: 'IT',
        currencyCode: 'EUR',
        testEnv: false,
      ),
      appearance: const PaymentSheetAppearance(
        colors: PaymentSheetAppearanceColors(primary: Color(0xFF0288D1)),
      ),
    ),
  );
  await Stripe.instance.presentPaymentSheet();
}

bool isCancelled(dynamic e) {
  if (e is StripeException) {
    return e.error.code == FailureCode.Canceled;
  }
  return false;
}
