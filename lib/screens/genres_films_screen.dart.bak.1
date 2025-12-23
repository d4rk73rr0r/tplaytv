import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'genresFilmsCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class GenresFilmsScreen extends StatefulWidget {
  final Map<String, dynamic> genre;

  const GenresFilmsScreen({super.key, required this.genre});

  @override
  State<GenresFilmsScreen> createState() => _GenresFilmsScreenState();
}

class _GenresFilmsScreenState extends State<GenresFilmsScreen> {
  List<dynamic> films = [];
  int currentPage = 1;
  final int perPage = 20;
  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchFilms();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoading &&
        hasMore) {
      _fetchFilms();
    }
  }

  Future<void> _fetchFilms({bool isRefresh = false}) async {
    if (isLoading || !mounted) return;

    setState(() {
      isLoading = true;
      if (isRefresh) {
        currentPage = 1;
        hasMore = true;
        films.clear();
        errorMessage = null;
      }
    });

    try {
      final genreId = widget.genre['id'];
      final response = await ApiService.getFilmsByGenre(
        genreId: genreId,
        page: currentPage,
        perPage: perPage,
      );

      final newFilms = (response['data'] as List<dynamic>?) ?? [];
      final meta = response['_meta'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          films.addAll(newFilms);
          isLoading = false;

          if (meta != null &&
              meta['currentPage'] is int &&
              meta['pageCount'] is int &&
              meta['currentPage'] < meta['pageCount']) {
            hasMore = true;
            currentPage++;
          } else {
            hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Kontent yuklashda xatolik: $e";
          _showErrorDialog(errorMessage!);
        });
      }
    }
  }

  Future<void> _onRefresh() async {
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
                            _fetchFilms(isRefresh: true);
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
    final genreName = widget.genre['name_uz'] ?? 'Janr';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 4,
        title: Text(
          genreName,
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              errorMessage != null
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
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
                                  onPressed: () => _fetchFilms(isRefresh: true),
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
                  )
                  : films.isEmpty && !isLoading
                  ? const Center(
                    child: Text(
                      "Kontent topilmadi",
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  )
                  : CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 500,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 12),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.65,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => FilmCard(film: films[index]),
                            childCount: films.length,
                          ),
                        ),
                      ),
                      if (isLoading)
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
                      if (!hasMore && films.isNotEmpty)
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
