import 'dart:async';
import 'package:demo_ai_even/services/g2_text_service.dart';

class TextService {
  static TextService? _instance;
  static TextService get get => _instance ??= TextService._();
  static bool isRunning = false;
  static int maxRetry = 5;
  static Timer? _timer;
  static List<String> list = [];
  static List<String> sendReplys = [];

  TextService._(); 

  Future startSendText(String text) async {
    isRunning = true;

    // Use G2 protocol for text transfer
    print('TextService: Using G2 protocol for text transfer');
    try {
      final success = await G2TextService.instance.sendText(text);
      if (success) {
        print('TextService: Text sent successfully using G2 protocol');
      } else {
        print('TextService: Failed to send text using G2 protocol');
        clear();
      }
    } catch (e) {
      print('TextService: Error sending text: $e');
      clear();
    }
  }

  // Stop sending and clear state
  Future stopTextSendingByOS() async {
    print("stopTextSendingByOS---------------");
    isRunning = false;
    G2TextService.instance.stop();
    clear();
  }

  void clear() {
    isRunning = false;
    _timer?.cancel();
    _timer = null;
    list = [];
    sendReplys = [];
  }
}
