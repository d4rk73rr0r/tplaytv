import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final FocusNode? focusNode;

  @override
  State<TVChannelsScreen> createState() => TVChannelsScreenState();
}

class TVChannelsScreenState extends State<TVChannelsScreen> {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestFocusSafely();
      }
    });
  }

  @override
  void didUpdateWidget(TVChannelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestFocusSafely();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestFocusSafely();
      }
    });
  }

  void requestFocus() {
    debugPrint('🎯 TV Channels: requestFocus called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('🎯 TV Channels: Not mounted, skipping focus request');
        return;
      }
      
      if (_mainFocusNode.canRequestFocus && !_mainFocusNode.hasFocus) {
        _mainFocusNode.requestFocus();
        debugPrint(
          '🎯 TV Channels: Focus requested (hasFocus: ${_mainFocusNode.hasFocus}, '
          'canRequestFocus: ${_mainFocusNode.canRequestFocus})',
        );
      } else {
        debugPrint(
          '🎯 TV Channels: Focus already set or cannot request '
          '(hasFocus: ${_mainFocusNode.hasFocus}, canRequestFocus: ${_mainFocusNode.canRequestFocus})',
        );
      }
    });
  }

  void _requestFocusSafely() {
    requestFocus();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _categoriesScrollController.dispose();
    if (_ownsFocusNode) {
      _mainFocusNode.dispose();
    }

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
        if (mounted) _requestFocusSafely();
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

    final selectedPlayer = await _showPlayerSelectionDialog();

    if (mounted) _requestFocusSafely();

    if (selectedPlayer == null) {
      return;
    }

    if (selectedPlayer == 'better_player') {
      if (mounted) {
        await Navigator.push(
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
              notificationConfiguration:
                  const BetterPlayerNotificationConfiguration(
                    showNotification: false,
                  ),
            ),
          ),
        );
        if (mounted) _requestFocusSafely();
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

  Future<String?> _showPlayerSelectionDialog() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder:
          (dialogContext) => _PlayerSelectionDialog(
            onSelected: (value) => Navigator.pop(dialogContext, value),
            onCancel: () => Navigator.pop(dialogContext),
          ),
    );
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: false,
        builder:
            (dialogContext) => _ErrorDialog(
              message: message,
              onOk: () => Navigator.pop(dialogContext),
              onRetry: () {
                Navigator.pop(dialogContext);
                _refresh();
              },
            ),
      );
    }
  }

  // ---------- Focus & navigation ----------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_isBackKey(key)) {
      // Use maybePop to check if there's a route to pop
      // If false, it means we're on the main route and should let parent handle it
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      // Let parent (MainScreen) handle it - it will trigger exit menu
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f1) {
      setState(() => _focusArea = _FocusArea.sources);
      return KeyEventResult.handled;
    }

    final currentChannels = _currentChannels();
    final isGridEmpty = currentChannels.isEmpty;

    bool handled = false;
    setState(() {
      switch (_focusArea) {
        case _FocusArea.sources:
          handled = _handleSourcesNavigation(key);
          break;
        case _FocusArea.categories:
          handled = _handleCategoriesNavigation(key);
          break;
        case _FocusArea.grid:
          if (isGridEmpty) {
            if (key == LogicalKeyboardKey.arrowUp) {
              _focusArea =
                  categories.isNotEmpty
                      ? _FocusArea.categories
                      : _FocusArea.sources;
              handled = true;
            }
          } else {
            handled = _handleGridNavigation(key, currentChannels);
          }
          break;
      }
    });

    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB;
  }

  bool _handleSourcesNavigation(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft && _selectedSourceIndex > 0) {
      _selectedSourceIndex--;
      return true;
    } else if (key == LogicalKeyboardKey.arrowRight &&
        _selectedSourceIndex < _sources.length - 1) {
      _selectedSourceIndex++;
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _focusArea =
          categories.isNotEmpty ? _FocusArea.categories : _FocusArea.grid;
      return true;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      final newSource = _sources[_selectedSourceIndex];
      if (newSource != selectedSource) {
        _onSourceChanged(newSource);
      }
      return true;
    }
    return false;
  }

  bool _handleCategoriesNavigation(LogicalKeyboardKey key) {
    final maxIndex = categories.length;

    if (key == LogicalKeyboardKey.arrowLeft && _selectedCategoryIndex > 0) {
      _selectedCategoryIndex--;
      _selectedChannelIndex = 0;
      _scrollCategoryIntoView();
      _resetGridScroll();
      return true;
    } else if (key == LogicalKeyboardKey.arrowRight &&
        _selectedCategoryIndex < maxIndex) {
      _selectedCategoryIndex++;
      _selectedChannelIndex = 0;
      _scrollCategoryIntoView();
      _resetGridScroll();
      return true;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _focusArea = _FocusArea.sources;
      return true;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _focusArea = _FocusArea.grid;
      return true;
    }
    return false;
  }

  bool _handleGridNavigation(
    LogicalKeyboardKey key,
    List<dynamic> currentChannels,
  ) {
    final lastIndex = currentChannels.length - 1;

    // CHAPGA harakat
    if (key == LogicalKeyboardKey.arrowLeft) {
      // Agar birinchi ustundagi card bo‘lsak (0,5,10,...) ->
      // bu holatda Sidebar ochilishi uchun eventni parentga uzatamiz
      if (_selectedChannelIndex % _rowSize == 0) {
        return false; // false → KeyEventResult.ignored parentga
      }

      if (_selectedChannelIndex > 0) {
        _selectedChannelIndex--;
        _scrollToChannelIndex();
        return true;
      }
      return false;
    }

    // O'NGA
    if (key == LogicalKeyboardKey.arrowRight &&
        _selectedChannelIndex < lastIndex) {
      _selectedChannelIndex++;
      _scrollToChannelIndex();
      return true;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final nextIndex = _selectedChannelIndex + _rowSize;
      if (nextIndex <= lastIndex) {
        _selectedChannelIndex = nextIndex;
        _scrollToChannelIndex(force: true);
        return true;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final prevIndex = _selectedChannelIndex - _rowSize;
      if (prevIndex >= 0) {
        _selectedChannelIndex = prevIndex;
        _scrollToChannelIndex(force: true);
        return true;
      } else {
        _focusArea =
            categories.isNotEmpty ? _FocusArea.categories : _FocusArea.sources;
        return true;
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
      return true;
    } else if (key == LogicalKeyboardKey.keyR) {
      _refresh();
      return true;
    }
    return false;
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

  List<dynamic> _currentChannels() {
    final key =
        _selectedCategoryIndex == 0
            ? 'all'
            : categories[_selectedCategoryIndex - 1]['id'];
    return channelsByCategory[key] ?? [];
  }

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

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocusNode,
      autofocus: false,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(child: _buildChannelGrid()),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog widget'lari

class _PlayerSelectionDialog extends StatefulWidget {
  final Function(String) onSelected;
  final VoidCallback onCancel;

  const _PlayerSelectionDialog({
    required this.onSelected,
    required this.onCancel,
  });

  @override
  State<_PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<_PlayerSelectionDialog> {
  static const int _internalPlayerIndex = 0;
  static const int _externalPlayerIndex = 1;
  static const int _cancelIndex = 2;
  static const int _maxOptionIndex = 2;

  int _selectedIndex = 0;
  final FocusNode _dialogFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown &&
        _selectedIndex < _maxOptionIndex) {
      setState(() => _selectedIndex++);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp && _selectedIndex > 0) {
      setState(() => _selectedIndex--);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_selectedIndex == _internalPlayerIndex) {
        widget.onSelected('better_player');
      } else if (_selectedIndex == _externalPlayerIndex) {
        widget.onSelected('external');
      } else if (_selectedIndex == _cancelIndex) {
        widget.onCancel();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      widget.onCancel();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _dialogFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              _buildOption(
                _internalPlayerIndex,
                Icons.play_circle_filled,
                "Ichki pleer:  Better Player",
              ),
              _buildOption(
                _externalPlayerIndex,
                Icons.video_library,
                "Tashqi pleer bilan ochish",
              ),
              _buildOption(_cancelIndex, Icons.close, "Bekor qilish"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(int index, IconData icon, String text) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isSelected ? kPinkColor : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
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
    );
  }
}

class _ErrorDialog extends StatefulWidget {
  final String message;
  final VoidCallback onOk;
  final VoidCallback onRetry;

  const _ErrorDialog({
    required this.message,
    required this.onOk,
    required this.onRetry,
  });

  @override
  State<_ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<_ErrorDialog> {
  int _selectedButton = 0;
  final FocusNode _dialogFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft && _selectedButton > 0) {
      setState(() => _selectedButton--);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight && _selectedButton < 1) {
      setState(() => _selectedButton++);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_selectedButton == 0) {
        widget.onOk();
      } else {
        widget.onRetry();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _dialogFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Xato",
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
        content: Text(
          widget.message,
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.black.withOpacity(0.9),
        actions: [
          TextButton(
            onPressed: widget.onOk,
            style: TextButton.styleFrom(
              backgroundColor:
                  _selectedButton == 0 ? Colors.white : Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text(
              "OK",
              style: TextStyle(
                fontSize: 20,
                color: _selectedButton == 0 ? Colors.black : Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onRetry,
            style: TextButton.styleFrom(
              backgroundColor:
                  _selectedButton == 1 ? kPinkColor : Colors.grey[800],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
