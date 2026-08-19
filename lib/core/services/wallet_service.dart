import '../../shared/models/wallet_transaction.dart';
import 'firebase_rtdb_service.dart';

class WalletService {
  static double get balance => 1250.0;

  static Future<List<WalletTransaction>> getTransactions() async {
    return FirebaseRtdbService.streamWalletTransactions('user_01').first;
  }

  static Future<bool> addMoney(double amount) async {
    await FirebaseRtdbService.topUpWallet('user_01', amount);
    return true;
  }

  static Future<bool> deductMoney(double amount, String reason) async {
    return true;
  }
}
