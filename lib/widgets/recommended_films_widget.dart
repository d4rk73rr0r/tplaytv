import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tplaytv/screens/index_screen.dart';

final customCacheManager = CacheManager(
  Config(
    'recommendedFilmsCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class RecommendedFilmsWidget extends StatefulWidget {
  final List<dynamic> films;
  final bool isLoading;
  final String? error;
  final Function(dynamic) onTap;
  final VoidCallback onMoreTap;
  final bool isSelected;
  final int selectedIndex;
  final ScrollController? scrollController;

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
    this.scrollController,
  });

  @override
  State<RecommendedFilmsWidget> createState() => _RecommendedFilmsWidgetState();
}

class _RecommendedFilmsWidgetState extends State<RecommendedFilmsWidget> {
  int _previousSelectedIndex = -1;
  
  // Design constants to match Categories section
  static const double visibleCardsCount = 5.5;
  static const double horizontalPadding = 24.0 * 2;
  static const double itemMargin = 8.0;

  @override
  void didUpdateWidget(RecommendedFilmsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger scroll when selection changes
    if (widget.isSelected &&
        widget.selectedIndex != _previousSelectedIndex &&
        widget.scrollController != null &&
        widget.scrollController!.hasClients) {
      _previousSelectedIndex = widget.selectedIndex;

      // Schedule scroll after frame to ensure proper positioning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  // Calculate item width based on screen size
  double _calculateItemWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (screenWidth - horizontalPadding - itemMargin * visibleCardsCount) / visibleCardsCount;
  }

  // Scroll the selected item into view
  void _scrollToSelectedItem() {
    if (widget.scrollController == null || !widget.scrollController!.hasClients) return;

    final itemWidth = _calculateItemWidth(context);
    final itemExtent = itemWidth + itemMargin;

    final viewportWidth = widget.scrollController!.position.viewportDimension;

    // Calculate target offset to center the selected item
    final targetOffset =
        (widget.selectedIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController!.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    widget.scrollController!.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

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
    // Calculate dimensions dynamically to match Categories section
    final itemWidth = _calculateItemWidth(context);
    final itemHeight = itemWidth * 1.5; // 2:3 aspect ratio to match Categories
    final sectionHeight = itemHeight + 100; // Height for image + text

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sizga tavsiya qilamiz",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: sectionHeight,
            child:
                widget.isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                    : widget.error != null
                    ? Center(
                      child: Builder(
                        builder:
                            (context) => TextButton(
                              onPressed:
                                  () => _showErrorDialog(context, widget.error!),
                              child: const Text(
                                "Xato yuz berdi. Ko'proq ma'lumot",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      ),
                    )
                    : widget.films.isEmpty
                    ? const Center(
                      child: Text(
                        "Tavsiya etilgan filmlar topilmadi",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(left: 8, right: 24),
                      controller: widget.scrollController,
                      scrollDirection: Axis.horizontal,
                      cacheExtent: 500,
                      itemCount:
                          widget.films.length +
                          (widget.films.isNotEmpty ? 1 : 0), // All films + View All
                      itemExtent: itemWidth + itemMargin,
                      itemBuilder: (context, index) {
                        // If this is the last position, show View All card
                        if (index == widget.films.length) {
                          final itemSelected =
                              widget.isSelected && widget.selectedIndex == index;
                          return ViewAllCard(
                            width: itemWidth,
                            height: itemHeight,
                            isSelected: itemSelected,
                            onTap: widget.onMoreTap,
                          );
                        }
                        final film = widget.films[index];
                        final itemSelected =
                            widget.isSelected && widget.selectedIndex == index;
                        return RecommendedFilmItem(
                          film: film,
                          itemWidth: itemWidth,
                          itemHeight: itemHeight,
                          isSelected: itemSelected,
                          onTap: () => widget.onTap(film),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// RecommendedFilmItem - matches FilmItem design from Categories section
class RecommendedFilmItem extends StatelessWidget {
  final dynamic film;
  final double itemWidth;
  final double itemHeight;
  final bool isSelected;
  final VoidCallback onTap;

  const RecommendedFilmItem({
    super.key,
    required this.film,
    required this.itemWidth,
    required this.itemHeight,
    this.isSelected = false,
    required this.onTap,
  });

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
    final title = film['name_uz'] ?? "Noma'lum";
    final year = film['year']?.toString() ?? '';
    final genres = film['genres'] ?? [];
    final genreName = genres.isNotEmpty ? genres[0]['name_uz'] ?? '' : '';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image card with border and animations
            SizedBox(
              width: itemWidth,
              height: itemHeight + 16, // Extra space for border
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform:
                        Matrix4.identity()..scale(isSelected ? 1.05 : 1.0),
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
                          isSelected
                              ? Border.all(
                                color: const Color.fromARGB(255, 255, 59, 108),
                                width: 2,
                              )
                              : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: itemWidth,
                            height: itemHeight,
                            fit: BoxFit.cover,
                            cacheManager: customCacheManager,
                            maxHeightDiskCache: 400,
                            fadeInDuration: const Duration(milliseconds: 300),
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
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
                ],
              ),
            ),

            // Text labels - remain static outside the animated container
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
                "$year · $genreName",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
