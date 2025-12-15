import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Generate URL-safe random hash string similar to examples.
/// length parameter controls final string length (default 32).
String generateHash({int length = 32}) {
  final rnd = Random.secure();
  final bytes = Uint8List(length);
  for (int i = 0; i < bytes.length; i++) {
    bytes[i] = rnd.nextInt(256);
  }
  // base64Url gives characters similar to your example; remove padding.
  String s = base64UrlEncode(bytes).replaceAll('=', '');
  // ensure length: if shorter, regenerate a bit; if longer, cut.
  if (s.length >= length) {
    return s.substring(0, length);
  } else {
    // pad with additional random chars if needed
    while (s.length < length) {
      s += base64UrlEncode([rnd.nextInt(256)]).replaceAll('=', '');
    }
    return s.substring(0, length);
  }
}
