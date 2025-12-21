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

class CategoriesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialCategory;

  const CategoriesScreen({super.key, this.initialCategory});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _films = [];
  dynamic _selectedCategory;
  int _currentPage = 1;
  final int _perPage = 20;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchCategories();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _fetchFilms);
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

      setState(() {
        _categories = response['data'] ?? [];
        _isLoading = false;

        if (_categories.isNotEmpty) {
          _selectedCategory =
              widget.initialCategory != null
                  ? _categories.firstWhere(
                    (category) =>
                        category['id'] == widget.initialCategory!['id'],
                    orElse: () => _categories.first,
                  )
                  : _categories.first;
          _fetchFilms(isRefresh: true);
        } else {
          _errorMessage = "Kategoriyalar mavjud emas";
          _showErrorDialog(_errorMessage!);
        }
      });
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
  }

  Widget _buildSkeletonLoader() {
    final cardWidth = MediaQuery.of(context).size.width / 3 - 24;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      height: 250,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: cardWidth * 0.9,
                        height: 22,
                        color: Colors.black.withOpacity(0.8),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 80,
                        height: 18,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 4,
        title: Text(
          widget.initialCategory?['title_uz'] ?? "Kategoriyalar",
          style: const TextStyle(
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.white,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent: 500,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child:
                      _categories.isNotEmpty && widget.initialCategory == null
                          ? SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected =
                                    category['id'] == _selectedCategory?['id'];
                                return FocusScope(
                                  child: Builder(
                                    builder:
                                        (context) => GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedCategory = category;
                                            });
                                            _fetchFilms(isRefresh: true);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border:
                                                  FocusScope.of(
                                                        context,
                                                      ).hasFocus
                                                      ? Border.all(
                                                        color: Colors.yellow,
                                                        width: 2,
                                                      )
                                                      : Border.all(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                      ),
                                              boxShadow:
                                                  FocusScope.of(
                                                        context,
                                                      ).hasFocus
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
                                                category['title_uz'] ??
                                                    'Noma’lum',
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
                        FocusScope(
                          child: Builder(
                            builder:
                                (context) => ElevatedButton(
                                  onPressed: _fetchCategories,
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
                                    "Qayta urinish",
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => FilmCard(film: _films[index]),
                    childCount: _films.length,
                  ),
                ),
              ),
              if (_isLoading && _films.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(child: _buildSkeletonLoader()),
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
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }
}

class FilmCard extends StatelessWidget {
  final dynamic film;

  const FilmCard({super.key, required this.film});

  @override
  Widget build(BuildContext context) {
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
    final filmId = film['id'];

    return FocusScope(
      child: Builder(
        builder:
            (context) => GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    createSlideRoute(FilmScreen(filmId: filmId)),
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
                  border:
                      FocusScope.of(context).hasFocus
                          ? Border.all(color: Colors.yellow, width: 2)
                          : null,
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
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        () => Navigator.push(
                          context,
                          createSlideRoute(FilmScreen(filmId: filmId)),
                        ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              cacheManager: customCacheManager,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 250,
                              maxHeightDiskCache: 300,
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
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                year.isNotEmpty && genreName.isNotEmpty
                                    ? "$year · $genreName"
                                    : year.isNotEmpty
                                    ? year
                                    : genreName,
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
      ),
    );
  }
}
