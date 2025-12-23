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

const Color kPinkColor = Color(0xFFFF3B6C);

enum _FocusArea { sources, categories, grid }

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
  const TVChannelsScreen({super.key, this.focusNode});

  /// Agar parent fokusni nazorat qilmoqchi bo‘lsa, shu yerga uzatadi.
  final FocusNode? focusNode;

  @override
  State<TVChannelsScreen> createState() => _TVChannelsScreenState();
}

class _TVChannelsScreenState extends State<TVChannelsScreen> {
  // Data
  List<dynamic> categories = [];
  Map<String, List<dynamic>> channelsByCategory = {};
  String selectedSource = "SalomTV";
  late final List<String> _sources = TVApiService.baseUrls.keys.toList();
  int totalChannels = 0;

  // Focus & selection
  _FocusArea _focusArea = _FocusArea.grid;
  int _selectedSourceIndex = 0;
  int _selectedCategoryIndex = 0;
  int _selectedChannelIndex = 0;

  // Loading
  bool _isLoading = true;

  // Scroll
  final ScrollController _gridScrollController = ScrollController();
  final ScrollController _categoriesScrollController = ScrollController();

  // Focus nodes
  late final FocusNode _internalFocusNode = FocusNode(debugLabel: 'TVMain');
  FocusNode get _mainFocusNode => widget.focusNode ?? _internalFocusNode;
  bool get _ownsFocusNode => widget.focusNode == null;

  // Layout
  static const int _rowSize = 5;
  static const double _cardSpacing = 16.0;
  static const double _cardAspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _selectedSourceIndex = _sources
        .indexOf(selectedSource)
        .clamp(0, _sources.length - 1);
    _loadTVData();

    // Request focus when the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mainFocusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(TVChannelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Request focus when widget updates (e.g., when navigating back to this screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_mainFocusNode.hasFocus) {
        _mainFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Request focus when the screen becomes visible in the IndexedStack
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_mainFocusNode.hasFocus) {
        _mainFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _categoriesScrollController.dispose();
    if (_ownsFocusNode) {
      _mainFocusNode.dispose();
    }

    // Revert orientation & system UI for the rest of the app
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  // ---------- Data fetching ----------
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
        _selectedCategoryIndex = 0;
        _selectedChannelIndex = 0;
        _focusArea = _FocusArea.grid;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
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
      _selectedCategoryIndex = 0;
      _selectedChannelIndex = 0;
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

  // ---------- Player ----------
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
            backgroundColor: Colors.black.withOpacity(0.9),
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
                  backgroundColor: Colors.grey[800],
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
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          data: videoUrl,
          type: 'video/*',
        );
        await intent.launch();
      } catch (e) {
        if (mounted) _showErrorDialog("Tashqi pleerni ochishda xato: $e");
      }
    }
  }

  Widget _buildPlayerOption(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String value,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 20, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Focus & navigation ----------
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    // Back: kengaytirilgan qo'llab-quvvatlash
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.pop(context);
      return;
    }

    final currentChannels = _currentChannels();
    final isGridEmpty = currentChannels.isEmpty;

    setState(() {
      switch (_focusArea) {
        case _FocusArea.sources:
          _handleSourcesNavigation(key);
          break;
        case _FocusArea.categories:
          _handleCategoriesNavigation(key);
          break;
        case _FocusArea.grid:
          if (isGridEmpty) {
            // Bo'sh holatda yuqoriga qaytish va kategoriyaga/source'ga o'tish
            if (key == LogicalKeyboardKey.arrowUp) {
              _focusArea =
                  categories.isNotEmpty
                      ? _FocusArea.categories
                      : _FocusArea.sources;
            }
          } else {
            _handleGridNavigation(key, currentChannels);
          }
          break;
      }
    });
  }

  void _handleSourcesNavigation(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft && _selectedSourceIndex > 0) {
      _selectedSourceIndex--;
    } else if (key == LogicalKeyboardKey.arrowRight &&
        _selectedSourceIndex < _sources.length - 1) {
      _selectedSourceIndex++;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _focusArea =
          categories.isNotEmpty ? _FocusArea.categories : _FocusArea.grid;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      final newSource = _sources[_selectedSourceIndex];
      if (newSource != selectedSource) {
        _onSourceChanged(newSource);
      }
    }
  }

  void _handleCategoriesNavigation(LogicalKeyboardKey key) {
    final maxIndex = categories.length;

    if (key == LogicalKeyboardKey.arrowLeft && _selectedCategoryIndex > 0) {
      _selectedCategoryIndex--;
      _selectedChannelIndex = 0;
      _scrollCategoryIntoView();
      _resetGridScroll();
    } else if (key == LogicalKeyboardKey.arrowRight &&
        _selectedCategoryIndex < maxIndex) {
      _selectedCategoryIndex++;
      _selectedChannelIndex = 0;
      _scrollCategoryIntoView();
      _resetGridScroll();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _focusArea = _FocusArea.sources;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _focusArea = _FocusArea.grid;
    }
  }

  void _handleGridNavigation(
    LogicalKeyboardKey key,
    List<dynamic> currentChannels,
  ) {
    final lastIndex = currentChannels.length - 1;

    if (key == LogicalKeyboardKey.arrowRight &&
        _selectedChannelIndex < lastIndex) {
      _selectedChannelIndex++;
      _scrollToChannelIndex();
    } else if (key == LogicalKeyboardKey.arrowLeft &&
        _selectedChannelIndex > 0) {
      _selectedChannelIndex--;
      _scrollToChannelIndex();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final nextIndex = _selectedChannelIndex + _rowSize;
      if (nextIndex <= lastIndex) {
        _selectedChannelIndex = nextIndex;
        _scrollToChannelIndex(force: true);
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final prevIndex = _selectedChannelIndex - _rowSize;
      if (prevIndex >= 0) {
        _selectedChannelIndex = prevIndex;
        _scrollToChannelIndex(force: true);
      } else {
        _focusArea =
            categories.isNotEmpty ? _FocusArea.categories : _FocusArea.sources;
      }
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      final channel = currentChannels[_selectedChannelIndex];
      _playChannel(
        selectedSource == "SalomTV" || selectedSource == "BizTV"
            ? channel['url']
            : channel['id'],
        channel['title_uz'],
        selectedSource,
      );
    } else if (key == LogicalKeyboardKey.keyR) {
      _refresh();
    }
  }

  void _scrollToChannelIndex({bool force = false}) {
    if (!_gridScrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        (screenWidth - 48 - (_rowSize - 1) * _cardSpacing) / _rowSize;
    final cardHeight = cardWidth / _cardAspectRatio;

    final targetRow = _selectedChannelIndex ~/ _rowSize;
    final targetOffset = targetRow * (cardHeight + _cardSpacing);

    final viewportHeight = _gridScrollController.position.viewportDimension;
    final currentOffset = _gridScrollController.offset;

    final isVisible =
        targetOffset >= currentOffset &&
        (targetOffset + cardHeight) <= (currentOffset + viewportHeight);

    if (!force && isVisible) return;

    final maxOffset = _gridScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    _gridScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollCategoryIntoView() {
    if (!_categoriesScrollController.hasClients) return;

    const itemWidth = 150.0;
    final targetOffset = _selectedCategoryIndex * (itemWidth + 24);
    final viewportWidth =
        _categoriesScrollController.position.viewportDimension;
    final currentOffset = _categoriesScrollController.offset;

    final isVisible =
        targetOffset >= currentOffset &&
        (targetOffset + itemWidth) <= (currentOffset + viewportWidth);

    if (isVisible) return;

    final maxOffset = _categoriesScrollController.position.maxScrollExtent;
    final clampedOffset = (targetOffset - viewportWidth / 2 + itemWidth / 2)
        .clamp(0.0, maxOffset);

    _categoriesScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetGridScroll() {
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(0);
    }
  }

  // ---------- Helpers ----------
  void _onSourceChanged(String newSource) {
    if (newSource != selectedSource && mounted) {
      setState(() {
        selectedSource = newSource;
        categories.clear();
        channelsByCategory.clear();
        _isLoading = true;
        _selectedCategoryIndex = 0;
        _selectedChannelIndex = 0;
      });
      _loadTVData();
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
              title: const Text(
                "Xato",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              content: Text(
                message,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              backgroundColor: Colors.black.withOpacity(0.9),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[800],
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
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _refresh();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: kPinkColor,
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
              ],
            ),
      );
    }
  }

  List<dynamic> _currentChannels() {
    final key =
        _selectedCategoryIndex == 0
            ? 'all'
            : categories[_selectedCategoryIndex - 1]['id'];
    return channelsByCategory[key] ?? [];
  }

  int _currentChannelCount() => _currentChannels().length;

  // ---------- UI ----------
  Widget _buildSourceRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children:
            _sources.asMap().entries.map((entry) {
              final idx = entry.key;
              final source = entry.value;
              final isSelected = selectedSource == source;
              final isFocused =
                  _focusArea == _FocusArea.sources &&
                  idx == _selectedSourceIndex;

              return Padding(
                padding: const EdgeInsets.only(right: 24.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedSourceIndex = idx);
                    _onSourceChanged(source);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? kPinkColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isFocused
                                ? Colors.white
                                : (isSelected ? kPinkColor : Colors.grey[700]!),
                        width: isFocused ? 3 : 2,
                      ),
                    ),
                    child: Text(
                      source,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCategoriesRow() {
    if (categories.isEmpty) return const SizedBox.shrink();

    final allCategories = [
      {'id': 'all', 'title_uz': 'Barchasi'},
      ...categories,
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        controller: _categoriesScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = _selectedCategoryIndex == index;
          final isFocused =
              _focusArea == _FocusArea.categories &&
              _selectedCategoryIndex == index;

          return Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                  _selectedChannelIndex = 0;
                });
                _resetGridScroll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border:
                      isFocused
                          ? const Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                          )
                          : null,
                ),
                child: Center(
                  child: Text(
                    category['title_uz'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? kPinkColor : Colors.white,
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

  Widget _buildChannelGrid() {
    final channels = _currentChannels();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPinkColor, strokeWidth: 6),
      );
    }

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Kanallar mavjud emas",
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kPinkColor, width: 2),
              ),
              onPressed: _refresh,
              child: const Text(
                "Qayta yuklash",
                style: TextStyle(color: kPinkColor, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _gridScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _rowSize,
        mainAxisSpacing: _cardSpacing,
        crossAxisSpacing: _cardSpacing,
        childAspectRatio: _cardAspectRatio,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isSelected =
            _focusArea == _FocusArea.grid && index == _selectedChannelIndex;
        return _buildChannelCard(
          channel: channel,
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedChannelIndex = index);
            _playChannel(
              selectedSource == "SalomTV" || selectedSource == "BizTV"
                  ? channel['url']
                  : channel['id'],
              channel['title_uz'],
              selectedSource,
            );
          },
        );
      },
    );
  }

  Widget _buildChannelCard({
    required dynamic channel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isSelected ? 1.08 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: kPinkColor, width: 3) : null,
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: kPinkColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: channel['image'] ?? 'https://placehold.co/300x169',
                cacheManager: customCacheManager,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    channel['title_uz'] ?? 'Noma\'lum',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _mainFocusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with reload button for TV (remote-friendly)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildSourceRow()),
                    IconButton(
                      tooltip: "Qayta yuklash (R)",
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (categories.isNotEmpty) _buildCategoriesRow(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Kanallar: ${_currentChannelCount()}",
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: kPinkColor,
                  child: _buildChannelGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
