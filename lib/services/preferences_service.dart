import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUtils {
  Future<void> cleanOldPlaybackPositions() async {
    // SharedPreferences obyektini olish
    final prefs = await SharedPreferences.getInstance();

    // Barcha kalitlarni olish va playback_position_ bilan boshlanuvchi kalitlarni filtrlash
    final keys = prefs.getKeys();
    final playbackKeys =
        keys.where((key) => key.startsWith('playback_position_')).toList();

    // Hozirgi vaqtni olish
    final now = DateTime.now().millisecondsSinceEpoch;

    // 30 kunlik maksimal muddatni aniqlash
    const maxAge = 30 * 24 * 60 * 60 * 1000; // 30 kun (millisekund)

    // Kalitlarni parallel o'chirish
    final futures = playbackKeys.map((key) async {
      final keyTimestamp = '${key}_timestamp';
      final lastModified = prefs.getInt(keyTimestamp) ?? now - maxAge - 1;

      if (now - lastModified > maxAge) {
        try {
          await prefs.remove(key);
          if (keys.contains(keyTimestamp)) {
            await prefs.remove(keyTimestamp);
          }
          debugPrint("O'chirildi: $key, timestamp: $lastModified");
          return 1; // O'chirilgan kalit
        } catch (e) {
          debugPrint("Kalitni o'chirishda xato: $key, xato: $e");
        }
      }
      return 0; // O'chirilmagan kalit
    });

    // Barcha o'chirish ishlarini yakunlash va natijalarni yig'ish
    final results = await Future.wait(futures);
    final deletedCount = results.reduce((a, b) => a + b);

    // O'chirilgan kalitlar sonini log qilish
    if (deletedCount > 0) {
      debugPrint("$deletedCount ta eski kalit o'chirildi");
    } else {
      debugPrint("O'chirish uchun eski kalitlar topilmadi");
    }
  }
}
