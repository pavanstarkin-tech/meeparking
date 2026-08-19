import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/env_config.dart';

class RazorpayService {
  Razorpay? _razorpay;
  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onFailure;
  Function(ExternalWalletResponse)? onExternalWallet;

  void init({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    this.onSuccess = onSuccess;
    this.onFailure = onFailure;
    this.onExternalWallet = onExternalWallet;

    if (!kIsWeb) {
      try {
        _razorpay = Razorpay();
        _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
        _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
        _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      } catch (e) {
        debugPrint('Razorpay init error: $e');
      }
    }
  }

  void openCheckout({
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
  }) {
    if (kIsWeb) {
      // In Flutter Web environment, simulate successful checkout or mock response
      onSuccess?.call(PaymentSuccessResponse(
        'pay_${DateTime.now().millisecondsSinceEpoch}',
        'order_${DateTime.now().millisecondsSinceEpoch}',
        'sig_mock',
        {},
      ));
      return;
    }

    final options = {
      'key': EnvConfig.razorpayKeyId,
      'amount': (amount * 100).toInt(), // Amount in paise
      'name': name,
      'description': description,
      'prefill': {'contact': contact, 'email': email},
      'external': {
        'wallets': ['paytm', 'gpay']
      }
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onExternalWallet?.call(response);
  }

  void dispose() {
    try {
      _razorpay?.clear();
    } catch (_) {}
  }
}
