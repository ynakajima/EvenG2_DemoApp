import 'dart:typed_data';

/// Even G2 Protocol Implementation
/// Based on: https://github.com/i-soxi/even-g2-protocol
class G2Protocol {
  /// CRC-16/CCITT calculation
  /// Init: 0xFFFF, Polynomial: 0x1021
  /// Input: Payload bytes only (skip 8-byte header)
  /// Output: Little-endian
  static int crc16Ccitt(Uint8List data, {int init = 0xFFFF}) {
    int crc = init;
    for (var byte in data) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  /// Add CRC to packet (calculated over payload, stored little-endian)
  static Uint8List addCrc(Uint8List packet) {
    // CRC is calculated over payload only (skip 8-byte header)
    final payload = packet.sublist(8);
    final crc = crc16Ccitt(payload);
    
    final result = Uint8List(packet.length + 2);
    result.setAll(0, packet);
    result[packet.length] = crc & 0xFF; // CRC low byte
    result[packet.length + 1] = (crc >> 8) & 0xFF; // CRC high byte
    
    return result;
  }

  /// Encode integer as protobuf varint
  static Uint8List encodeVarint(int value) {
    List<int> result = [];
    while (value > 0x7F) {
      result.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    result.add(value & 0x7F);
    return Uint8List.fromList(result);
  }

  /// Build a complete packet with header and CRC
  /// - seq: Sequence ID (incrementing counter 0-255)
  /// - serviceHi: Service ID high byte
  /// - serviceLo: Service ID low byte
  /// - payload: Payload bytes (protobuf-encoded)
  static Uint8List buildPacket(int seq, int serviceHi, int serviceLo, Uint8List payload) {
    final header = Uint8List.fromList([
      0xAA, // Magic
      0x21, // Type (Command: Phone -> Glasses)
      seq & 0xFF, // Sequence ID
      (payload.length + 2) & 0xFF, // Length (includes CRC)
      0x01, // Packet Total (usually 1)
      0x01, // Packet Serial (usually 1)
      serviceHi & 0xFF, // Service Hi
      serviceLo & 0xFF, // Service Lo
    ]);
    
    final packet = Uint8List(header.length + payload.length);
    packet.setAll(0, header);
    packet.setAll(header.length, payload);
    
    return addCrc(packet);
  }

  /// Build the 7-packet authentication sequence
  static List<Uint8List> buildAuthPackets() {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tsVarint = encodeVarint(timestamp);
    final txid = Uint8List.fromList([0xE8, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]);
    
    List<Uint8List> packets = [];
    
    // Auth 1: Capability query
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x01, 0x0C, 0x01, 0x01, 0x80, 0x00,
      0x08, 0x04, 0x10, 0x0C, 0x1A, 0x04, 0x08, 0x01, 0x10, 0x04
    ])));
    
    // Auth 2: Capability response request
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x02, 0x0A, 0x01, 0x01, 0x80, 0x20,
      0x08, 0x05, 0x10, 0x0E, 0x22, 0x02, 0x08, 0x02
    ])));
    
    // Auth 3: Time sync with transaction ID
    final payload3 = Uint8List.fromList([
      0x08, 0x80, 0x01, 0x10, 0x0F, 0x82, 0x08, 0x11, 0x08,
      ...tsVarint,
      0x10,
      ...txid
    ]);
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x03, (payload3.length + 2) & 0xFF, 0x01, 0x01, 0x80, 0x20,
      ...payload3
    ])));
    
    // Auth 4-5: Additional capability exchanges
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x04, 0x0C, 0x01, 0x01, 0x80, 0x00,
      0x08, 0x04, 0x10, 0x10, 0x1A, 0x04, 0x08, 0x01, 0x10, 0x04
    ])));
    
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x05, 0x0C, 0x01, 0x01, 0x80, 0x00,
      0x08, 0x04, 0x10, 0x11, 0x1A, 0x04, 0x08, 0x01, 0x10, 0x04
    ])));
    
    // Auth 6: Final capability
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x06, 0x0A, 0x01, 0x01, 0x80, 0x20,
      0x08, 0x05, 0x10, 0x12, 0x22, 0x02, 0x08, 0x01
    ])));
    
    // Auth 7: Final time sync
    final payload7 = Uint8List.fromList([
      0x08, 0x80, 0x01, 0x10, 0x13, 0x82, 0x08, 0x11, 0x08,
      ...tsVarint,
      0x10,
      ...txid
    ]);
    packets.add(addCrc(Uint8List.fromList([
      0xAA, 0x21, 0x07, (payload7.length + 2) & 0xFF, 0x01, 0x01, 0x80, 0x20,
      ...payload7
    ])));
    
    return packets;
  }

  /// Build display configuration packet
  /// Service 0x0E-20: Display configuration
  static Uint8List buildDisplayConfig(int seq, int msgId) {
    final config = _hexToBytes(
      "0801121308021090" "4E1D00E094442500" "000000280030001213"
      "0803100D0F1D0040" "8D44250000000028" "0030001212080410"
      "001D0000884225" "00000000280030" "001212080510001D"
      "00009242250000" "A242280030001212" "080610001D0000C6"
      "42250000C4422800" "30001800"
    );
    
    final payload = Uint8List.fromList([
      0x08, 0x02, 0x10,
      ...encodeVarint(msgId),
      0x22, 0x6A,
      ...config
    ]);
    
    return buildPacket(seq, 0x0E, 0x20, payload);
  }

  /// Build teleprompter init packet
  /// Service 0x06-20 type=1: Initialize teleprompter
  static Uint8List buildTeleprompterInit(int seq, int msgId, int totalLines, {bool manualMode = true}) {
    final mode = manualMode ? 0x00 : 0x01;
    
    // Scale content height based on line count (Bee Movie: 140 lines = 2665)
    final contentHeight = (totalLines * 2665 / 140).ceil().clamp(1, 65535);
    
    final display = Uint8List.fromList([
      0x08, 0x01, 0x10, 0x00, 0x18, 0x00, 0x20, 0x8B, 0x02, // Fixed settings
      0x28, ...encodeVarint(contentHeight), // Content height
      0x30, 0xE6, 0x01, // Line height = 230
      0x38, 0x8E, 0x0A, // Viewport = 1294
      0x40, 0x05, 0x48, mode // Font size + mode
    ]);
    
    // Settings block: script_index=1, display settings
    final settings = Uint8List.fromList([
      0x08, 0x01, // Script index = 1
      0x12, display.length, // Display settings sub-field
      ...display
    ]);
    
    final payload = Uint8List.fromList([
      0x08, 0x01, // Type = 1 (init)
      0x10, ...encodeVarint(msgId), // msg_id
      0x1A, settings.length, // Settings field
      ...settings
    ]);
    
    return buildPacket(seq, 0x06, 0x20, payload);
  }

  /// Build content page packet
  /// Service 0x06-20 type=3: Content page
  static Uint8List buildContentPage(int seq, int msgId, int pageNum, String text) {
    final textBytes = Uint8List.fromList('\n$text'.codeUnits);
    
    final inner = Uint8List.fromList([
      0x08, ...encodeVarint(pageNum),
      0x10, 0x0A, // 10 lines
      0x1A, ...encodeVarint(textBytes.length),
      ...textBytes
    ]);
    
    final content = Uint8List.fromList([
      0x2A, ...encodeVarint(inner.length),
      ...inner
    ]);
    
    final payload = Uint8List.fromList([
      0x08, 0x03, 0x10,
      ...encodeVarint(msgId),
      ...content
    ]);
    
    return buildPacket(seq, 0x06, 0x20, payload);
  }

  /// Build mid-stream marker packet
  /// Service 0x06-20 type=255: Mid-stream marker
  static Uint8List buildMarker(int seq, int msgId) {
    final payload = Uint8List.fromList([
      0x08, 0xFF, 0x01, 0x10,
      ...encodeVarint(msgId),
      0x6A, 0x04, 0x08, 0x00, 0x10, 0x06
    ]);
    
    return buildPacket(seq, 0x06, 0x20, payload);
  }

  /// Build sync/trigger packet
  /// Service 0x80-00 type=14: Sync/trigger
  static Uint8List buildSync(int seq, int msgId) {
    final payload = Uint8List.fromList([
      0x08, 0x0E, 0x10,
      ...encodeVarint(msgId),
      0x6A, 0x00
    ]);
    
    return buildPacket(seq, 0x80, 0x00, payload);
  }

  /// Format text into pages of wrapped lines
  /// - charsPerLine: Maximum characters per line (default: 25)
  /// - linesPerPage: Lines per page (default: 10)
  static List<String> formatText(String text, {int charsPerLine = 25, int linesPerPage = 10}) {
    final lines = text.split('\n');
    final wrappedLines = <String>[];
    
    for (var line in lines) {
      if (line.isEmpty) {
        wrappedLines.add('');
        continue;
      }
      
      final words = line.split(' ');
      String currentLine = '';
      
      for (var word in words) {
        if (currentLine.isEmpty) {
          currentLine = word;
        } else if ((currentLine.length + 1 + word.length) <= charsPerLine) {
          currentLine += ' $word';
        } else {
          wrappedLines.add(currentLine);
          currentLine = word;
        }
      }
      
      if (currentLine.isNotEmpty) {
        wrappedLines.add(currentLine);
      }
    }
    
    // Pad to minimum 14 pages (140 lines)
    const minLines = 140;
    while (wrappedLines.length < minLines) {
      wrappedLines.add(' '); // Add space lines for padding
    }
    
    // Split into pages
    final pages = <String>[];
    for (var i = 0; i < wrappedLines.length; i += linesPerPage) {
      final end = (i + linesPerPage < wrappedLines.length) 
          ? i + linesPerPage 
          : wrappedLines.length;
      final pageLines = wrappedLines.sublist(i, end);
      
      // Pad page to 10 lines if needed
      while (pageLines.length < linesPerPage) {
        pageLines.add(' ');
      }
      
      pages.add(pageLines.join('\n') + ' \n');
    }
    
    return pages;
  }

  /// Helper: Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
