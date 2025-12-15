import 'package:better_player/better_player.dart';
import 'package:flutter/foundation.dart';

/// BetterPlayerController uchun xavfsiz pozitsiyani olish
Future<Duration?> safeGetPosition(BetterPlayerController? controller) async {
  try {
    if (controller?.videoPlayerController != null &&
        controller!.videoPlayerController!.value.initialized) {
      return await controller.videoPlayerController!.position;
    }
  } catch (e) {
    debugPrint("safeGetPosition xato: $e");
  }
  return null;
}

/// BetterPlayerController uchun xavfsiz pauza
Future<void> safePause(BetterPlayerController? controller) async {
  try {
    if (controller != null && controller.videoPlayerController != null) {
      await controller.pause();
    }
  } catch (e) {
    debugPrint("safePause xato: $e");
  }
}

/// BetterPlayerController uchun xavfsiz o'ynatish
Future<void> safePlay(BetterPlayerController? controller) async {
  try {
    if (controller != null && controller.videoPlayerController != null) {
      await controller.play();
    }
  } catch (e) {
    debugPrint("safePlay xato: $e");
  }
}

/// BetterPlayerController ni xavfsiz tarzda dispose qilish
Future<void> safeDispose(
  BetterPlayerController? controller, {
  void Function(BetterPlayerEvent)? onPlayerEvent,
  void Function(BetterPlayerEvent)? onFullscreenEvent,
}) async {
  try {
    if (controller != null) {
      await safePause(
        controller,
      ); // Pauza qilish (agar video o'ynayotgan bo'lsa)

      // Event listener'larni o'chirish
      if (onPlayerEvent != null) {
        controller.removeEventsListener(onPlayerEvent);
      }
      if (onFullscreenEvent != null) {
        controller.removeEventsListener(onFullscreenEvent);
      }

      // Controller'ni dispose qilish
      await controller.dispose();
    }
  } catch (e) {
    debugPrint("safeDispose xato: $e");
  }
}

/// BetterPlayerController uchun xavfsiz sifatni tanlash
Future<void> safeSetResolution(
  BetterPlayerController? controller,
  String? resolutionUrl,
) async {
  try {
    if (controller != null && resolutionUrl != null) {
      controller.setResolution(resolutionUrl);
      debugPrint("Resolution o'zgartirildi: $resolutionUrl");
    }
  } catch (e) {
    debugPrint("safeSetResolution xato: $e");
  }
}

/// BetterPlayerController ni xavfsiz tarzda qayta boshlash
Future<void> safeRestart(BetterPlayerController? controller) async {
  try {
    if (controller != null) {
      await controller.seekTo(Duration.zero);
      await controller.play();
      debugPrint("Player qayta boshlandi.");
    }
  } catch (e) {
    debugPrint("safeRestart xato: $e");
  }
}
