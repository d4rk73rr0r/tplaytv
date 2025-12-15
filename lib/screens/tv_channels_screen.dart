import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:better_player/better_player.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:tplaytv/screens/video_player_screen.dart';
import 'package:tplaytv/services/tv_api_service.dart';
import 'package:tplaytv/utils/navigation.dart';

// Kesh sozlamalari
final customCacheManager = CacheManager(
  Config(
    'tvChannelsCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 50,
  ),
);

final dataCacheManager = CacheManager(
  Config(
    'tvDataCache',
    stalePeriod: const Duration(minutes: 30),
    maxNrOfCacheObjects: 50,
  ),
);

class TVChannelsScreen extends StatefulWidget {
  const TVChannelsScreen({super.key});

  @override
  State<TVChannelsScreen> createState() => _TVChannelsScreenState();
}

class _TVChannelsScreenState extends State<TVChannelsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<dynamic> categories = [];
  Map<String, List<dynamic>> channelsByCategory = {};
  String selectedSource = "SalomTV";
  bool _isLoading = true;
  int totalChannels = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadTVData();
  }

  Future<void> _loadTVData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final categoryCacheKey = 'categories_$selectedSource';
      final cachedCategories = await dataCacheManager.getFileFromCache(
        categoryCacheKey,
      );

      if (cachedCategories != null) {
        categories = jsonDecode(await cachedCategories.file.readAsString());
      } else {
        categories = await TVApiService.getTVCategories(selectedSource);
        await dataCacheManager.putFile(
          categoryCacheKey,
          utf8.encode(jsonEncode(categories)),
          fileExtension: 'json',
        );
      }

      await _loadChannelsForAllCategories();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tabController?.dispose();
        _tabController = TabController(
          length: categories.isEmpty ? 1 : categories.length + 1,
          vsync: this,
        );
        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) return;
          setState(() {});
        });
      });

      _precacheImages();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog("TV ma'lumotlarini yuklashda xato: $e");
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      categories.clear();
      channelsByCategory.clear();
      _isLoading = true;
      _tabController?.dispose();
      _tabController = null;
    });
    await _loadTVData();
  }

  Future<void> _loadChannelsForAllCategories() async {
    channelsByCategory['all'] = await _fetchChannels(null);
    totalChannels = channelsByCategory['all']!.length;

    if (categories.isNotEmpty) {
      final futures = categories.map(
        (category) => _fetchChannels(category['id']),
      );
      final results = await Future.wait(futures);
      for (var i = 0; i < categories.length; i++) {
        channelsByCategory[categories[i]['id']] = results[i];
      }
    }
  }

  Future<List<dynamic>> _fetchChannels(String? categoryId) async {
    final channelCacheKey =
        'channels_${selectedSource}_page_1${categoryId ?? "all"}';
    Map<String, dynamic> channelData;

    if (selectedSource == "SalomTV" || selectedSource == "BizTV") {
      channelData = await TVApiService.getTVChannels(
        source: selectedSource,
        page: 1,
        categoryId: categoryId,
        fetchAll: selectedSource == "BizTV",
      );
    } else {
      final cachedChannels = await dataCacheManager.getFileFromCache(
        channelCacheKey,
      );
      if (cachedChannels != null) {
        channelData = jsonDecode(await cachedChannels.file.readAsString());
      } else {
        channelData = await TVApiService.getTVChannels(
          source: selectedSource,
          page: 1,
          categoryId: categoryId,
        );
        await dataCacheManager.putFile(
          channelCacheKey,
          utf8.encode(jsonEncode(channelData)),
          fileExtension: 'json',
        );
      }
    }
    return channelData['tv_channels'] ?? [];
  }

  void _precacheImages() {
    for (var channels in channelsByCategory.values) {
      for (var channel in channels.take(10)) {
        precacheImage(
          CachedNetworkImageProvider(
            channel['image'] ?? 'https://placehold.co/150x150',
            cacheManager: customCacheManager,
          ),
          context,
          onError: (_, __) {},
        );
      }
    }
  }

  Future<void> _playChannel(
    String channelId,
    String title,
    String source,
  ) async {
    String? videoUrl;
    try {
      if (source == "SalomTV" || source == "BizTV") {
        videoUrl = channelId;
      } else if (source == "SpecUZ") {
        final channelDetails = await TVApiService.getChannelDetails(
          source: source,
          channelId: channelId,
        );
        videoUrl =
            channelDetails['channel_stream_all'] ??
            channelDetails['test_stream'];
      }
      if (videoUrl == null) throw Exception("Strim URL topilmadi");
    } catch (e) {
      _showErrorDialog("Strim URL'ni olishda xato: $e");
      return;
    }

    // Pleer tanlash dialogi
    final selectedPlayer = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Pleerni tanlang",
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            backgroundColor: Colors.black.withOpacity(0.8),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPlayerOption(
                    context,
                    icon: Icons.play_circle_filled,
                    text: "Ichki pleer: Better Player",
                    value: 'better_player',
                  ),
                  _buildPlayerOption(
                    context,
                    icon: Icons.video_library,
                    text: "Tashqi pleer bilan ochish",
                    value: 'external',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue[700],
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
            ],
          ),
    );

    if (selectedPlayer == null) return;

    if (selectedPlayer == 'better_player') {
      // Ichki pleer bilan ochish
      if (mounted) {
        Navigator.push(
          context,
          createSlideRoute(
            VideoPlayerScreen(
              videoUrl: videoUrl,
              title: title,
              liveStream: true,
              autoPlay: true,
              deviceOrientationsOnFullScreen: const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
              deviceOrientationsAfterFullScreen: const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
              autoDetectFullscreenDeviceOrientation: true,
              controlsConfiguration: BetterPlayerControlsConfiguration(
                enableFullscreen: true,
                enablePlayPause: true,
                enableMute: true,
                enableSkips: false,
                controlBarHeight: 60,
                controlBarColor: Colors.black.withOpacity(0.8),
                progressBarPlayedColor: Colors.white,
                customControlsBuilder: (
                  controller,
                  onControlsVisibilityChanged,
                ) {
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
                        ],
                      ),
                    ),
                  );
                },
              ),
              notificationConfiguration: BetterPlayerNotificationConfiguration(
                showNotification: false,
                title: title,
                author: source,
              ),
            ),
          ),
        );
      }
    } else if (selectedPlayer == 'external') {
      // Tashqi pleer bilan ochish
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: videoUrl,
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

  Widget _buildPlayerOption(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String value,
  }) {
    return FocusScope(
      child: Builder(
        builder:
            (context) => GestureDetector(
              onTap: () => Navigator.pop(context, value),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
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
                  border:
                      FocusScope.of(context).hasFocus
                          ? Border.all(color: Colors.yellow, width: 2)
                          : null,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 32, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  void _onSourceChanged(String newSource) {
    if (newSource != selectedSource && mounted) {
      setState(() {
        selectedSource = newSource;
        categories.clear();
        channelsByCategory.clear();
        _isLoading = true;
        _tabController?.dispose();
        _tabController = null;
      });
      _loadTVData();
    }
  }

  String _shortenText(String text, {int maxLength = 20}) =>
      text.length <= maxLength ? text : '${text.substring(0, maxLength)}...';

  void _showErrorDialog(String message) {
    if (mounted) {
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
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              backgroundColor: Colors.black.withOpacity(0.8),
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
                FocusScope(
                  child: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _refresh();
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

  int _getCurrentCategoryChannelCount() {
    final currentIndex = _tabController?.index ?? 0;
    if (currentIndex == 0 || categories.isEmpty) {
      return totalChannels;
    } else {
      final categoryId = categories[currentIndex - 1]['id'];
      return channelsByCategory[categoryId]?.length ?? 0;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 4,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "TV Kanallar",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(
              width: 300,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    TVApiService.baseUrls.keys.map((source) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: FocusScope(
                          child: Builder(
                            builder:
                                (context) => GestureDetector(
                                  onTap: () => _onSourceChanged(source),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          selectedSource == source
                                              ? Colors.blue[500]
                                              : Colors.blue[700],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          FocusScope.of(context).hasFocus
                                              ? Border.all(
                                                color: Colors.yellow,
                                                width: 2,
                                              )
                                              : null,
                                      boxShadow:
                                          FocusScope.of(context).hasFocus
                                              ? [
                                                BoxShadow(
                                                  color: Colors.yellow
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                ),
                                              ]
                                              : null,
                                    ),
                                    child: Text(
                                      source,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          FocusScope(
            child: Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: _refresh,
                    tooltip: 'Yangilash',
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
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              )
              : channelsByCategory.isEmpty
              ? const Center(
                child: Text(
                  "Kanallar mavjud emas",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              )
              : _tabController == null
              ? const Center(
                child: Text(
                  "Tablarni yuklashda xato",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              )
              : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categories.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildCategoryButton(
                                text: "Barchasi",
                                isSelected: _tabController?.index == 0,
                                onTap: () {
                                  _tabController?.animateTo(0);
                                  setState(() {});
                                },
                              ),
                              ...categories.asMap().entries.map(
                                (entry) => _buildCategoryButton(
                                  text: _shortenText(
                                    entry.value['title_uz'],
                                    maxLength: 20,
                                  ),
                                  isSelected:
                                      _tabController?.index == entry.key + 1,
                                  onTap: () {
                                    _tabController?.animateTo(entry.key + 1);
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        "Kanallar soni: ${_getCurrentCategoryChannelCount()} ta",
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildChannelGrid('all'),
                            if (categories.isNotEmpty)
                              ...categories.map(
                                (category) => _buildChannelGrid(category['id']),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildCategoryButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: FocusScope(
        child: Builder(
          builder:
              (context) => GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[500] : Colors.blue[700],
                    borderRadius: BorderRadius.circular(8),
                    border:
                        FocusScope.of(context).hasFocus
                            ? Border.all(color: Colors.yellow, width: 2)
                            : null,
                    boxShadow:
                        FocusScope.of(context).hasFocus
                            ? [
                              BoxShadow(
                                color: Colors.yellow.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildChannelGrid(String categoryId) {
    final channels = channelsByCategory[categoryId] ?? [];
    return FocusScope(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        cacheExtent: 500,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return FocusScope(
            child: Builder(
              builder:
                  (context) => GestureDetector(
                    onTap:
                        () => _playChannel(
                          selectedSource == "SalomTV" ||
                                  selectedSource == "BizTV"
                              ? channel['url']
                              : channel['id'],
                          channel['title_uz'],
                          selectedSource,
                        ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform:
                          FocusScope.of(context).hasFocus
                              ? (Matrix4.identity()..scale(1.1))
                              : Matrix4.identity(),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                          if (FocusScope.of(context).hasFocus)
                            BoxShadow(
                              color: Colors.yellow.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                        ],
                        border:
                            FocusScope.of(context).hasFocus
                                ? Border.all(color: Colors.yellow, width: 2)
                                : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap:
                              () => _playChannel(
                                selectedSource == "SalomTV" ||
                                        selectedSource == "BizTV"
                                    ? channel['url']
                                    : channel['id'],
                                channel['title_uz'],
                                selectedSource,
                              ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CachedNetworkImage(
                                  imageUrl:
                                      channel['image'] ??
                                      'https://placehold.co/150x150',
                                  cacheManager: customCacheManager,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        height: 180,
                                        color: Colors.black.withOpacity(0.8),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        height: 180,
                                        color: Colors.black.withOpacity(0.8),
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _shortenText(
                                    channel['title_uz'] ?? 'Noma\'lum',
                                    maxLength: 20,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}
