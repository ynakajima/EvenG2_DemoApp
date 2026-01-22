import 'dart:async';
import 'dart:typed_data';
import 'package:demo_ai_even/ble_manager.dart';
import 'package:demo_ai_even/services/g2_protocol.dart';

/// G2 Text Transfer Service
/// Implements the teleprompter protocol for G2 glasses
class G2TextService {
  static G2TextService? _instance;
  static G2TextService get instance => _instance ??= G2TextService._();
  
  int _seq = 0x08; // Start at 8 (after auth sequence)
  int _msgId = 0x14; // Message ID counter (starts at 20)
  bool _isAuthenticated = false;
  bool _isSending = false;

  G2TextService._();

  /// Send text to G2 glasses
  Future<bool> sendText(String text) async {
    if (_isSending) {
      print('G2TextService: Already sending text');
      return false;
    }

    _isSending = true;

    try {
      // Step 1: Authenticate if not already authenticated
      if (!_isAuthenticated) {
        print('G2TextService: Authenticating...');
        final authSuccess = await _authenticate();
        if (!authSuccess) {
          print('G2TextService: Authentication failed');
          return false;
        }
        _isAuthenticated = true;
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Step 2: Format text into pages
      print('G2TextService: Formatting text...');
      final pages = G2Protocol.formatText(text);
      final totalLines = text.split('\n').length;
      print('G2TextService: Created ${pages.length} pages from $totalLines lines');

      // Step 3: Display config
      print('G2TextService: Sending display config...');
      final displayConfig = G2Protocol.buildDisplayConfig(_seq, _msgId);
      final configSuccess = await _sendToBothEyes(displayConfig, noResponse: true);
      if (!configSuccess) {
        print('G2TextService: Display config failed');
        return false;
      }
      _seq++;
      _msgId++;
      await Future.delayed(Duration(milliseconds: 300));

      // Step 4: Teleprompter init
      print('G2TextService: Initializing teleprompter...');
      final initPacket = G2Protocol.buildTeleprompterInit(_seq, _msgId, totalLines);
      final initSuccess = await _sendToBothEyes(initPacket, noResponse: true);
      if (!initSuccess) {
        print('G2TextService: Teleprompter init failed');
        return false;
      }
      _seq++;
      _msgId++;
      await Future.delayed(Duration(milliseconds: 500));

      // Step 5: Send content pages 0-9
      print('G2TextService: Sending pages 0-9...');
      for (var i = 0; i < pages.length && i < 10; i++) {
        final pagePacket = G2Protocol.buildContentPage(_seq, _msgId, i, pages[i]);
        final pageSuccess = await _sendToBothEyes(pagePacket, noResponse: true);
        if (!pageSuccess) {
          print('G2TextService: Failed to send page $i');
          return false;
        }
        _seq++;
        _msgId++;
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Step 6: Mid-stream marker
      print('G2TextService: Sending mid-stream marker...');
      final marker = G2Protocol.buildMarker(_seq, _msgId);
      final markerSuccess = await _sendToBothEyes(marker, noResponse: true);
      if (!markerSuccess) {
        print('G2TextService: Marker failed');
        return false;
      }
      _seq++;
      _msgId++;
      await Future.delayed(Duration(milliseconds: 100));

      // Step 7: Send pages 10-11
      if (pages.length > 10) {
        print('G2TextService: Sending pages 10-11...');
        for (var i = 10; i < pages.length && i < 12; i++) {
          final pagePacket = G2Protocol.buildContentPage(_seq, _msgId, i, pages[i]);
          final pageSuccess = await _sendToBothEyes(pagePacket, noResponse: true);
          if (!pageSuccess) {
            print('G2TextService: Failed to send page $i');
            return false;
          }
          _seq++;
          _msgId++;
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      // Step 8: Sync trigger
      print('G2TextService: Sending sync trigger...');
      final sync = G2Protocol.buildSync(_seq, _msgId);
      final syncSuccess = await _sendToBothEyes(sync, noResponse: true);
      if (!syncSuccess) {
        print('G2TextService: Sync failed');
        return false;
      }
      _seq++;
      _msgId++;
      await Future.delayed(Duration(milliseconds: 100));

      // Step 9: Send remaining pages
      if (pages.length > 12) {
        print('G2TextService: Sending remaining pages...');
        for (var i = 12; i < pages.length; i++) {
          final pagePacket = G2Protocol.buildContentPage(_seq, _msgId, i, pages[i]);
          final pageSuccess = await _sendToBothEyes(pagePacket, noResponse: true);
          if (!pageSuccess) {
            print('G2TextService: Failed to send page $i');
            return false;
          }
          _seq++;
          _msgId++;
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      print('G2TextService: Text sent successfully! Check your glasses.');
      return true;
      
    } catch (e) {
      print('G2TextService: Error sending text: $e');
      return false;
    } finally {
      _isSending = false;
    }
  }

  /// Authenticate with G2 glasses (7-packet sequence)
  Future<bool> _authenticate() async {
    try {
      final authPackets = G2Protocol.buildAuthPackets();
      print('G2TextService: Sending ${authPackets.length} auth packets...');
      
      for (var i = 0; i < authPackets.length; i++) {
        final packet = authPackets[i];
        print('G2TextService: Sending auth packet ${i + 1}/${authPackets.length}...');
        
        final success = await _sendToBothEyes(packet, noResponse: true);
        if (!success) {
          print('G2TextService: Auth packet ${i + 1} failed');
          return false;
        }
        
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      print('G2TextService: Authentication complete');
      return true;
      
    } catch (e) {
      print('G2TextService: Authentication error: $e');
      return false;
    }
  }

  /// Send packet to both eyes (L and R)
  Future<bool> _sendToBothEyes(Uint8List packet, {bool noResponse = false}) async {
    try {
      // Send to left eye
      final leftSuccess = await _sendPacket(packet, 'L', noResponse: noResponse);
      if (!leftSuccess) {
        print('G2TextService: Failed to send to left eye');
        return false;
      }
      
      // Small delay between eyes
      await Future.delayed(Duration(milliseconds: 10));
      
      // Send to right eye
      final rightSuccess = await _sendPacket(packet, 'R', noResponse: noResponse);
      if (!rightSuccess) {
        print('G2TextService: Failed to send to right eye');
        return false;
      }
      
      return true;
      
    } catch (e) {
      print('G2TextService: Error sending to both eyes: $e');
      return false;
    }
  }

  /// Send a single packet to one eye
  Future<bool> _sendPacket(Uint8List packet, String lr, {bool noResponse = false}) async {
    try {
      if (noResponse) {
        // For auth packets, just send without waiting for response
        await BleManager.sendData(packet, lr: lr);
        return true;
      } else {
        // For other packets, wait for response
        final response = await BleManager.request(packet, lr: lr, timeoutMs: 1500);
        if (response.isTimeout) {
          print('G2TextService: Timeout sending to $lr');
          return false;
        }
        // Check for success response (0xc9 or similar)
        if (response.data.length > 1) {
          final responseCode = response.data[1];
          if (responseCode == 0xc9 || responseCode == 0xcB) {
            return true;
          }
        }
        return true; // Consider success if we got any response
      }
    } catch (e) {
      print('G2TextService: Error sending packet to $lr: $e');
      return false;
    }
  }

  /// Reset authentication state
  void resetAuth() {
    _isAuthenticated = false;
    _seq = 0x08;
    _msgId = 0x14;
  }

  /// Stop any ongoing transmission
  void stop() {
    _isSending = false;
  }
}
