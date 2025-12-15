import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/screens/favorites_screen.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_iconly/flutter_iconly.dart';

final customCacheManager = CacheManager(
  Config(
    'LatestViewedCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class LatestViewedScreen extends StatefulWidget {
  const LatestViewedScreen({super.key});

  @override
  State<LatestViewedScreen> createState() => _LatestViewedScreenState();
}

class _LatestViewedScreenState extends State<LatestViewedScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _LatestViewed = [];
  bool _isLoading = false;
  String? _error;
  bool _isEditing = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchLatestViewed();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _fetchLatestViewed({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset) || !mounted) {
      debugPrint(
        'Fetch stopped: isLoading=$_isLoading, hasMore=$_hasMore, reset=$reset',
      );
      return;
    }
    debugPrint('Fetching last viewed, page: $_page');
    setState(() {
      _isLoading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
        _LatestViewed.clear();
      }
    });
    try {
      final response = await ApiService.getLatestViewed(
        page: _page,
        perPage: 20,
        isAll: true,
        fields:
            'name_uz,name_ru,name_en,id,films.id,films.name_uz,films.name_ru,films.publish_time,films.type,films.paid,films.year,films.tags.id,films.tags.title_uz,films.tags.title_en,films.files.thumbnails,films.genres.name_uz,films.genres.name_ru,films.genres.name_en',
      );
      debugPrint('API response for page $_page: $response');
      final results = response['data'] as List<dynamic>? ?? [];
      final meta = response['_meta'] as Map<String, dynamic>? ?? {};
      debugPrint('Results length: ${results.length}, Meta: $meta');
      if (mounted) {
        setState(() {
          final existingIds =
              _LatestViewed.map((item) => item['film']['id']).toSet();
          final newItems =
              results
                  .where((item) => !existingIds.contains(item['film']['id']))
                  .toList();
          debugPrint('New items: ${newItems.length}');
          _LatestViewed.addAll(newItems);
          _page++;
          if (newItems.isNotEmpty) {
            _precacheImages(newItems);
          }
          final totalCount = (meta['totalCount'] as num?)?.toInt() ?? 0;
          final pageCount = (meta['pageCount'] as num?)?.toInt() ?? 1;
          _hasMore =
              results.isNotEmpty &&
              _page <= pageCount &&
              _LatestViewed.length < totalCount;
          debugPrint(
            'Updated hasMore: $_hasMore, page: $_page, totalCount: $totalCount, results: ${results.length}',
          );
          _isLoading = false;
          if (_LatestViewed.isEmpty) {
            _error = "Hozircha so'ngi ko'rilganlar yo'q";
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Ma'lumotlarni yuklashda xatolik: $e";
          _showErrorDialog(_error!);
        });
      }
    }
  }

  void _precacheImages(List<dynamic> items) {
    final visibleItems = items.take(10).toList();
    for (var item in visibleItems) {
      final screenshots = item['screenshots'] as List<dynamic>? ?? [];
      final file =
          screenshots.isNotEmpty
              ? (screenshots[0]['file'] as List<dynamic>?)?.first ?? {}
              : {};
      final imageUrl =
          screenshots.isNotEmpty
              ? (file['thumbnails'] != null &&
                      file['thumbnails']['small'] != null &&
                      file['thumbnails']['small']['src'] != null
                  ? file['thumbnails']['small']['src']
                  : file['link'] ?? 'https://placehold.co/320x180')
              : 'https://placehold.co/320x180';
      precacheImage(
        CachedNetworkImageProvider(imageUrl, cacheManager: customCacheManager),
        context,
        onError: (exception, stackTrace) {
          debugPrint('Precache image error: $exception');
        },
      );
    }
  }

  Future<void> _refresh() async {
    debugPrint('RefreshIndicator triggered');
    await _fetchLatestViewed(reset: true);
    if (mounted) {
      setState(() => _isEditing = false);
    }
  }

  void _onScroll() {
    if (_hasMore &&
        _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      debugPrint('Scroll triggered, fetching page: $_page');
      _fetchLatestViewed();
    }
  }

  void _toggleEditMode() {
    if (mounted) {
      setState(() => _isEditing = !_isEditing);
    }
  }

  Future<void> _removeLatestViewed(int filmId) async {
    debugPrint('Removing last viewed item with filmId: $filmId');
    if (filmId == 0) {
      _showErrorDialog("Film ID topilmadi");
      return;
    }

    final success = await ApiService.removeFromLatestViewed(filmId);
    debugPrint('Remove success: $success');
    if (success && mounted) {
      setState(() {
        _LatestViewed.removeWhere(
          (item) => item['second']['film_id'] == filmId,
        );
        debugPrint('Removed filmId $filmId from _LatestViewed');
        if (_LatestViewed.isEmpty) {
          _error = "Hozircha so'ngi ko'rilganlar yo'q";
        }
      });
    } else if (mounted) {
      debugPrint('Failed to remove filmId: $filmId');
      _showErrorDialog("Kontentni o'chirishda xatolik");
    }
  }

  Future<void> _clearLatestViewed() async {
    final success = await ApiService.clearLatestViewed();
    if (success && mounted) {
      setState(() {
        _LatestViewed.clear();
        _error = "Hozircha so'ngi ko'rilganlar yo'q";
      });
    } else if (mounted) {
      _showErrorDialog("Barchasini o'chirishda xatolik");
    }
  }

  void _showClearAllDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Barchasini o'chirish",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              content: const Text(
                "Barcha so'ngi ko'rilganlarni o'chirmoqchimisiz?",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              backgroundColor: Colors.black.withOpacity(0.8),
              actions: [
                FocusScope(
                  child: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _clearLatestViewed();
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
                            "O'chirish",
                            style: TextStyle(fontSize: 20, color: Colors.white),
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
                            "Bekor qilish",
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
                            _fetchLatestViewed(reset: true);
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

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
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
        title: const Text(
          'Ko‘rishni davom ettirish',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: FocusScope(
          child: Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
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
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.white,
        child: ContentWidget(
          latestviewed: _LatestViewed,
          isLoading: _isLoading,
          error: _error,
          isEditing: _isEditing,
          hasMore: _hasMore,
          scrollController: _scrollController,
          onToggleEditMode: _toggleEditMode,
          onShowClearAllDialog: _showClearAllDialog,
          onRemoveLatestViewed: _removeLatestViewed,
          animationController: _animationController,
          scaleAnimation: _scaleAnimation,
          onRefresh: _refresh,
        ),
      ),
    );
  }
}

class ContentWidget extends StatelessWidget {
  final List<dynamic> latestviewed;
  final bool isLoading;
  final String? error;
  final bool isEditing;
  final bool hasMore;
  final ScrollController scrollController;
  final VoidCallback onToggleEditMode;
  final VoidCallback onShowClearAllDialog;
  final ValueChanged<int> onRemoveLatestViewed;
  final AnimationController animationController;
  final Animation<double> scaleAnimation;
  final Future<void> Function() onRefresh;

  const ContentWidget({
    super.key,
    required this.latestviewed,
    required this.isLoading,
    required this.error,
    required this.isEditing,
    required this.hasMore,
    required this.scrollController,
    required this.onToggleEditMode,
    required this.onShowClearAllDialog,
    required this.onRemoveLatestViewed,
    required this.animationController,
    required this.scaleAnimation,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && latestviewed.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6),
      );
    }

    if (latestviewed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error ?? "Hozircha so'ngi ko'rilganlar yo'q",
              style: const TextStyle(fontSize: 24, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FocusScope(
              child: Builder(
                builder:
                    (context) => ElevatedButton(
                      onPressed: onRefresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            FocusScope.of(context).hasFocus
                                ? Colors.blue[500]
                                : Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        "Qayta yuklash",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedButtonsHeader(
            isEditing: isEditing,
            onToggleEditMode: onToggleEditMode,
            onShowClearAllDialog: onShowClearAllDialog,
            animationController: animationController,
            scaleAnimation: scaleAnimation,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => LatestViewedCardStateful(
                item: latestviewed[index],
                isEditing: isEditing,
                onRemove:
                    () => onRemoveLatestViewed(
                      latestviewed[index]['second']['film_id'],
                    ),
              ),
              childCount: latestviewed.length,
            ),
          ),
        ),
        if (isLoading && latestviewed.isNotEmpty)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              ),
            ),
          ),
        if (!hasMore && latestviewed.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "Barcha so'ngi ko'rilganlar yuklandi",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Convert LatestViewedCard to a Stateful widget with its own FocusNode so it can receive focus
class LatestViewedCardStateful extends StatefulWidget {
  final dynamic item;
  final bool isEditing;
  final VoidCallback onRemove;

  const LatestViewedCardStateful({
    super.key,
    required this.item,
    required this.isEditing,
    required this.onRemove,
  });

  @override
  State<LatestViewedCardStateful> createState() =>
      _LatestViewedCardStatefulState();
}

class _LatestViewedCardStatefulState extends State<LatestViewedCardStateful> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleActivate() {
    final film = widget.item['film'] as Map<String, dynamic>? ?? {};
    final second = widget.item['second'] as Map<String, dynamic>? ?? {};
    final filmId = second['film_id'] ?? 0;
    if (!widget.isEditing) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FilmScreen(filmId: filmId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final film = widget.item['film'] as Map<String, dynamic>? ?? {};
    final screenshots = widget.item['screenshots'] as List<dynamic>? ?? [];
    final second = widget.item['second'] as Map<String, dynamic>? ?? {};
    final file =
        screenshots.isNotEmpty
            ? (screenshots[0]['file'] as List<dynamic>?)?.first ?? {}
            : {};
    final imageUrl =
        screenshots.isNotEmpty
            ? (file['thumbnails'] != null &&
                    file['thumbnails']['small'] != null &&
                    file['thumbnails']['small']['src'] != null
                ? file['thumbnails']['small']['src']
                : file['link'] ?? 'https://placehold.co/320x180')
            : 'https://placehold.co/320x180';
    final filmId = second['film_id'] ?? 0;
    final viewedTime = second['time'] ?? 0;
    final playbackTime = film['playback_time'] ?? 1;
    final viewedMinutes = (viewedTime / 60).floor();
    final viewedSeconds = viewedTime % 60;
    final viewedTimeString =
        '${viewedMinutes.toString().padLeft(2, '0')}:${viewedSeconds.toString().padLeft(2, '0')}';
    final double progress =
        playbackTime > 0 ? (viewedTime / (playbackTime * 60)) : 0.0;
    final year = film['year']?.toString() ?? 'Noma\'lum';
    final genres = film['genres'] as List<dynamic>? ?? [];
    final genre =
        genres.isNotEmpty ? genres[0]['name_uz'] ?? 'Noma\'lum' : 'Noma\'lum';

    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _handleActivate();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (focused) {
        setState(() {
          _hasFocus = focused;
        });
      },
      child: GestureDetector(
        onTap: () {
          if (!widget.isEditing) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FilmScreen(filmId: filmId),
              ),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform:
              _hasFocus ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.8),
            border:
                _hasFocus ? Border.all(color: Colors.yellow, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              if (_hasFocus)
                BoxShadow(color: Colors.yellow.withOpacity(0.3), blurRadius: 8),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (!widget.isEditing) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilmScreen(filmId: filmId),
                    ),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheManager: customCacheManager,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 250,
                          maxHeightDiskCache: 400,
                          fadeInDuration: const Duration(milliseconds: 300),
                          placeholder:
                              (context, url) => Container(
                                height: 250,
                                color: Colors.black.withOpacity(0.8),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                height: 250,
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
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                viewedTimeString,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                              minHeight: 4,
                            ),
                          ],
                        ),
                      ),
                      if (widget.isEditing)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: widget.onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    _hasFocus
                                        ? Colors.blue[500]
                                        : Colors.blue[700],
                                shape: BoxShape.circle,
                                border:
                                    _hasFocus
                                        ? Border.all(
                                          color: Colors.yellow,
                                          width: 2,
                                        )
                                        : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                  if (_hasFocus)
                                    BoxShadow(
                                      color: Colors.yellow.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                ],
                              ),
                              child: const Icon(
                                IconlyLight.delete,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          film['name_uz'] ?? 'Noma\'lum',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$year, $genre",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
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
      ),
    );
  }
}
