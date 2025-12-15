import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/screens/index_screen.dart';

final customCacheManager = CacheManager(
  Config(
    'genreFilmsCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class GenreCard extends StatelessWidget {
  final Map<String, dynamic> genre;
  final VoidCallback onTap;

  const GenreCard({super.key, required this.genre, required this.onTap});

  void _showErrorDialog(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
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
                        onPressed: () {
                          Navigator.pop(context);
                          onRetry?.call();
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
                          "OK",
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                ),
              ),
              if (onRetry != null)
                FocusScope(
                  child: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onRetry();
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

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        genre['photo'] != null
            ? (genre['photo']['thumbnails'] != null &&
                    genre['photo']['thumbnails']['small'] != null &&
                    genre['photo']['thumbnails']['small']['src'] != null
                ? genre['photo']['thumbnails']['small']['src']
                : genre['photo']['link'] ?? 'https://placehold.co/360x250')
            : 'https://placehold.co/360x250';
    final name = genre['name_uz'] ?? 'No Name';

    return FocusScope(
      child: Builder(
        builder:
            (context) => GestureDetector(
              onTap: () async {
                final connectivityResult =
                    await Connectivity().checkConnectivity();
                if (connectivityResult == ConnectivityResult.none) {
                  _showErrorDialog(
                    context,
                    "Internet aloqasi yo‘q",
                    onRetry: () async {
                      if (await Connectivity().checkConnectivity() !=
                          ConnectivityResult.none) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => IndexScreen()),
                        );
                      } else {
                        _showErrorDialog(
                          context,
                          "Internet aloqasi hali ham yo‘q",
                        );
                      }
                    },
                  );
                } else {
                  onTap();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform:
                    FocusScope.of(context).hasFocus
                        ? (Matrix4.identity()..scale(1.1))
                        : Matrix4.identity(),
                width: 360,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border:
                      FocusScope.of(context).hasFocus
                          ? Border.all(color: Colors.yellow, width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
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
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final connectivityResult =
                          await Connectivity().checkConnectivity();
                      if (connectivityResult == ConnectivityResult.none) {
                        _showErrorDialog(
                          context,
                          "Internet aloqasi yo‘q",
                          onRetry: () async {
                            if (await Connectivity().checkConnectivity() !=
                                ConnectivityResult.none) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IndexScreen(),
                                ),
                              );
                            } else {
                              _showErrorDialog(
                                context,
                                "Internet aloqasi hali ham yo‘q",
                              );
                            }
                          },
                        );
                      } else {
                        onTap();
                      }
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheManager: customCacheManager,
                            fit: BoxFit.cover,
                            width: 360,
                            height: 250,
                            maxHeightDiskCache: 400,
                            fadeInDuration: const Duration(milliseconds: 300),
                            placeholder:
                                (context, url) => Container(
                                  width: 360,
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
                                  width: 360,
                                  height: 250,
                                  color: Colors.black.withOpacity(0.8),
                                  child: const Center(
                                    child: Text(
                                      "Rasmni yuklashda xato",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Container(
                          width: 360,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 50,
                          left: 24,
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
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
