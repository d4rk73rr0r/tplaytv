import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'filmImagesCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _categories = [];
  Map<String, List<dynamic>> _filmsByCategory = {};
  Map<String, bool> _isLoadingByCategory = {};
  Map<String, bool> _isLoadingMoreByCategory = {};
  Map<String, int> _pageByCategory = {};
  Map<String, ScrollController> _scrollControllers = {};
  Map<String, String> _errorByCategory = {};
  late TabController _tabController;
  bool _isInitialLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final Map<int, bool> _favorites = {};
  final Map<int, bool> _isAnimatingFavorites = {};
  final Map<int, double> _favoriteScales = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
    });

    try {
      await _fetchCategories();
      _fetchFilms('', reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _errorByCategory[''] = "Ma'lumotlarni yuklashda xatolik: $e";
          _showErrorDialog(_errorByCategory['']!);
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _categories.clear();
      _filmsByCategory.clear();
      _favorites.clear();
      _isAnimatingFavorites.clear();
      _favoriteScales.clear();
      _errorByCategory.clear();
      _pageByCategory.clear();
      _isLoadingByCategory.clear();
      _isLoadingMoreByCategory.clear();
      _scrollControllers.forEach((_, controller) => controller.dispose());
      _scrollControllers.clear();
      _searchController.clear();
      _isInitialLoading = true;
    });
    await _fetchInitialData();
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() => _isInitialLoading = true);

    try {
      final response = await ApiService.sendRequest(
        url: '${ApiService.baseUrl}/v1/types?filter[status]=1&sort=sort',
        headers: {"Authorization": "Bearer ${await _getAuthToken()}"},
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          if (response['success'] == false) {
            _errorByCategory[''] =
                'Kategoriyalarni yuklashda xato: ${response['error']}';
            _showErrorDialog(_errorByCategory['']!);
          } else {
            _categories = (response['data'] as List<dynamic>?) ?? [];
            _filmsByCategory[''] = [];
            _isLoadingByCategory[''] = false;
            _isLoadingMoreByCategory[''] = false;
            _pageByCategory[''] = 1;
            _scrollControllers[''] = ScrollController();
            _scrollControllers['']!.addListener(() => _onScroll(''));
            _errorByCategory[''] = '';
            for (var category in _categories) {
              final categoryId = category['id'].toString();
              _filmsByCategory[categoryId] = [];
              _isLoadingByCategory[categoryId] = false;
              _isLoadingMoreByCategory[categoryId] = false;
              _pageByCategory[categoryId] = 1;
              _scrollControllers[categoryId] = ScrollController();
              _scrollControllers[categoryId]!.addListener(
                () => _onScroll(categoryId),
              );
              _errorByCategory[categoryId] = '';
            }
          }
          _isInitialLoading = false;
          _tabController = TabController(
            length: _categories.length + 1,
            vsync: this,
          );
          _tabController.addListener(() {
            if (!_tabController.indexIsChanging) {
              final categoryId =
                  _tabController.index == 0
                      ? ''
                      : _categories[_tabController.index - 1]['id'].toString();
              if (_filmsByCategory[categoryId]!.isEmpty &&
                  !_isLoadingMoreByCategory[categoryId]!) {
                _fetchFilms(categoryId, reset: true);
              }
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _errorByCategory[''] = 'Kategoriyalarni yuklashda xato: $e';
          _showErrorDialog(_errorByCategory['']!);
        });
      }
    }
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _fetchFilms(String categoryId, {bool reset = false}) async {
    if (_isLoadingByCategory[categoryId] == true || !mounted) return;

    setState(() {
      _isLoadingByCategory[categoryId] = true;
      if (reset) {
        _errorByCategory[categoryId] = '';
      }
    });

    if (reset) {
      _pageByCategory[categoryId] = 1;
      _filmsByCategory[categoryId] = [];
    }

    try {
      final results = await ApiService.searchFilms(
        _searchQuery,
        _pageByCategory[categoryId]!,
        categoryId,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          final existingIds =
              _filmsByCategory[categoryId]!.map((film) => film['id']).toSet();
          final newFilms =
              results
                  .where((film) => !existingIds.contains(film['id']))
                  .toList();

          if (newFilms.isNotEmpty) {
            _filmsByCategory[categoryId]!.addAll(newFilms);
            for (var film in newFilms) {
              final filmId = film['id'] as int;
              _favorites[filmId] =
                  film.containsKey('favorite') && film['favorite'] == 1;
              _isAnimatingFavorites[filmId] = false;
              _favoriteScales[filmId] = 1.0;
            }
            _pageByCategory[categoryId] = _pageByCategory[categoryId]! + 1;
            _precacheImages(newFilms);
          } else if (_filmsByCategory[categoryId]!.isEmpty) {
            _errorByCategory[categoryId] = "Hech qanday film topilmadi";
            _showErrorDialog(_errorByCategory[categoryId]!);
          }
          _isLoadingByCategory[categoryId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingByCategory[categoryId] = false;
          _errorByCategory[categoryId] = "Kontentlarni yuklashda xatolik: $e";
          _showErrorDialog(_errorByCategory[categoryId]!);
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
      _fetchFilms('', reset: true);
      for (var category in _categories) {
        _fetchFilms(category['id'].toString(), reset: true);
      }
    });
  }

  void _onScroll(String categoryId) {
    final controller = _scrollControllers[categoryId];
    if (controller!.position.pixels >=
            controller.position.maxScrollExtent - 200 &&
        !_isLoadingByCategory[categoryId]!) {
      _fetchFilms(categoryId, reset: false);
    }
  }

  void _precacheImages(List<dynamic> films) {
    for (var film in films.take(10)) {
      final files = film['files'] ?? [];
      final coverUrl =
          files.isNotEmpty
              ? (files[0]['thumbnails']?['small']?['src'] ??
                  'https://placehold.co/320x180')
              : 'https://placehold.co/320x180';
      precacheImage(
        CachedNetworkImageProvider(coverUrl, cacheManager: customCacheManager),
        context,
      );
    }
  }

  void _toggleSearch() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.black.withOpacity(0.8),
            title: const Text(
              "Qidiruv",
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            content: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Film, serial nomi...",
                hintStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 20, color: Colors.white),
              autofocus: true,
            ),
            actions: [
              FocusScope(
                child: Builder(
                  builder:
                      (context) => TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          Navigator.pop(context);
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
                          "Tozalash",
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

  Future<void> _toggleFavorite(int filmId) async {
    if (_isAnimatingFavorites[filmId] ?? false || !mounted) return;

    setState(() {
      _isAnimatingFavorites[filmId] = true;
      _favoriteScales[filmId] = 1.5;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    if (mounted) {
      setState(() {
        _favoriteScales[filmId] = 1.0;
      });
    }

    try {
      setState(() {
        _favorites[filmId] = !(_favorites[filmId] ?? false);
      });

      bool success;
      if (_favorites[filmId]!) {
        success = await ApiService.addToFavorite(filmId);
      } else {
        success = await ApiService.removeFromFavorite(filmId);
      }

      if (!success && mounted) {
        setState(() {
          _favorites[filmId] = !(_favorites[filmId] ?? false);
        });
        _showErrorDialog(
          _favorites[filmId]!
              ? "Sevimliga qo'shishda xato"
              : "Sevimlidan o'chirishda xato",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _favorites[filmId] = !(_favorites[filmId] ?? false);
        });
        _showErrorDialog("Xato: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnimatingFavorites[filmId] = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 4,
        title: const Text(
          'Katalog',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          FocusScope(
            child: Builder(
              builder:
                  (context) => IconButton(
                    icon: const Icon(
                      Icons.search,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: _toggleSearch,
                    tooltip: 'Qidiruv',
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
      body: SafeArea(
        child:
            _isInitialLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 6,
                  ),
                )
                : _categories.isEmpty
                ? const Center(
                  child: Text(
                    "Kategoriyalar mavjud emas",
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
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildCategoryButton(
                                text: "Barchasi",
                                isSelected: _tabController.index == 0,
                                onTap: () {
                                  _tabController.animateTo(0);
                                  setState(() {});
                                },
                              ),
                              ..._categories.asMap().entries.map(
                                (entry) => _buildCategoryButton(
                                  text:
                                      entry.value['name_uz']?.length <= 20
                                          ? entry.value['name_uz']
                                          : '${entry.value['name_uz']?.substring(0, 17)}...',
                                  isSelected:
                                      _tabController.index == entry.key + 1,
                                  onTap: () {
                                    _tabController.animateTo(entry.key + 1);
                                    setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: TabBarView(
                            controller: _tabController,
                            children: List.generate(_categories.length + 1, (
                              index,
                            ) {
                              final categoryId =
                                  index == 0
                                      ? ''
                                      : _categories[index - 1]['id'].toString();
                              final films = _filmsByCategory[categoryId] ?? [];
                              return films.isEmpty &&
                                      !_isLoadingByCategory[categoryId]!
                                  ? const Center(
                                    child: Text(
                                      "Filmlar mavjud emas",
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                  : CustomScrollView(
                                    controller: _scrollControllers[categoryId],
                                    slivers: [
                                      SliverPadding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        sliver: SliverGrid(
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 16,
                                                childAspectRatio: 0.65,
                                              ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) => FilmCard(
                                              film: films[index],
                                              isFavorite:
                                                  _favorites[films[index]['id']] ??
                                                  false,
                                              isAnimatingFavorite:
                                                  _isAnimatingFavorites[films[index]['id']] ??
                                                  false,
                                              favoriteScale:
                                                  _favoriteScales[films[index]['id']] ??
                                                  1.0,
                                              onToggleFavorite:
                                                  () => _toggleFavorite(
                                                    films[index]['id'],
                                                  ),
                                            ),
                                            childCount: films.length,
                                          ),
                                        ),
                                      ),
                                      if (_isLoadingByCategory[categoryId]! &&
                                          films.isNotEmpty)
                                        const SliverToBoxAdapter(
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 6,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                            }),
                          ),
                        ),
                      ],
                    ),
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

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollControllers.forEach((_, controller) => controller.dispose());
    _searchController.dispose();
    _tabController.dispose();
    _filmsByCategory.clear();
    _categories.clear();
    _favorites.clear();
    _isAnimatingFavorites.clear();
    _favoriteScales.clear();
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
  final bool isFavorite;
  final bool isAnimatingFavorite;
  final double favoriteScale;
  final VoidCallback onToggleFavorite;

  const FilmCard({
    super.key,
    required this.film,
    required this.isFavorite,
    required this.isAnimatingFavorite,
    required this.favoriteScale,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final files = film['files'] ?? [];
    final imageUrl =
        files.isNotEmpty
            ? (files[0]['thumbnails']?['small']?['src'] ??
                'https://placehold.co/320x180')
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
                    child: Stack(
                      children: [
                        Column(
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
                                  fadeInDuration: const Duration(
                                    milliseconds: 300,
                                  ),
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
                        Positioned(
                          top: 8,
                          right: 8,
                          child: FocusScope(
                            child: Builder(
                              builder:
                                  (context) => GestureDetector(
                                    onTap: onToggleFavorite,
                                    child: AnimatedScale(
                                      scale: favoriteScale,
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.8),
                                          border:
                                              FocusScope.of(context).hasFocus
                                                  ? Border.all(
                                                    color: Colors.yellow,
                                                    width: 2,
                                                  )
                                                  : null,
                                        ),
                                        child: Icon(
                                          isFavorite
                                              ? IconlyBold.heart
                                              : IconlyLight.heart,
                                          color:
                                              isFavorite
                                                  ? Colors.redAccent
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
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
