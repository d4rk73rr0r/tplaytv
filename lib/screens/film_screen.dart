import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/screens/films_full_screen.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/screens/video_player_screen.dart';
import 'package:better_player/better_player.dart';
import 'package:tplaytv/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'filmImagesCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class FilmScreen extends StatefulWidget {
  final int filmId;

  const FilmScreen({required this.filmId, super.key});

  @override
  State<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends State<FilmScreen> {
  Map<String, dynamic>? film;
  List<dynamic> episodes = [];
  int? selectedSeason;
  Map<int, int?> seasonMapping = {};
  bool _isLoading = true;
  int page = 1;
  bool _isLoadingMore = false;
  bool _hasMoreEpisodes = true;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _loadedEpisodeIds = {};
  bool isFavorite = false;
  double _scale = 1.0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadFilmDetails();
    _scrollController.addListener(_onScroll);
    StorageUtils().cleanOldPlaybackPositions();
  }

  Future<void> _toggleFavorite() async {
    if (_isAnimating || !mounted) return;

    setState(() {
      _isAnimating = true;
      _scale = 1.5;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    setState(() {
      _scale = 1.0;
    });

    try {
      setState(() {
        isFavorite = !isFavorite;
      });

      bool success;
      if (isFavorite) {
        success = await ApiService.addToFavorite(widget.filmId);
      } else {
        success = await ApiService.removeFromFavorite(widget.filmId);
      }

      if (!success && mounted) {
        setState(() {
          isFavorite = !isFavorite;
        });
        _showErrorDialog(
          isFavorite
              ? "Sevimliga qo'shishda xato"
              : "Sevimlidan o'chirishda xato",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isFavorite = !isFavorite;
        });
        _showErrorDialog("Xato: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    }
  }

  Future<void> _loadFilmDetails() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final filmData = await ApiService.getFilmDetails(widget.filmId);
      if (mounted) {
        setState(() {
          film = filmData;
          isFavorite =
              filmData.containsKey('favorite') && filmData['favorite'] == 1;
          _isLoading = false;
        });
      }

      if (isSerial() && film?['season_count'] != null) {
        await _mapSeasons();
        if (mounted) {
          setState(() => selectedSeason = 1);
          _loadEpisodes(clearExisting: true);
        }
      }
      _precacheImages();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog("Film ma'lumotlarini yuklashda xato: $e");
      }
    }
  }

  Future<void> _mapSeasons() async {
    try {
      final seasonsData = await ApiService.getSeasons(widget.filmId);
      final Map<int, int?> seasonMappingTemp = {};
      for (var i = 0; i < seasonsData.length; i++) {
        seasonMappingTemp[i + 1] = seasonsData[i]['season_id'] as int?;
      }

      if (mounted) {
        setState(() => seasonMapping = seasonMappingTemp);
      }
    } catch (e) {}
  }

  Future<void> _loadEpisodes({bool clearExisting = false}) async {
    if (selectedSeason == null || _isLoadingMore || !mounted) return;

    setState(() {
      _isLoadingMore = true;
      if (clearExisting) {
        episodes.clear();
        _loadedEpisodeIds.clear();
        page = 1;
        _hasMoreEpisodes = true;
      }
    });

    final int? effectiveSeason = seasonMapping[selectedSeason];
    if (effectiveSeason == null) {
      if (mounted) {
        setState(() {
          episodes = [];
          _isLoadingMore = false;
          _hasMoreEpisodes = false;
        });
      }
      return;
    }

    try {
      final episodeData = await ApiService.getEpisodes(
        widget.filmId,
        effectiveSeason,
        page: page,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          if (episodeData.isNotEmpty) {
            for (var episode in episodeData) {
              final episodeId = episode['id'] as int?;
              if (episodeId != null && !_loadedEpisodeIds.contains(episodeId)) {
                episodes.add(episode);
                _loadedEpisodeIds.add(episodeId);
              }
            }
            page++;
            _hasMoreEpisodes = episodeData.length == 20;
          } else {
            _hasMoreEpisodes = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showErrorDialog("Qismlarni yuklashda xato: $e");
      }
    }
  }

  void _onSeasonSelected(int season) {
    if (mounted) {
      setState(() => selectedSeason = season);
      _loadEpisodes(clearExisting: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMoreEpisodes &&
        isSerial()) {
      _loadEpisodes();
    }
  }

  Future<String> _getValidStreamUrl(String initialUrl) async {
    try {
      final response = await ApiService.checkUrlValidity(initialUrl);
      if (response['isValid'] == true) return initialUrl;
    } catch (e) {}

    try {
      final updatedFilmData = await ApiService.getFilmDetails(widget.filmId);
      final newUrl =
          updatedFilmData['lastSeries']?[0]?['track']?[0]?['stream_url'] ?? '';
      if (mounted) {
        setState(() => film = updatedFilmData);
      }
      return newUrl;
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Yangi URL olishda xato: $e");
      }
      return initialUrl;
    }
  }

  bool isSerial() {
    return film?['type']?['name_uz'] == "Serial";
  }

  Future<void> _playVideo(String url, String title) async {
    if (!mounted) return;

    final validUrl = await _getValidStreamUrl(url);
    if (validUrl.isEmpty) {
      if (mounted) {
        _showErrorDialog("Video URL topilmadi");
      }
      return;
    }

    final cleanUrl = validUrl.split('?').first;
    final safeKey =
        'playback_position_${base64Url.encode(utf8.encode(cleanUrl))}';
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt(safeKey);

    bool? resumePlayback;
    if (savedPosition != null && savedPosition > 0) {
      resumePlayback = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF1F2937),
              title: const Text(
                "Davom ettirish",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              content: Text(
                "'$title' ni ${_formatDuration(savedPosition)} dan davom ettirishni xohlaysizmi?",
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              actions: [
                FocusScope(
                  child: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed: () => Navigator.pop(context, false),
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
                            "Yo'q",
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                        ),
                  ),
                ),
                FocusScope(
                  child: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed: () => Navigator.pop(context, true),
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
                            "Ha",
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                        ),
                  ),
                ),
              ],
            ),
      );

      if (resumePlayback == null) return;

      if (!resumePlayback) {
        await prefs.remove(safeKey);
      }
    }

    final selectedPlayer = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFF1F2937),
            title: const Text(
              "Pleerni tanlang",
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FocusScope(
                    child: Builder(
                      builder:
                          (context) => ListTile(
                            leading: Icon(
                              Icons.play_circle_filled,
                              color:
                                  FocusScope.of(context).hasFocus
                                      ? Colors.yellow
                                      : Colors.white,
                              size: 32,
                            ),
                            title: const Text(
                              "Ichki pleer: Better Player",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            onTap:
                                () => Navigator.pop(context, 'better_player'),
                            selected: FocusScope.of(context).hasFocus,
                            selectedTileColor: Colors.blue[700],
                          ),
                    ),
                  ),
                  FocusScope(
                    child: Builder(
                      builder:
                          (context) => ListTile(
                            leading: Icon(
                              Icons.video_library,
                              color:
                                  FocusScope.of(context).hasFocus
                                      ? Colors.yellow
                                      : Colors.white,
                              size: 32,
                            ),
                            title: const Text(
                              "Tashqi pleer bilan ochish",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, 'external'),
                            selected: FocusScope.of(context).hasFocus,
                            selectedTileColor: Colors.blue[700],
                          ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
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
                          "Bekor qilish",
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                ),
              ),
            ],
          ),
    );

    if (selectedPlayer == null) return;

    if (selectedPlayer == 'better_player') {
      if (mounted) {
        await Navigator.push(
          context,
          createSlideRoute(
            VideoPlayerScreen(
              videoUrl: validUrl,
              title: title,
              liveStream: false,
              autoPlay: true,
              deviceOrientationsOnFullScreen: const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
              deviceOrientationsAfterFullScreen: const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
              autoDetectFullscreenDeviceOrientation: false,
              controlsConfiguration: const BetterPlayerControlsConfiguration(
                enableFullscreen: true,
                enablePlayPause: true,
                enableMute: true,
                enableProgressText: true,
                enableSkips: true,
                enableQualities: true,
                enableAudioTracks: true,
              ),
              notificationConfiguration:
                  const BetterPlayerNotificationConfiguration(
                    showNotification: false,
                  ),
              startAt:
                  resumePlayback == true && savedPosition != null
                      ? Duration(seconds: savedPosition)
                      : null,
            ),
          ),
        );
      }
    } else if (selectedPlayer == 'external') {
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: validUrl,
          type: 'video/*',
        );
        await intent.launch();
      } catch (e) {
        if (mounted) {
          _showErrorDialog("Tashqi pleerni ochishda xato: $e");
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFF1F2937),
              title: const Text(
                "Xato",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              content: Text(
                message,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              actions: [
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
                            "OK",
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                        ),
                  ),
                ),
              ],
            ),
      );
    }
  }

  void _precacheImages() {
    Future.microtask(() {
      final coverUrl =
          film != null && film!['files'] != null && film!['files'].isNotEmpty
              ? film!['files'][0]['linkAbsolute'] ??
                  'https://placehold.co/200x300'
              : 'https://placehold.co/200x300';
      precacheImage(
        CachedNetworkImageProvider(coverUrl, cacheManager: customCacheManager),
        context,
        onError: (_, __) {},
      );
    });
  }

  String _getGenresText(List<dynamic> genres) {
    if (genres.isEmpty) return 'Noma\'lum';
    return genres.map((genre) => genre['name_uz'] ?? 'Noma\'lum').join(', ');
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$secs';
    } else {
      return '$minutes:$secs';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 4,
        leading: FocusScope(
          child: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Orqaga',
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith(
                      (states) =>
                          FocusScope.of(context).hasFocus
                              ? Colors.blue[500]
                              : Colors.blue[700],
                    ),
                  ),
                ),
          ),
        ),
        title: Text(
          film?['name_uz'] ?? "Noma'lum",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              )
              : film == null
              ? Center(
                child: TextButton(
                  onPressed:
                      () => _showErrorDialog("Film ma'lumotlari topilmadi"),
                  child: const Text(
                    "Film ma'lumotlari topilmadi. Ko‘proq ma'lumot",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              )
              : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl:
                                    film != null &&
                                            film!['files'] != null &&
                                            film!['files'].isNotEmpty
                                        ? film!['files'][0]['linkAbsolute'] ??
                                            'https://placehold.co/200x300'
                                        : 'https://placehold.co/200x300',
                                cacheManager: customCacheManager,
                                width: 200,
                                height: 300,
                                fit: BoxFit.cover,
                                maxWidthDiskCache: 200,
                                maxHeightDiskCache: 300,
                                placeholder:
                                    (context, url) => Container(
                                      width: 200,
                                      height: 300,
                                      color: const Color(0xFF374151),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      width: 200,
                                      height: 300,
                                      color: const Color(0xFF374151),
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                        size: 48,
                                      ),
                                    ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: FocusScope(
                                  child: Builder(
                                    builder:
                                        (context) => GestureDetector(
                                          onTap: _toggleFavorite,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            transform:
                                                FocusScope.of(context).hasFocus
                                                    ? (Matrix4.identity()
                                                      ..scale(1.1))
                                                    : Matrix4.identity(),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                              border:
                                                  FocusScope.of(
                                                        context,
                                                      ).hasFocus
                                                      ? Border.all(
                                                        color: Colors.yellow,
                                                        width: 2,
                                                      )
                                                      : null,
                                            ),
                                            child: AnimatedScale(
                                              scale: _scale,
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              curve: Curves.easeInOut,
                                              child: Icon(
                                                isFavorite
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color:
                                                    isFavorite
                                                        ? Colors.red
                                                        : Colors.white,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${film?['name_uz'] ?? 'Noma\'lum'} (${film?['year'] ?? 'Noma\'lum'})",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (isSerial() &&
                                    film?['season_count'] != null &&
                                    film?['episode_count'] != null)
                                  Text(
                                    "${film?['season_count']} fasl, ${film?['episode_count']} qism",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                Text(
                                  "Janr: ${_getGenresText(film?['genres'] ?? [])}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  "Kinopoisk: ${film?['kinopoisk_rating'] ?? 'Noma\'lum'}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  "IMDb: ${film?['imdb_rating'] ?? 'Noma\'lum'}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Tavsif:",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        film?['description_uz'] ?? "Tavsif mavjud emas",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isSerial() &&
                          film != null &&
                          film!['lastSeries'] != null &&
                          film!['lastSeries'].isNotEmpty)
                        FocusScope(
                          child: Builder(
                            builder:
                                (context) => ElevatedButton(
                                  onPressed: () {
                                    final lastSeriesList =
                                        film!['lastSeries'] as List<dynamic>;
                                    final trackList =
                                        lastSeriesList.isNotEmpty
                                            ? lastSeriesList[0]['track']
                                                as List<dynamic>?
                                            : null;
                                    if (trackList != null &&
                                        trackList.isNotEmpty) {
                                      final streamUrl =
                                          trackList[0]['stream_url'] ?? '';
                                      _playVideo(
                                        streamUrl,
                                        film!['name_uz'] ?? 'Noma\'lum',
                                      );
                                    } else {
                                      _showErrorDialog(
                                        "Film uchun video mavjud emas",
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        FocusScope.of(context).hasFocus
                                            ? Colors.blue[500]
                                            : Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side:
                                        FocusScope.of(context).hasFocus
                                            ? const BorderSide(
                                              color: Colors.yellow,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                  child: const Text(
                                    "Filmni ko'rish",
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                          ),
                        ),
                      if (isSerial()) ...[
                        const SizedBox(height: 24),
                        FocusScope(
                          child: Builder(
                            builder:
                                (context) => ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      createSlideRoute(
                                        FilmsFullScreen(
                                          filmId: widget.filmId,
                                          filmName:
                                              film?['name_uz'] ?? 'Noma\'lum',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        FocusScope.of(context).hasFocus
                                            ? Colors.blue[500]
                                            : Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side:
                                        FocusScope.of(context).hasFocus
                                            ? const BorderSide(
                                              color: Colors.yellow,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                  child: const Text(
                                    "Barcha qismlar",
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Fasllar",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              film != null && film!['season_count'] != null
                                  ? film!['season_count'] as int
                                  : 1,
                              (index) {
                                final season = index + 1;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: FocusScope(
                                    child: Builder(
                                      builder:
                                          (context) => ElevatedButton(
                                            onPressed:
                                                () => _onSeasonSelected(season),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  selectedSeason == season
                                                      ? (FocusScope.of(
                                                            context,
                                                          ).hasFocus
                                                          ? Colors.blue[500]
                                                          : Colors.blue[700])
                                                      : (FocusScope.of(
                                                            context,
                                                          ).hasFocus
                                                          ? Colors.grey[700]
                                                          : const Color(
                                                            0xFF1F2937,
                                                          )),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 32,
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              side:
                                                  FocusScope.of(
                                                        context,
                                                      ).hasFocus
                                                      ? const BorderSide(
                                                        color: Colors.yellow,
                                                        width: 2,
                                                      )
                                                      : null,
                                            ),
                                            child: Text(
                                              "Fasl $season",
                                              style: const TextStyle(
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Qismlar (Fasl ${selectedSeason ?? ''})",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child:
                              episodes.isEmpty && !_isLoadingMore
                                  ? Center(
                                    child: TextButton(
                                      onPressed:
                                          () => _showErrorDialog(
                                            "Bu fasl uchun epizodlar mavjud emas",
                                          ),
                                      child: const Text(
                                        "Bu fasl uchun epizodlar mavjud emas. Ko‘proq ma'lumot",
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                  : GridView.builder(
                                    controller: _scrollController,
                                    cacheExtent: 500,
                                    physics: const BouncingScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 2.0,
                                        ),
                                    itemCount:
                                        episodes.length +
                                        (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == episodes.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 6,
                                          ),
                                        );
                                      }
                                      return EpisodeCard(
                                        episode: episodes[index],
                                        index: index,
                                        onTap: () {
                                          final trackList =
                                              episodes[index]['track']
                                                  as List<dynamic>?;
                                          if (trackList != null &&
                                              trackList.isNotEmpty) {
                                            final streamUrl =
                                                trackList[0]['stream_url'] ??
                                                '';
                                            _playVideo(
                                              streamUrl,
                                              episodes[index]['name_uz'] ??
                                                  "Qism ${index + 1}",
                                            );
                                          } else {
                                            _showErrorDialog(
                                              "Epizod uchun video mavjud emas",
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }
}

class EpisodeCard extends StatelessWidget {
  final dynamic episode;
  final int index;
  final VoidCallback onTap;

  const EpisodeCard({
    super.key,
    required this.episode,
    required this.index,
    required this.onTap,
  });

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$secs';
    } else {
      return '$minutes:$secs';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Builder(
        builder:
            (context) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform:
                  FocusScope.of(context).hasFocus
                      ? (Matrix4.identity()..scale(1.1))
                      : Matrix4.identity(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1F2937),
                border:
                    FocusScope.of(context).hasFocus
                        ? Border.all(color: Colors.yellow, width: 2)
                        : Border.all(color: Colors.grey.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  if (FocusScope.of(context).hasFocus)
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                FocusScope.of(context).hasFocus
                                    ? Colors.blue[500]
                                    : Colors.blue[700],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                episode['name_uz'] ?? "Qism ${index + 1}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (episode['duration'] != null)
                                Text(
                                  _formatDuration(episode['duration']),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.play_arrow_rounded,
                          color:
                              FocusScope.of(context).hasFocus
                                  ? Colors.yellow
                                  : Colors.blue,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
