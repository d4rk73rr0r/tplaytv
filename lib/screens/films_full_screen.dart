import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/screens/video_player_screen.dart';
import 'package:better_player/better_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'filmImagesCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class FilmsFullScreen extends StatefulWidget {
  final int filmId;
  final String filmName;

  const FilmsFullScreen({
    required this.filmId,
    required this.filmName,
    super.key,
  });

  @override
  State<FilmsFullScreen> createState() => _FilmsFullScreenState();
}

class _FilmsFullScreenState extends State<FilmsFullScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> seasons = [];
  Map<int, List<dynamic>> episodesBySeason = {};
  Map<int, int?> seasonMapping = {};
  Map<int, bool> isLoadingBySeason = {};
  Map<int, bool> isLoadingMoreBySeason = {};
  Map<int, bool> hasMoreEpisodesBySeason = {};
  Map<int, int> pageBySeason = {};
  Map<int, ScrollController> scrollControllers = {};
  Map<int, Set<int>> loadedEpisodeIdsBySeason = {};
  late TabController _tabController;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    if (!mounted) return;

    setState(() => _isInitialLoading = true);

    try {
      final seasonsData = await ApiService.getSeasons(widget.filmId);
      final Map<int, int?> seasonMappingTemp = {};
      for (var i = 0; i < seasonsData.length; i++) {
        seasonMappingTemp[i + 1] = seasonsData[i]['season_id'] as int?;
      }

      if (mounted) {
        setState(() {
          seasons = seasonsData;
          seasonMapping = seasonMappingTemp;
          _isInitialLoading = false;
          _tabController = TabController(length: seasons.length, vsync: this);
          for (var i = 1; i <= seasons.length; i++) {
            episodesBySeason[i] = [];
            isLoadingBySeason[i] = false;
            isLoadingMoreBySeason[i] = false;
            hasMoreEpisodesBySeason[i] = true;
            pageBySeason[i] = 1;
            loadedEpisodeIdsBySeason[i] = {};
            scrollControllers[i] = ScrollController();
            scrollControllers[i]!.addListener(() => _onScroll(i));
          }
        });
        _loadEpisodes(1, clearExisting: true);

        _tabController.addListener(() {
          if (!_tabController.indexIsChanging) {
            final seasonNumber = _tabController.index + 1;
            if (episodesBySeason[seasonNumber]!.isEmpty &&
                !isLoadingMoreBySeason[seasonNumber]!) {
              _loadEpisodes(seasonNumber, clearExisting: true);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        _showErrorDialog("Fasllarni yuklashda xato: $e");
      }
    }
  }

  Future<void> _loadEpisodes(
    int seasonNumber, {
    bool clearExisting = false,
  }) async {
    if (isLoadingMoreBySeason[seasonNumber] == true || !mounted) return;

    setState(() {
      isLoadingMoreBySeason[seasonNumber] = true;
      if (clearExisting) {
        episodesBySeason[seasonNumber] = [];
        loadedEpisodeIdsBySeason[seasonNumber] = {};
        pageBySeason[seasonNumber] = 1;
        hasMoreEpisodesBySeason[seasonNumber] = true;
      }
    });

    final int? effectiveSeason = seasonMapping[seasonNumber];
    if (effectiveSeason == null) {
      if (mounted) {
        setState(() {
          episodesBySeason[seasonNumber] = [];
          isLoadingMoreBySeason[seasonNumber] = false;
          hasMoreEpisodesBySeason[seasonNumber] = false;
        });
      }
      return;
    }

    try {
      final episodeData = await ApiService.getEpisodes(
        widget.filmId,
        effectiveSeason,
        page: pageBySeason[seasonNumber]!,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          if (episodeData.isNotEmpty) {
            for (var episode in episodeData) {
              final episodeId = episode['id'] as int?;
              if (episodeId != null &&
                  !loadedEpisodeIdsBySeason[seasonNumber]!.contains(
                    episodeId,
                  )) {
                episodesBySeason[seasonNumber]!.add(episode);
                loadedEpisodeIdsBySeason[seasonNumber]!.add(episodeId);
              }
            }
            pageBySeason[seasonNumber] = pageBySeason[seasonNumber]! + 1;
            hasMoreEpisodesBySeason[seasonNumber] = episodeData.length == 20;
          } else {
            hasMoreEpisodesBySeason[seasonNumber] = false;
          }
          isLoadingMoreBySeason[seasonNumber] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingMoreBySeason[seasonNumber] = false);
        _showErrorDialog("Qismlarni yuklashda xato: $e");
      }
    }
  }

  void _onScroll(int seasonNumber) {
    final controller = scrollControllers[seasonNumber];
    if (controller!.position.pixels >=
            controller.position.maxScrollExtent - 100 &&
        !isLoadingMoreBySeason[seasonNumber]! &&
        hasMoreEpisodesBySeason[seasonNumber]!) {
      _loadEpisodes(seasonNumber);
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
      return newUrl;
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Yangi URL olishda xato: $e");
      }
      return initialUrl;
    }
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

  Widget _buildShimmer() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.0,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[700]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    scrollControllers.forEach((_, controller) => controller.dispose());
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
          widget.filmName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom:
            seasons.isEmpty
                ? null
                : PreferredSize(
                  preferredSize: const Size.fromHeight(60.0),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.yellow,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    tabs: List.generate(
                      seasons.length,
                      (index) => FocusScope(
                        child: Builder(
                          builder:
                              (context) => Tab(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border:
                                        FocusScope.of(context).hasFocus
                                            ? Border.all(
                                              color: Colors.yellow,
                                              width: 2,
                                            )
                                            : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Fasl ${index + 1}",
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
      ),
      body:
          _isInitialLoading
              ? _buildShimmer()
              : seasons.isEmpty
              ? Center(
                child: TextButton(
                  onPressed: () => _showErrorDialog("Fasllar mavjud emas"),
                  child: const Text(
                    "Fasllar mavjud emas. Ko‘proq ma'lumot",
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: List.generate(seasons.length, (index) {
                  final seasonNumber = index + 1;
                  final episodes = episodesBySeason[seasonNumber] ?? [];
                  return episodes.isEmpty &&
                          !isLoadingMoreBySeason[seasonNumber]!
                      ? Center(child: _buildShimmer())
                      : GridView.builder(
                        controller: scrollControllers[seasonNumber],
                        padding: const EdgeInsets.all(24.0),
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
                            (isLoadingMoreBySeason[seasonNumber]! ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == episodes.length) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 6,
                              ),
                            );
                          }
                          final episode = episodes[index];
                          final screenshot =
                              episode['screenshots'] != null &&
                                      episode['screenshots'].isNotEmpty &&
                                      episode['screenshots'][0]['file'] !=
                                          null &&
                                      episode['screenshots'][0]['file']
                                          .isNotEmpty &&
                                      episode['screenshots'][0]['file'][0]['thumbnails'] !=
                                          null &&
                                      episode['screenshots'][0]['file'][0]['thumbnails']['small'] !=
                                          null
                                  ? episode['screenshots'][0]['file'][0]['thumbnails']['small']['src']
                                  : 'https://placehold.co/300x200';
                          final isLastSeen = episode['is_last_seen'] == true;

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
                                              ? Border.all(
                                                color: Colors.yellow,
                                                width: 2,
                                              )
                                              : Border.all(
                                                color: Colors.grey.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                        if (FocusScope.of(context).hasFocus)
                                          BoxShadow(
                                            color: Colors.yellow.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                          ),
                                      ],
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        final trackList =
                                            episode['track'] as List<dynamic>?;
                                        if (trackList != null &&
                                            trackList.isNotEmpty) {
                                          final streamUrl =
                                              trackList[0]['stream_url'] ?? '';
                                          _playVideo(
                                            streamUrl,
                                            episode['name_uz'] ??
                                                "Qism ${index + 1}",
                                          );
                                        } else {
                                          _showErrorDialog(
                                            "Epizod uchun video mavjud emas",
                                          );
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: CachedNetworkImage(
                                                    imageUrl: screenshot,
                                                    cacheManager:
                                                        customCacheManager,
                                                    fit: BoxFit.cover,
                                                    width: 300,
                                                    height: 200,
                                                    maxWidthDiskCache: 300,
                                                    maxHeightDiskCache: 200,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => Container(
                                                          width: 300,
                                                          height: 200,
                                                          color: const Color(
                                                            0xFF374151,
                                                          ),
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  strokeWidth:
                                                                      4,
                                                                ),
                                                          ),
                                                        ),
                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Container(
                                                          width: 300,
                                                          height: 200,
                                                          color: const Color(
                                                            0xFF374151,
                                                          ),
                                                          child: const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.grey,
                                                            size: 48,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                                if (isLastSeen)
                                                  Positioned(
                                                    top: 12,
                                                    right: 12,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withOpacity(0.8),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        "So'nggi ko'rilgan",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  episode['name_uz'] ??
                                                      "Qism ${index + 1}",
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (episode['duration'] != null)
                                                  Text(
                                                    _formatDuration(
                                                      episode['duration'],
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          );
                        },
                      );
                }),
              ),
    );
  }
}
