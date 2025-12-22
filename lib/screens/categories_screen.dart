import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/utils/navigation.dart';
import 'package:shimmer/shimmer.dart';

final customCacheManager = CacheManager(
  Config(
    'filmImagesCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

// Matn blokining balandligi (global, FilmCard ham foydalanadi)
const double kTextBlockHeight = 60.0;

// Grid metrikasi (SliverGrid hisoblari bilan mos)
class _GridMetrics {
  final double itemWidth;
  final double itemHeight;
  final double rowHeight;
  final int rowSize;
  final double topPadding;

  const _GridMetrics({
    required this.itemWidth,
    required this.itemHeight,
    required this.rowHeight,
    required this.rowSize,
    required this.topPadding,
  });
}

class CategoriesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialCategory;

  const CategoriesScreen({super.key, this.initialCategory});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // Data
  List<dynamic> _categories = [];
  List<dynamic> _films = [];
  dynamic _selectedCategory;
  int _selectedCategoryIndex = 0;
  int _selectedFilmIndex = 0;

  // Paging
  int _currentPage = 1;
  final int _perPage = 20;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // Focus
  final FocusNode _pageFocusNode = FocusNode();
  bool _isOnChips = true;
  bool get _hasChips => widget.initialCategory == null;

  // Layout (IndexScreen Categories bilan mos)
  static const double _gridLeftPad = 24.0;
  static const double _gridRightPad = 16.0;
  static const double _horizontalPadding = _gridLeftPad + _gridRightPad; // 40
  static const double _itemMargin = 8.0;
  static const double _gridSpacing = 8.0;
  static const double _targetCards = 5.5; // ~5.5 kartani ko‘rsatish
  static const double _cardRatio = 1.5; // height = width * 1.5
  static const double _rowSpacing = 24.0; // qatordan qatorga masofa

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.initialCategory != null) {
      _categories = [widget.initialCategory];
      _selectedCategory = widget.initialCategory;
      _selectedCategoryIndex = 0;
      _isOnChips = false; // darhol gridga
      _fetchFilms(isRefresh: true);
    } else {
      _fetchCategories();
    }

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    _pageFocusNode.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  // -------- Grid metrics --------

  _GridMetrics _gridMetrics(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _gridLeftPad - _gridRightPad;

    // SliverGridDelegateWithMaxCrossAxisExtent’da ishlatiladigan extents bilan mos
    final maxCrossAxisExtent =
        ((screenWidth - _horizontalPadding - _itemMargin * _targetCards) /
            _targetCards) +
        _itemMargin;

    final rowSize = (availableWidth / maxCrossAxisExtent).floor().clamp(1, 10);
    final itemWidth = (availableWidth - _itemMargin * rowSize) / rowSize;
    final itemHeight = itemWidth * _cardRatio;
    // Row balandligi: karta + matn + rowSpacing (griddagi real vertikal ajratma)
    final rowHeight = itemHeight + kTextBlockHeight + _rowSpacing;

    return _GridMetrics(
      itemWidth: itemWidth,
      itemHeight: itemHeight,
      rowHeight: rowHeight,
      rowSize: rowSize,
      topPadding: 24, // SliverPadding(top: 24) bilan mos
    );
  }

  int _rowSizeForWidth() => _gridMetrics(context).rowSize;

  // -------- Fetching --------

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoading && _hasMore) {
          _fetchFilms();
        }
      });
    }
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getCategories();
      if (!mounted) return;

      final list = response['data'] ?? [];
      _categories = list;
      _isLoading = false;

      if (_categories.isNotEmpty) {
        if (widget.initialCategory != null) {
          _selectedCategoryIndex = _categories.indexWhere(
            (c) => c['id'] == widget.initialCategory!['id'],
          );
          if (_selectedCategoryIndex < 0) _selectedCategoryIndex = 0;
        } else {
          _selectedCategoryIndex = 0;
        }
        _selectedCategory = _categories[_selectedCategoryIndex];
        _fetchFilms(isRefresh: true);
      } else {
        _errorMessage = "Kategoriyalar mavjud emas";
        _showErrorDialog(_errorMessage!);
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Kategoriyalarni yuklashda xato: $e";
        _showErrorDialog(_errorMessage!);
      });
    }
  }

  Future<void> _fetchFilms({bool isRefresh = false}) async {
    if (_isLoading || _selectedCategory == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (isRefresh) {
        _currentPage = 1;
        _hasMore = true;
        _films.clear();
        _selectedFilmIndex = 0;
      }
    });

    try {
      final response = await ApiService.getFilmsByCategory(
        categoryId: _selectedCategory['id'],
        page: _currentPage,
        perPage: _perPage,
      );

      final newFilms = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] is Map ? response['meta'] : {};

      if (!mounted) return;

      setState(() {
        _films.addAll(newFilms);
        _isLoading = false;

        if (meta['currentPage'] != null && meta['pageCount'] != null) {
          final current = int.tryParse(meta['currentPage'].toString()) ?? 1;
          final total = int.tryParse(meta['pageCount'].toString()) ?? 1;
          if (current < total) {
            _hasMore = true;
            _currentPage++;
          } else {
            _hasMore = false;
            HapticFeedback.mediumImpact();
          }
        } else {
          _hasMore = newFilms.length == _perPage;
          if (_hasMore) _currentPage++;
        }
      });

      _precacheImages(newFilms);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Filmlarni yuklashda xato: $e";
        _showErrorDialog(_errorMessage!);
      });
    }
  }

  void _precacheImages(List<dynamic> films) {
    for (var film in films.take(10)) {
      String coverUrl = 'https://placehold.co/320x180';
      if (film['files'] != null && film['files'].isNotEmpty) {
        final file = film['files'][0];
        if (file['thumbnails'] != null &&
            file['thumbnails']['small'] != null &&
            file['thumbnails']['small']['src'] != null) {
          coverUrl = file['thumbnails']['small']['src'];
        } else if (file['link'] != null) {
          coverUrl = file['link'];
        }
      }
      precacheImage(
        CachedNetworkImageProvider(coverUrl, cacheManager: customCacheManager),
        context,
      );
    }
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });
    await _fetchFilms(isRefresh: true);
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
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
                          if (message.contains("Kategoriyalar")) {
                            _fetchCategories();
                          } else {
                            _fetchFilms(isRefresh: true);
                          }
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

  // -------- Fokus va navigatsiya --------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_categories.isEmpty) return KeyEventResult.ignored;
    final totalFilms = _films.length;

    if (_isOnChips && _hasChips) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_selectedCategoryIndex < _categories.length - 1) {
          setState(() {
            _selectedCategoryIndex++;
            _selectedCategory = _categories[_selectedCategoryIndex];
          });
          _fetchFilms(isRefresh: true);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_selectedCategoryIndex > 0) {
          setState(() {
            _selectedCategoryIndex--;
            _selectedCategory = _categories[_selectedCategoryIndex];
          });
          _fetchFilms(isRefresh: true);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (totalFilms > 0) {
          setState(() {
            _isOnChips = false;
            _selectedFilmIndex = 0;
          });
          _scrollToFilmIndex(force: true);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else {
      final lastIndex = totalFilms == 0 ? 0 : totalFilms - 1;
      final rowSize = _rowSizeForWidth();

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_selectedFilmIndex < lastIndex) {
          final prevRow = _selectedFilmIndex ~/ rowSize;
          setState(() => _selectedFilmIndex++);
          final newRow = _selectedFilmIndex ~/ rowSize;
          if (newRow != prevRow) _scrollToFilmIndex();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_selectedFilmIndex > 0) {
          final prevRow = _selectedFilmIndex ~/ rowSize;
          setState(() => _selectedFilmIndex--);
          final newRow = _selectedFilmIndex ~/ rowSize;
          if (newRow != prevRow) {
            _scrollToFilmIndex();
          }
          return KeyEventResult.handled;
        } else {
          if (_hasChips) {
            setState(() {
              _isOnChips = true;
            });
          }
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextRowIdx = _selectedFilmIndex + rowSize;
        if (nextRowIdx <= lastIndex) {
          setState(() => _selectedFilmIndex = nextRowIdx);
          _scrollToFilmIndex(force: true);
        } else if (_hasMore && !_isLoading) {
          _fetchFilms();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevRowIdx = _selectedFilmIndex - rowSize;
        if (prevRowIdx >= 0) {
          setState(() => _selectedFilmIndex = prevRowIdx);
          _scrollToFilmIndex(force: true);
        } else {
          if (_hasChips) {
            setState(() {
              _isOnChips = true;
            });
          }
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
        if (_selectedFilmIndex >= 0 && _selectedFilmIndex < _films.length) {
          final film = _films[_selectedFilmIndex];
          final filmId = film['id'];
          Navigator.push(
            context,
            createSlideRoute(FilmScreen(filmId: filmId)),
          ).then((_) => _pageFocusNode.requestFocus());
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToFilmIndex({bool force = false}) {
    if (!_scrollController.hasClients || _films.isEmpty) return;

    final metrics = _gridMetrics(context);
    final rowSize = metrics.rowSize;
    final targetRow = (_selectedFilmIndex ~/ rowSize);
    final targetOffset = metrics.topPadding + targetRow * metrics.rowHeight;

    final currentRow = ((_scrollController.offset - metrics.topPadding) /
            metrics.rowHeight)
        .round()
        .clamp(0, targetRow);

    if (!force && currentRow == targetRow) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    final clamped = targetOffset.clamp(0.0, maxOffset);
    final distance = (clamped - _scrollController.offset).abs();

    if (distance > 800) {
      _scrollController.jumpTo(clamped);
    } else {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  // -------- UI --------

  Widget _buildSkeletonLoader() {
    final metrics = _gridMetrics(context);
    final itemWidth = metrics.itemWidth;
    final itemHeight = metrics.itemHeight;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: itemWidth + _gridSpacing,
        mainAxisSpacing: _rowSpacing,
        crossAxisSpacing: _gridSpacing,
        childAspectRatio: itemWidth / (itemHeight + kTextBlockHeight),
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          period: const Duration(milliseconds: 1000),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText =
        _selectedCategory != null
            ? (_selectedCategory['title_uz'] ?? "Kategoriyalar")
            : (widget.initialCategory?['title_uz'] ?? "Kategoriyalar");

    final metrics = _gridMetrics(context);
    final itemWidth = metrics.itemWidth;
    final itemHeight = metrics.itemHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 4,
        title: Text(
          titleText,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Orqaga',
        ),
      ),
      body: Focus(
        autofocus: true,
        focusNode: _pageFocusNode,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.white,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 500,
              slivers: [
                if (_hasChips)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child:
                          _categories.isNotEmpty
                              ? SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _categories.length,
                                  itemBuilder: (context, index) {
                                    final category = _categories[index];
                                    final isSelected =
                                        index == _selectedCategoryIndex;
                                    final hasFocus = _isOnChips && isSelected;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryIndex = index;
                                          _selectedCategory = category;
                                        });
                                        _fetchFilms(isRefresh: true);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        margin: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? Colors.blue[500]
                                                  : Colors.blue[700],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border:
                                              hasFocus
                                                  ? Border.all(
                                                    color: Colors.yellow,
                                                    width: 2,
                                                  )
                                                  : Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                  ),
                                          boxShadow:
                                              hasFocus
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.yellow
                                                          .withOpacity(0.3),
                                                      blurRadius: 8,
                                                    ),
                                                  ]
                                                  : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.2),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            category['title_uz'] ?? 'Noma’lum',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),

                if (_isLoading && _films.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _buildSkeletonLoader()),
                  ),
                if (!_isLoading && _films.isEmpty && _errorMessage != null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchCategories,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
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
                              "Qayta urinish",
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isLoading && _films.isEmpty && _errorMessage == null)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        "Filmlar mavjud emas",
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                  ),

                // Grid (5.5 karta ko‘rinishi, aniq balandlik)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _gridLeftPad,
                    24,
                    _gridRightPad,
                    0,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: itemWidth + _itemMargin,
                      mainAxisSpacing: _rowSpacing,
                      crossAxisSpacing: _itemMargin,
                      childAspectRatio:
                          itemWidth / (itemHeight + kTextBlockHeight),
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final film = _films[index];
                      final isSelected =
                          !_isOnChips && index == _selectedFilmIndex;
                      return FilmCard(
                        film: film,
                        isSelected: isSelected,
                        onTap: () {
                          Navigator.push(
                            context,
                            createSlideRoute(FilmScreen(filmId: film['id'])),
                          ).then((_) => _pageFocusNode.requestFocus());
                        },
                        itemWidth: itemWidth,
                        itemHeight: itemHeight,
                      );
                    }, childCount: _films.length),
                  ),
                ),

                if (_isLoading && _films.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                if (!_hasMore && _films.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Barcha filmlar ko‘rsatildi",
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
            ),
          ),
        ),
      ),
    );
  }
}

// -------- Cards (IndexScreen Categories dizayniga mos) --------

class FilmCard extends StatelessWidget {
  final dynamic film;
  final bool isSelected;
  final VoidCallback onTap;
  final double itemWidth;
  final double itemHeight;

  const FilmCard({
    super.key,
    required this.film,
    required this.isSelected,
    required this.onTap,
    required this.itemWidth,
    required this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFF3B6C);
    final files = film['files'] ?? [];
    final imageUrl =
        files.isNotEmpty
            ? (files[0]['thumbnails'] != null &&
                    files[0]['thumbnails']['small'] != null &&
                    files[0]['thumbnails']['small']['src'] != null
                ? files[0]['thumbnails']['small']['src']
                : files[0]['link'] ?? 'https://placehold.co/320x180')
            : 'https://placehold.co/320x180';
    final title = film['name_uz'] ?? 'Noma’lum';
    final year = film['year']?.toString() ?? '';
    final genres = film['genres'] ?? [];
    final genreName = genres.isNotEmpty ? genres[0]['name_uz'] ?? '' : '';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: SizedBox(
          width: itemWidth,
          height: itemHeight + kTextBlockHeight, // butun hujayra balandligi
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Muqova + border
              SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.identity()..scale(isSelected ? 1.05 : 1.0),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border:
                        isSelected ? Border.all(color: pink, width: 2) : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheManager: customCacheManager,
                          fit: BoxFit.cover,
                          width: itemWidth,
                          height: itemHeight,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.black.withOpacity(0.8),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.black.withOpacity(0.8),
                              ),
                        ),
                        if (isSelected)
                          Container(
                            width: itemWidth,
                            height: itemHeight,
                            color: Colors.white.withOpacity(0.12),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: itemWidth,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: itemWidth,
                child: Text(
                  year.isNotEmpty && genreName.isNotEmpty
                      ? "$year · $genreName"
                      : year.isNotEmpty
                      ? year
                      : genreName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
