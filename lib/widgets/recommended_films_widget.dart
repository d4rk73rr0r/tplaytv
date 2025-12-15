import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';

final customCacheManager = CacheManager(
  Config(
    'recommendedFilmsCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class RecommendedFilmsWidget extends StatelessWidget {
  final List<dynamic> films;
  final bool isLoading;
  final String? error;
  final Function(dynamic) onTap;
  final VoidCallback onMoreTap;
  final bool isSelected;
  final int selectedIndex;

  const RecommendedFilmsWidget({
    super.key,
    required this.films,
    required this.isLoading,
    this.error,
    required this.onTap,
    required this.onMoreTap,
    required bool isDark,
    this.isSelected = false,
    this.selectedIndex = 0,
  });

  void _showErrorDialog(BuildContext context, String message) {
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
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 16.0;
    const itemWidth = 180.0; // TV uchun qattiq kenglik
    const itemHeight = 250.0; // TV uchun qattiq balandlik
    const sectionHeight = itemHeight + 60; // Matnlar va bo'shliqlar uchun

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Sizga tavsiya qilamiz",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              FocusScope(
                child: Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: onMoreTap,
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
          const SizedBox(height: 12),
          SizedBox(
            height: sectionHeight,
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 6,
                      ),
                    )
                    : error != null
                    ? Center(
                      child: Builder(
                        builder:
                            (context) => TextButton(
                              onPressed:
                                  () => _showErrorDialog(context, error!),
                              child: const Text(
                                "Xato yuz berdi. Ko‘proq ma'lumot",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      ),
                    )
                    : films.isEmpty
                    ? const Center(
                      child: Text(
                        "Tavsiya etilgan filmlar topilmadi",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    )
                    : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      cacheExtent: 500,
                      itemCount: films.length,
                      itemExtent: itemWidth + itemMargin,
                      itemBuilder: (context, index) {
                        final film = films[index];
                        final itemSelected = isSelected && selectedIndex == index;
                        final files = film['files'] as List<dynamic>? ?? [];
                        final imageUrl =
                            files.isNotEmpty
                                ? (files[0]['thumbnails'] != null &&
                                        files[0]['thumbnails']['small'] !=
                                            null &&
                                        files[0]['thumbnails']['small']['src'] !=
                                            null
                                    ? files[0]['thumbnails']['small']['src']
                                    : files[0]['link'] ??
                                        'https://placehold.co/320x180')
                                : 'https://placehold.co/320x180';

                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () => onTap(film),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform:
                                  itemSelected
                                      ? (Matrix4.identity()..scale(1.1))
                                      : Matrix4.identity(),
                              margin: const EdgeInsets.only(right: 16),
                              width: itemWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    itemSelected
                                        ? Border.all(
                                          color: Colors.yellow,
                                          width: 3,
                                        )
                                        : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                  if (itemSelected)
                                    BoxShadow(
                                      color: Colors.yellow.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                    ),
                                ],
                              ),
                              child: Material(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => onTap(film),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                cacheManager:
                                                    customCacheManager,
                                                fit: BoxFit.cover,
                                                width: itemWidth,
                                                height: itemHeight,
                                                maxHeightDiskCache: 400,
                                                fadeInDuration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                placeholder:
                                                    (context, url) => Container(
                                                      width: itemWidth,
                                                      height: itemHeight,
                                                      color: Colors.black
                                                          .withOpacity(0.8),
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Container(
                                                      width: itemWidth,
                                                      height: itemHeight,
                                                      color: Colors.black
                                                          .withOpacity(0.8),
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
                                            const SizedBox(height: 8),
                                            Text(
                                              film['name_uz'] ?? 'Noma’lum',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${film['year']?.toString() ?? ''} · ${film['genres']?.isNotEmpty ?? false ? film['genres'][0]['name_uz'] ?? '' : ''}",
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white70,
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
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
