import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:tplaytv/utils/navigation.dart';

final customCacheManager = CacheManager(
  Config(
    'favoritesCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _favorites = [];
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
    _fetchFavorites();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _fetchFavorites({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset) || !mounted) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
        _favorites.clear();
      }
    });

    try {
      final results = await ApiService.getFavorites(page: _page);
      if (mounted) {
        setState(() {
          final existingIds = _favorites.map((film) => film['id']).toSet();
          final newFavorites =
              results
                  .where((film) => !existingIds.contains(film['id']))
                  .toList();

          if (newFavorites.isNotEmpty) {
            _favorites.addAll(newFavorites);
            _page++;
            _precacheImages(newFavorites);
          } else if (_page > 1) {
            _hasMore = false;
          }
          _isLoading = false;
          if (_favorites.isEmpty) {
            _error = "Hozircha sevimli kontentlar yo'q";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Ma'lumotlarni yuklashda xatolik: $e";
        });
      }
    }
  }

  void _precacheImages(List<dynamic> films) {
    Future.microtask(() {
      for (var film in films) {
        final coverUrl =
            (film['files'] != null &&
                    film['files'].isNotEmpty &&
                    film['files'][0]['linkAbsolute'] != null)
                ? film['files'][0]['linkAbsolute']
                : 'https://placehold.co/150x150';
        precacheImage(
          CachedNetworkImageProvider(
            coverUrl,
            cacheManager: customCacheManager,
          ),
          context,
          onError: (_, __) {},
        );
      }
    });
  }

  void _onScroll() {
    if (_hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _fetchFavorites();
    }
  }

  void _toggleEditMode() {
    if (mounted) {
      setState(() => _isEditing = !_isEditing);
    }
  }

  Future<void> _removeFavorite(int filmId) async {
    final success = await ApiService.removeFromFavorite(filmId);
    if (success && mounted) {
      setState(() {
        _favorites.removeWhere((film) => film['id'] == filmId);
        if (_favorites.isEmpty) {
          _error = "Hozircha sevimli kontentlar yo'q";
        }
      });
    } else if (mounted) {
      _showErrorDialog("Kontentni o'chirishda xatolik");
    }
  }

  Future<void> _clearAllFavorites() async {
    final success = await ApiService.clearAllFavorites();
    if (success && mounted) {
      setState(() {
        _favorites.clear();
        _error = "Hozircha sevimli kontentlar yo'q";
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
                "Hammasini o'chirish",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              content: const Text(
                "Barcha sevimli kontentlarni o'chirmoqchimisiz?",
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
                            _clearAllFavorites();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor:
                                FocusScope.of(context).hasFocus
                                    ? Colors.red[700]
                                    : Colors.red,
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
          'Sevimlilar',
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
                    IconlyLight.arrowLeft,
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
      body: ContentWidget(
        favorites: _favorites,
        isLoading: _isLoading,
        error: _error,
        isEditing: _isEditing,
        hasMore: _hasMore,
        scrollController: _scrollController,
        onToggleEditMode: _toggleEditMode,
        onShowClearAllDialog: _showClearAllDialog,
        onRemoveFavorite: _removeFavorite,
        animationController: _animationController,
        scaleAnimation: _scaleAnimation,
      ),
    );
  }
}

class ContentWidget extends StatelessWidget {
  final List<dynamic> favorites;
  final bool isLoading;
  final String? error;
  final bool isEditing;
  final bool hasMore;
  final ScrollController scrollController;
  final VoidCallback onToggleEditMode;
  final VoidCallback onShowClearAllDialog;
  final ValueChanged<int> onRemoveFavorite;
  final AnimationController animationController;
  final Animation<double> scaleAnimation;

  const ContentWidget({
    super.key,
    required this.favorites,
    required this.isLoading,
    required this.error,
    required this.isEditing,
    required this.hasMore,
    required this.scrollController,
    required this.onToggleEditMode,
    required this.onShowClearAllDialog,
    required this.onRemoveFavorite,
    required this.animationController,
    required this.scaleAnimation,
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
    if (isLoading && favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6),
      );
    }

    if (favorites.isEmpty) {
      return Center(
        child: TextButton(
          onPressed:
              () => _showErrorDialog(
                context,
                error ?? "Hozircha sevimli kontentlar yo'q",
              ),
          child: const Text(
            "Hozircha sevimli kontentlar yo'q. Ko‘proq ma'lumot",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
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
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => FavoriteCard(
                film: favorites[index],
                isEditing: isEditing,
                onRemove: () => onRemoveFavorite(favorites[index]['id']),
              ),
              childCount: favorites.length,
            ),
          ),
        ),
        if (isLoading && favorites.isNotEmpty)
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
        if (!hasMore && favorites.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
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
                    "Barcha sevimli kontentlar yuklandi",
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

class PinnedButtonsHeader extends SliverPersistentHeaderDelegate {
  final bool isEditing;
  final VoidCallback onToggleEditMode;
  final VoidCallback onShowClearAllDialog;
  final AnimationController animationController;
  final Animation<double> scaleAnimation;

  PinnedButtonsHeader({
    required this.isEditing,
    required this.onToggleEditMode,
    required this.onShowClearAllDialog,
    required this.animationController,
    required this.scaleAnimation,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isEditing) ...[
            FocusScope(
              child: Builder(
                builder:
                    (context) => GestureDetector(
                      onTap: () {
                        onShowClearAllDialog();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform:
                            FocusScope.of(context).hasFocus
                                ? (Matrix4.identity()..scale(1.1))
                                : Matrix4.identity(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconlyLight.delete,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Barchasini o'chirish",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 16),
            FocusScope(
              child: Builder(
                builder:
                    (context) => GestureDetector(
                      onTap: onToggleEditMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform:
                            FocusScope.of(context).hasFocus
                                ? (Matrix4.identity()..scale(1.1))
                                : Matrix4.identity(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(12),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconlyLight.edit,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "O'chirish",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ] else ...[
            FocusScope(
              child: Builder(
                builder:
                    (context) => GestureDetector(
                      onTap: onToggleEditMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform:
                            FocusScope.of(context).hasFocus
                                ? (Matrix4.identity()..scale(1.1))
                                : Matrix4.identity(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[700],
                          borderRadius: BorderRadius.circular(12),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              IconlyLight.closeSquare,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Bekor qilish",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64.0;

  @override
  double get minExtent => 64.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class FavoriteCard extends StatefulWidget {
  final dynamic film;
  final bool isEditing;
  final VoidCallback onRemove;

  const FavoriteCard({
    super.key,
    required this.film,
    required this.isEditing,
    required this.onRemove,
  });

  @override
  _FavoriteCardState createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<FavoriteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGenresText(List<dynamic> genres) {
    if (genres.isEmpty) return 'Noma\'lum';
    return genres.map((genre) => genre['name_uz'] ?? 'Noma\'lum').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        (widget.film['files'] != null &&
                widget.film['files'].isNotEmpty &&
                widget.film['files'][0]['linkAbsolute'] != null)
            ? widget.film['files'][0]['linkAbsolute']
            : 'https://placehold.co/150x150';

    return FocusScope(
      child: Builder(
        builder:
            (context) => GestureDetector(
              onTap: () {
                if (!widget.isEditing) {
                  Navigator.push(
                    context,
                    createSlideRoute(FilmScreen(filmId: widget.film['id'])),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform:
                    FocusScope.of(context).hasFocus
                        ? (Matrix4.identity()..scale(1.1))
                        : Matrix4.identity(),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (!widget.isEditing) {
                        Navigator.push(
                          context,
                          createSlideRoute(
                            FilmScreen(filmId: widget.film['id']),
                          ),
                        );
                      }
                    },
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
                                  imageUrl: coverUrl,
                                  cacheManager: customCacheManager,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  maxWidthDiskCache: 150,
                                  maxHeightDiskCache: 250,
                                  fadeInDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  placeholder:
                                      (context, url) => Container(
                                        color: Colors.black.withOpacity(0.8),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 6,
                                          ),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        color: Colors.black.withOpacity(0.8),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white70,
                                          size: 48,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.film['name_uz'] ?? 'Noma\'lum',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Yil: ${widget.film['year'] ?? 'Noma\'lum'}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    'Janr: ${_getGenresText(widget.film['genres'] ?? [])}',
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
                        if (widget.isEditing)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: FocusScope(
                              child: Builder(
                                builder:
                                    (context) => GestureDetector(
                                      onTap: widget.onRemove,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border:
                                              FocusScope.of(context).hasFocus
                                                  ? Border.all(
                                                    color: Colors.yellow,
                                                    width: 2,
                                                  )
                                                  : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          IconlyLight.delete,
                                          color: Colors.white,
                                          size: 32,
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

class ClearAllDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const ClearAllDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Hammasini o'chirish",
        style: TextStyle(fontSize: 24, color: Colors.white),
      ),
      content: const Text(
        "Barcha sevimli kontentlarni o'chirmoqchimisiz?",
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
                    onConfirm();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor:
                        FocusScope.of(context).hasFocus
                            ? Colors.red[700]
                            : Colors.red,
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
    );
  }
}
