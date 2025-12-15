import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player/better_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:tplaytv/utils/video_helpers.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final bool liveStream;
  final bool autoPlay;
  final List<DeviceOrientation>? deviceOrientationsOnFullScreen;
  final List<DeviceOrientation>? deviceOrientationsAfterFullScreen;
  final bool? autoDetectFullscreenDeviceOrientation;
  final BetterPlayerControlsConfiguration? controlsConfiguration;
  final BetterPlayerNotificationConfiguration? notificationConfiguration;

  const VideoPlayerScreen({
    required this.videoUrl,
    required this.title,
    this.liveStream = false,
    this.autoPlay = true,
    this.deviceOrientationsOnFullScreen,
    this.deviceOrientationsAfterFullScreen,
    this.autoDetectFullscreenDeviceOrientation,
    this.controlsConfiguration,
    this.notificationConfiguration,
    super.key,
    Duration? startAt,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  BetterPlayerController? _betterPlayerController;
  Map<String, String> _resolutions = {};
  bool _isPlayerInitialized = false;
  bool _isDisposed = false;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializePlayer();
  }

  Future<Map<String, String>> _fetchResolutions(String m3u8Url) async {
    try {
      _logger.d("Sifatlarni olish: $m3u8Url");
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'resolutions_${m3u8Url.hashCode}';
      final cachedResolutions = prefs.getString(cacheKey);

      if (cachedResolutions != null) {
        _logger.d("Keshdan sifatlar olindi");
        return Map<String, String>.from(jsonDecode(cachedResolutions));
      }

      final response = await http
          .get(Uri.parse(m3u8Url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('Timeout', 408),
          );
      _logger.d("Javob holati: ${response.statusCode}");
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        Map<String, String> resolutions = {};
        String? currentResolution;

        for (var line in lines) {
          if (line.contains('#EXT-X-STREAM-INF')) {
            final resolutionMatch = RegExp(
              r'RESOLUTION=(\d+x\d+)',
            ).firstMatch(line);
            if (resolutionMatch != null) {
              currentResolution = resolutionMatch.group(1);
            }
          } else if (line.trim().isNotEmpty &&
              currentResolution != null &&
              !line.startsWith('#')) {
            resolutions[currentResolution] = line.trim();
            currentResolution = null;
          }
        }

        final result = resolutions.isEmpty ? {"Auto": m3u8Url} : resolutions;
        await prefs.setString(cacheKey, jsonEncode(result));
        return result;
      }
      return {"Auto": m3u8Url};
    } catch (e) {
      _logger.e("Sifatlarni olishda xato: $e");
      return {"Auto": m3u8Url};
    }
  }

  String _getSafeKey(String url) {
    final cleanUrl = url.split('?').first;
    return 'playback_position_${base64Url.encode(utf8.encode(cleanUrl))}';
  }

  Future<void> _savePlaybackPosition() async {
    if (!mounted ||
        _betterPlayerController == null ||
        !_isPlayerInitialized ||
        _isDisposed) {
      _logger.d(
        "Playback position saqlanmadi: controller yoki state mavjud emas",
      );
      return;
    }
    try {
      final position = await safeGetPosition(_betterPlayerController);
      if (position != null && position.inSeconds > 0) {
        final safeKey = _getSafeKey(widget.videoUrl);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(safeKey, position.inSeconds);
        _logger.d(
          "Playback position saqlandi: ${position.inSeconds} sekund, kalit: $safeKey",
        );
      }
    } catch (e) {
      _logger.e("Playback position saqlashda xato: $e");
    }
  }

  Future<int?> _getSavedPlaybackPosition() async {
    if (widget.liveStream) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getSafeKey(widget.videoUrl);
      final savedPosition = prefs.getInt(key);
      _logger.d(
        "Saqlangan pozitsiya olindi: $savedPosition sekund, kalit: $key",
      );
      return savedPosition;
    } catch (e) {
      _logger.e("Saqlangan pozitsiyani olishda xato: $e");
      return null;
    }
  }

  Future<void> _restorePlaybackPosition() async {
    if (widget.liveStream ||
        !_isPlayerInitialized ||
        _betterPlayerController == null ||
        _isDisposed) {
      _logger.d("Pozitsiya tiklanmadi: jonli efir yoki controller mavjud emas");
      return;
    }
    try {
      final savedPosition = await _getSavedPlaybackPosition();
      if (savedPosition != null && savedPosition > 0) {
        await _betterPlayerController!.seekTo(Duration(seconds: savedPosition));
        _logger.d("Pozitsiya tiklandi: $savedPosition sekund");
      }
    } catch (e) {
      _logger.e("Pozitsiyani tiklashda xato: $e");
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) async {
    if (!mounted) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
      setState(() => _isPlayerInitialized = true);
      if (widget.autoPlay && !widget.liveStream) {
        await safePlay(_betterPlayerController);
        _logger.d("Video avtomatik o‘ynatildi");
      }
      await _restorePlaybackPosition();
    } else if (event.betterPlayerEventType ==
        BetterPlayerEventType.changedTrack) {
      _logger.d("Sifat o‘zgartirildi: ${event.parameters}");
    } else if (event.betterPlayerEventType == BetterPlayerEventType.play) {
      try {
        await WakelockPlus.enable();
        _logger.d("Wakelock yoqildi");
      } catch (e) {
        _logger.e("Wakelock yoqishda xato: $e");
      }
    } else if (event.betterPlayerEventType == BetterPlayerEventType.pause) {
      await _savePlaybackPosition();
      try {
        await WakelockPlus.disable();
        _logger.d("Wakelock o‘chirildi");
      } catch (e) {
        _logger.e("Wakelock o‘chirishda xato: $e");
      }
    }
  }

  void _onFullscreenEvent(BetterPlayerEvent event) async {
    if (!mounted) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.openFullscreen) {
      try {
        await SystemChrome.setPreferredOrientations(
          widget.deviceOrientationsOnFullScreen ??
              [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
        );
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _logger.d("To‘liq ekran rejimi (landshaft)");
      } catch (e) {
        _logger.e("To‘liq ekran sozlamasida xato: $e");
      }
    } else if (event.betterPlayerEventType ==
        BetterPlayerEventType.hideFullscreen) {
      try {
        await SystemChrome.setPreferredOrientations(
          widget.deviceOrientationsAfterFullScreen ??
              [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
        );
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _logger.d("To‘liq ekrandan chiqildi (landshaft)");
      } catch (e) {
        _logger.e("To‘liq ekrandan chiqishda xato: $e");
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Xato",
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            backgroundColor: Colors.black.withOpacity(0.8),
            actions: [
              FocusScope(
                child: Builder(
                  builder:
                      (context) => TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _initializePlayer();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor:
                              FocusScope.of(context).hasFocus
                                  ? Colors.blue[500]
                                  : Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          "Qayta urinish",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                ),
              ),
              FocusScope(
                child: Builder(
                  builder:
                      (context) => TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              FocusScope.of(context).hasFocus
                                  ? Colors.blue[500]
                                  : Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          "Yopish",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isFocused,
  }) {
    return FocusScope(
      child: Builder(
        builder:
            (context) => ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                backgroundColor:
                    isFocused ? Colors.blue[500] : Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: isFocused ? 8 : 4,
                shadowColor: isFocused ? Colors.yellow.withOpacity(0.3) : null,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 32, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildQualityMenu(BetterPlayerController controller) {
    return FocusScope(
      child: Builder(
        builder:
            (context) => PopupMenuButton<String>(
              onSelected: (quality) async {
                final resolutions =
                    controller.betterPlayerDataSource?.resolutions;
                if (resolutions != null && resolutions.containsKey(quality)) {
                  controller.setResolution(resolutions[quality]!);
                }
              },
              itemBuilder: (context) {
                final resolutions =
                    controller.betterPlayerDataSource?.resolutions ?? {};
                return resolutions.keys.map((quality) {
                  return PopupMenuItem<String>(
                    value: quality,
                    child: Text(
                      quality,
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      FocusScope.of(context).hasFocus
                          ? Colors.blue[500]
                          : Colors.blue[700],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        FocusScope.of(context).hasFocus
                            ? Colors.yellow
                            : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.high_quality, size: 32, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Sifat",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _initializePlayer() async {
    if (!mounted || _isPlayerInitialized || _isDisposed) {
      _logger.d("Player allaqachon ishga tushirilgan yoki yopilgan");
      return;
    }

    _logger.d("Player ishga tushirilmoqda: ${widget.videoUrl}");
    if (widget.videoUrl.endsWith('.m3u8')) {
      _resolutions = await _fetchResolutions(widget.videoUrl);
      _logger.d("Mavjud sifatlar: $_resolutions");
    } else {
      _resolutions = {"Auto": widget.videoUrl};
    }

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.videoUrl,
      liveStream: widget.liveStream,
      resolutions: _resolutions,
      notificationConfiguration:
          widget.notificationConfiguration ??
          const BetterPlayerNotificationConfiguration(showNotification: false),
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: widget.autoPlay,
        fit: BoxFit.contain,
        fullScreenByDefault: true,
        handleLifecycle: true,
        autoDispose: true,
        autoDetectFullscreenDeviceOrientation:
            widget.autoDetectFullscreenDeviceOrientation ?? false,
        controlsConfiguration:
            widget.controlsConfiguration ??
            BetterPlayerControlsConfiguration(
              enableFullscreen: true,
              enablePlayPause: true,
              enableMute: true,
              enableProgressText: true,
              enableSkips: true,
              enableQualities: true,
              enableAudioTracks: true,
              controlBarHeight: 60,
              playerTheme: BetterPlayerTheme.material,
              controlBarColor: Colors.black.withOpacity(0.8),
              enableOverflowMenu: true,
              showControlsOnInitialize: true,
              progressBarPlayedColor: Colors.white,
              customControlsBuilder: (controller, onControlsVisibilityChanged) {
                return FocusScope(
                  child: Container(
                    height: 60,
                    color: Colors.black.withOpacity(0.8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: Icons.play_arrow,
                          label: "O‘ynatish",
                          onPressed:
                              controller.isPlaying() == true
                                  ? null
                                  : () {
                                    controller.play();
                                    onControlsVisibilityChanged(true);
                                  },
                          isFocused: FocusScope.of(context).hasFocus,
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.pause,
                          label: "Pauza",
                          onPressed:
                              controller.isPlaying() == true
                                  ? () {
                                    controller.pause();
                                    onControlsVisibilityChanged(true);
                                  }
                                  : null,
                          isFocused: FocusScope.of(context).hasFocus,
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.fullscreen,
                          label: "To‘liq ekran",
                          onPressed: () {
                            controller.toggleFullScreen();
                            onControlsVisibilityChanged(true);
                          },
                          isFocused: FocusScope.of(context).hasFocus,
                        ),
                        const SizedBox(width: 16),
                        _buildQualityMenu(controller),
                      ],
                    ),
                  ),
                );
              },
            ),
        errorBuilder: (context, errorMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showErrorDialog(
              "Video xatosi: ${errorMessage ?? 'Noma’lum xato'}",
            );
          });
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 6,
            ),
          );
        },
      ),
      betterPlayerDataSource: dataSource,
    );

    if (!mounted) return;

    setState(() {
      _isPlayerInitialized = true;
    });

    _betterPlayerController?.addEventsListener(_onPlayerEvent);
    _betterPlayerController?.addEventsListener(_onFullscreenEvent);

    if (_resolutions.isNotEmpty && _resolutions.length > 1 && mounted) {
      final highestResolution = _resolutions.keys.reduce((a, b) {
        try {
          final aRes = int.parse(a.split('x')[1]);
          final bRes = int.parse(b.split('x')[1]);
          return aRes > bRes ? a : b;
        } catch (e) {
          _logger.e("Sifat parsing xatosi: $e");
          return a;
        }
      });
      await safeSetResolution(
        _betterPlayerController,
        _resolutions[highestResolution],
      );
    }
  }

  @override
  void dispose() {
    if (!_isDisposed &&
        _betterPlayerController != null &&
        _isPlayerInitialized) {
      _isDisposed = true;
      try {
        _savePlaybackPosition().catchError((e) {
          _logger.e("Playback position saqlashda xato: $e");
        });

        safeDispose(
              _betterPlayerController,
              onPlayerEvent: _onPlayerEvent,
              onFullscreenEvent: _onFullscreenEvent,
            )
            .then((_) {
              _logger.d("BetterPlayerController muvaffaqiyatli yopildi");
            })
            .catchError((e) {
              _logger.e("safeDispose xatosi: $e");
            });

        _betterPlayerController = null;
        _isPlayerInitialized = false;
      } catch (e, stackTrace) {
        _logger.e("dispose xatosi: $e\nStackTrace: $stackTrace");
      }
    }

    try {
      WakelockPlus.disable().then((_) => _logger.d("Wakelock o‘chirildi"));
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      _logger.e("Tizim sozlamalarini tozalashda xato: $e");
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _betterPlayerController == null || !_isPlayerInitialized
              ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              )
              : BetterPlayer(controller: _betterPlayerController!),
    );
  }
}
