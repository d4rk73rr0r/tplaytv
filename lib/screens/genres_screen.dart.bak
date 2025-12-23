import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/genres_films_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'genresCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class GenresScreen extends StatefulWidget {
  const GenresScreen({super.key});

  @override
  State<GenresScreen> createState() => _GenresScreenState();
}

class _GenresScreenState extends State<GenresScreen> {
  List<dynamic> genres = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchGenres();
  }

  Future<void> _fetchGenres() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getGenresPreview();
      if (mounted) {
        setState(() {
          genres = response;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Janrlar yuklashda xatolik: $e";
          _showErrorDialog(errorMessage!);
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
                            _fetchGenres();
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
          'Janrlar',
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
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 6,
                ),
              )
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage!,
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FocusScope(
                      child: Builder(
                        builder:
                            (context) => ElevatedButton(
                              onPressed: _fetchGenres,
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
              : genres.isEmpty
              ? const Center(
                child: Text(
                  "Janrlar topilmadi",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
              )
              : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                cacheExtent: 500,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => GenreCard(genre: genres[index]),
                        childCount: genres.length,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  @override
  void dispose() {
    genres.clear();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }
}

class GenreCard extends StatelessWidget {
  final dynamic genre;

  const GenreCard({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        genre['photo']?['thumbnails']?['small']?['src'] ??
        genre['photo']?['link'] ??
        'https://placehold.co/600x300';
    final name = genre['name_uz'] ?? 'Noma’lum';

    return FocusScope(
      child: Builder(
        builder:
            (context) => GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    createSlideRoute(GenresFilmsScreen(genre: genre)),
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                            createSlideRoute(GenresFilmsScreen(genre: genre)),
                          ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              cacheManager: customCacheManager,
                              width: double.infinity,
                              height: 250,
                              fit: BoxFit.cover,
                              maxWidthDiskCache: 600,
                              maxHeightDiskCache: 400,
                              fadeInDuration: const Duration(milliseconds: 300),
                              placeholder:
                                  (context, url) => Container(
                                    width: double.infinity,
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
                                    width: double.infinity,
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
                            Container(
                              width: double.infinity,
                              height: 250,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 24,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
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
            ),
      ),
    );
  }
}
