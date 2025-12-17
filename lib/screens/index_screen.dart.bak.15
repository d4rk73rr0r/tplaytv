import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tplaytv/screens/latestviewed_screen.dart';
import 'package:tplaytv/screens/recommended_films_screen.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/screens/film_screen.dart';
import 'package:tplaytv/widgets/recommended_films_widget.dart';
import 'package:tplaytv/screens/genres_screen.dart';
import 'package:tplaytv/screens/genres_films_screen.dart';
import 'package:tplaytv/screens/categories_screen.dart';
import 'package:tplaytv/utils/navigation.dart';

// Kesh sozlamalari
final customCacheManager = CacheManager(
  Config(
    'indexScreenCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 50,
  ),
);

// Holatni boshqarish uchun Provider
class IndexScreenProvider with ChangeNotifier {
  List<dynamic> _banners = [];
  List<dynamic> _latestViewed = [];
  List<dynamic> _recommendedFilms = [];
  List<dynamic> _genresPreview = [];
  List<dynamic> _categories = [];
  Map<int, List<dynamic>> _categoryFilms = {};
  bool _isLoadingBanners = true;
  bool _isLoadingLatestViewed = true;
  bool _isLoadingRecommended = true;
  bool _isLoadingGenres = true;
  bool _isLoadingCategories = true;
  Map<int, bool> _isLoadingCategoryFilms = {};
  String? _globalError;
  int? _globalErrorStatusCode;
  String? _genresError;

  List<dynamic> get banners => _banners;
  List<dynamic> get latestViewed => _latestViewed;
  List<dynamic> get recommendedFilms => _recommendedFilms;
  List<dynamic> get genresPreview => _genresPreview;
  List<dynamic> get categories => _categories;
  Map<int, List<dynamic>> get categoryFilms => _categoryFilms;
  bool get isLoadingBanners => _isLoadingBanners;
  bool get isLoadingLatestViewed => _isLoadingLatestViewed;
  bool get isLoadingRecommended => _isLoadingRecommended;
  bool get isLoadingGenres => _isLoadingGenres;
  bool get isLoadingCategories => _isLoadingCategories;
  Map<int, bool> get isLoadingCategoryFilms => _isLoadingCategoryFilms;
  String? get globalError => _globalError;
  int? get globalErrorStatusCode => _globalErrorStatusCode;
  String? get genresError => _genresError;

  void updateBanners(List<dynamic> data) {
    _banners = data;
    _isLoadingBanners = false;
    notifyListeners();
  }

  void updateLatestViewed(List<dynamic> data) {
    _latestViewed = data;
    _isLoadingLatestViewed = false;
    notifyListeners();
  }

  void updateRecommendedFilms(List<dynamic> data) {
    _recommendedFilms = data;
    _isLoadingRecommended = false;
    notifyListeners();
  }

  void updateGenresPreview(List<dynamic> data) {
    _genresPreview = data;
    _isLoadingGenres = false;
    _genresError = null;
    notifyListeners();
  }

  void updateCategories(List<dynamic> data) {
    _categories = data;
    _isLoadingCategories = false;
    for (var category in data) {
      _isLoadingCategoryFilms[category['id']] = true;
      _categoryFilms[category['id']] = [];
    }
    notifyListeners();
  }

  void updateCategoryFilms(int categoryId, List<dynamic> films) {
    _categoryFilms[categoryId] = films;
    _isLoadingCategoryFilms[categoryId] = false;
    notifyListeners();
  }

  void setLoadingBanners(bool value) {
    _isLoadingBanners = value;
    notifyListeners();
  }

  void setLoadingLatestViewed(bool value) {
    _isLoadingLatestViewed = value;
    notifyListeners();
  }

  void setLoadingRecommended(bool value) {
    _isLoadingRecommended = value;
    notifyListeners();
  }

  void setLoadingGenres(bool value) {
    _isLoadingGenres = value;
    notifyListeners();
  }

  void setLoadingCategories(bool value) {
    _isLoadingCategories = value;
    notifyListeners();
  }

  void setGlobalError(String error, int? statusCode) {
    _globalError = error;
    _globalErrorStatusCode = statusCode;
    _isLoadingBanners = false;
    _isLoadingLatestViewed = false;
    _isLoadingRecommended = false;
    _isLoadingGenres = false;
    _isLoadingCategories = false;
    _isLoadingCategoryFilms.clear();
    _banners = [];
    _latestViewed = [];
    _recommendedFilms = [];
    _genresPreview = [];
    _categories = [];
    _categoryFilms = {};
    notifyListeners();
  }

  void setGenresError(String error) {
    _genresError = error;
    _isLoadingGenres = false;
    notifyListeners();
  }

  void clearGlobalError() {
    _globalError = null;
    _globalErrorStatusCode = null;
    notifyListeners();
  }

  void reset() {
    _banners = [];
    _latestViewed = [];
    _recommendedFilms = [];
    _genresPreview = [];
    _categories = [];
    _categoryFilms = {};
    _isLoadingBanners = true;
    _isLoadingLatestViewed = true;
    _isLoadingRecommended = true;
    _isLoadingGenres = true;
    _isLoadingCategories = true;
    _isLoadingCategoryFilms = {};
    _globalError = null;
    _globalErrorStatusCode = null;
    _genresError = null;
    notifyListeners();
  }
}

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IndexScreenProvider(),
      child: const IndexScreenContent(),
    );
  }
}

class IndexScreenContent extends StatefulWidget {
  const IndexScreenContent({super.key});

  @override
  State<IndexScreenContent> createState() => _IndexScreenContentState();
}

class _IndexScreenContentState extends State<IndexScreenContent> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Focus nodes for TV remote control
  final FocusNode _contentFocusNode = FocusNode();
  int _selectedSectionIndex = 0;
  int _selectedItemIndex = 0;

  // Scroll controller for vertical scrolling
  late ScrollController _scrollController;

  // Horizontal scroll controllers for each section
  final Map<int, ScrollController> _horizontalScrollControllers = {};

  // Global keys for sections to enable scrolling
  final GlobalKey _bannerKey = GlobalKey();
  final GlobalKey _latestViewedKey = GlobalKey();
  final GlobalKey _recommendedKey = GlobalKey();
  final GlobalKey _genresKey = GlobalKey();
  // Dynamic keys for category sections
  final Map<int, GlobalKey> _categoryKeys = {};

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    // Request focus after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.every((result) => result == ConnectivityResult.none)) {
        final provider = Provider.of<IndexScreenProvider>(
          context,
          listen: false,
        );
        provider.setGlobalError('Tarmoq xatosi', null);
        _showErrorDialog(
          'Tarmoq aloqasi yo‘q. Iltimos, internet aloqasini tekshiring.',
        );
      } else {
        _fetchInitialData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    // Dispose horizontal scroll controllers
    for (final controller in _horizontalScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    provider.clearGlobalError();
    if (!(await _checkInternetConnection())) {
      provider.setGlobalError('Tarmoq xatosi', null);
      _showErrorDialog(
        'Tarmoq aloqasi yo‘q. Iltimos, internet aloqasini tekshiring.',
      );
      return;
    }

    try {
      await Future.wait([
        _fetchData(
          fetchFunction: ApiService.getBanners,
          onSuccess: (data) => provider.updateBanners(data),
          onError:
              (error, statusCode) => provider.setGlobalError(error, statusCode),
          errorMessage: 'Bannerlarni yuklashda xato',
        ),
        _fetchData(
          fetchFunction:
              () => ApiService.getLatestViewed(
                isAll: false,
                perPage: 10,
                fields:
                    'name_uz,name_ru,name_en,id,films.id,films.name_uz,films.name_ru,films.publish_time,films.type,films.paid,films.year,films.tags.id,films.tags.title_uz,films.tags.title_en,films.files.thumbnails',
              ),
          onSuccess: (response) {
            final films = response['data'] ?? [];
            provider.updateLatestViewed(films);
          },
          onError:
              (error, statusCode) => provider.setGlobalError(error, statusCode),
          errorMessage: 'So‘ngi ko‘rilganlarni yuklashda xato',
        ),
        _fetchData(
          fetchFunction: ApiService.getRecommendedFilms,
          onSuccess: (response) async {
            final films = response['data'] ?? [];
            final processedFilms = await _processFilms(films);
            provider.updateRecommendedFilms(processedFilms);
          },
          onError:
              (error, statusCode) => provider.setGlobalError(error, statusCode),
          errorMessage: 'Tavsiya etilganlarni yuklashda xato',
        ),
        _fetchData(
          fetchFunction: ApiService.getGenresPreview,
          onSuccess: (data) => provider.updateGenresPreview(data),
          onError: (error, statusCode) => provider.setGenresError(error),
          errorMessage: 'Janrlar yuklashda xatolik',
        ),
        _fetchCategories(),
      ]);
    } catch (e) {
      provider.setGlobalError('Umumiy xato: $e', null);
      _showErrorDialog('Ma\'lumotlarni yuklashda xato: $e');
    }
  }

  Future<void> _fetchData<T>({
    required Future<T> Function() fetchFunction,
    required Function(T) onSuccess,
    required Function(String, int?) onError,
    required String errorMessage,
  }) async {
    try {
      final data = await fetchFunction();
      if (data is Map<String, dynamic> && data['success'] == false) {
        final statusCode = data['statusCode'] as int?;
        final error = data['error']?.toString() ?? 'Noma’lum xato';
        onError(error, statusCode);
      } else {
        onSuccess(data);
      }
    } catch (e) {
      onError('$errorMessage: $e', null);
    }
  }

  Future<void> _fetchCategories() async {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    await _fetchData(
      fetchFunction: ApiService.getCategories,
      onSuccess: (response) async {
        final List categoryList = response['data'] ?? [];
        provider.updateCategories(categoryList);
        await Future.wait(
          categoryList.map(
            (category) => _fetchFilmsForCategory(category['id']),
          ),
        );
      },
      onError:
          (error, statusCode) => provider.setGlobalError(error, statusCode),
      errorMessage: 'Kategoriyalarni yuklashda xato',
    );
  }

  Future<void> _fetchFilmsForCategory(int categoryId) async {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    await _fetchData(
      fetchFunction:
          () => ApiService.getFilmsByCategory(
            categoryId: categoryId,
            page: 1,
            perPage: 10,
          ),
      onSuccess: (response) async {
        final films = response['data'] ?? [];
        final processedFilms = await _processFilms(films);
        provider.updateCategoryFilms(categoryId, processedFilms);
      },
      onError:
          (error, statusCode) => provider.setGlobalError(error, statusCode),
      errorMessage: 'Kategoriya filmlarini yuklashda xato',
    );
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );
      if (!isConnected) return false;

      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5), onTimeout: () => []);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Xato", style: TextStyle(fontSize: 22)),
              content: Text(message, style: const TextStyle(fontSize: 18)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK", style: TextStyle(fontSize: 18)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _onRetry();
                  },
                  child: const Text(
                    "Qayta urinish",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _onRetry() async {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    if (!(await _checkInternetConnection())) {
      _showErrorDialog(
        'Tarmoq aloqasi yo‘q. Iltimos, internet aloqasini tekshiring.',
      );
      return;
    }

    provider.reset();
    await _fetchInitialData();
  }

  Future<List<dynamic>> _processFilms(List<dynamic> newFilms) async {
    return newFilms.take(20).toList();
  }

  // Scroll to the selected section
  void _scrollToSelectedSection() {
    GlobalKey? key;
    int currentSection = 0;
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);

    if (provider.banners.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) key = _bannerKey;
      currentSection++;
    }

    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) key = _latestViewedKey;
      currentSection++;
    }

    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) key = _recommendedKey;
      currentSection++;
    }

    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) key = _genresKey;
      currentSection++;
    }

    // For category sections, check if we have a key for this specific category
    if (provider.categories.isNotEmpty &&
        _selectedSectionIndex >= currentSection &&
        _selectedSectionIndex < currentSection + provider.categories.length) {
      final categoryIndex = _selectedSectionIndex - currentSection;
      // Create key if it doesn't exist
      if (!_categoryKeys.containsKey(categoryIndex)) {
        _categoryKeys[categoryIndex] = GlobalKey();
      }
      key = _categoryKeys[categoryIndex];
    }

    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  // Scroll horizontally to the currently selected item
  // This method dynamically calculates item widths based on the section type
  // and ensures that the selected card is centered or fully brought into view
  void _scrollToCurrentItem() {
    final controller = _horizontalScrollControllers[_selectedSectionIndex];
    if (controller == null || !controller.hasClients) return;

    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    final double viewportWidth = controller.position.viewportDimension;

    // Calculate section-specific item width and margin
    final itemDimensions = _getItemDimensionsForSection(
      _selectedSectionIndex,
      provider,
      viewportWidth,
    );
    final double itemWidth = itemDimensions['width']!;
    final double itemMargin = itemDimensions['margin']!;

    // Total width occupied by each item (card + margin)
    final double itemExtent = itemWidth + itemMargin;

    // Calculate target scroll offset to center the selected item
    // We position the item so its center aligns with the viewport center
    final double targetOffset =
        (_selectedItemIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final double maxOffset = controller.position.maxScrollExtent;

    // Clamp the offset to valid scroll range
    final double clampedOffset = targetOffset.clamp(0.0, maxOffset);

    controller.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Calculate item width and margin for each section type
  // This ensures scroll behavior matches the actual card dimensions
  Map<String, double> _getItemDimensionsForSection(
    int sectionIndex,
    IndexScreenProvider provider,
    double viewportWidth,
  ) {
    int currentSection = 0;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Banner section - uses carousel, no scroll needed but included for consistency
    if (provider.banners.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return {'width': viewportWidth * 0.9, 'margin': 16.0};
      }
      currentSection++;
    }

    // Latest Viewed section - 16:9 aspect ratio cards
    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return {'width': 240.0, 'margin': 16.0};
      }
      currentSection++;
    }

    // Recommended Films section - uses RecommendedFilmsWidget
    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return {'width': 160.0, 'margin': 16.0};
      }
      currentSection++;
    }

    // Genres section - dynamically calculated based on screen size
    // Shows ~3 cards at a time for optimal viewing
    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == sectionIndex) {
        const horizontalPadding = 24.0 * 2; // left + right padding
        const itemMargin = 16.0;
        final availableWidth = screenWidth - horizontalPadding;
        final itemWidth = (availableWidth - itemMargin * 2) / 3;
        return {'width': itemWidth, 'margin': itemMargin};
      }
      currentSection++;
    }

    // Category sections - dynamically calculated
    // Shows ~5.5 cards at a time
    for (var category in provider.categories) {
      if (currentSection == sectionIndex) {
        const horizontalPadding = 24.0 * 2;
        const itemMargin = 8.0;
        final itemWidth =
            (screenWidth - horizontalPadding - itemMargin * 5.5) / 5.5;
        return {'width': itemWidth, 'margin': itemMargin};
      }
      currentSection++;
    }

    // Default fallback
    return {'width': 200.0, 'margin': 16.0};
  }

  // Get or create a scroll controller for a section
  ScrollController _getScrollControllerForSection(int sectionIndex) {
    if (!_horizontalScrollControllers.containsKey(sectionIndex)) {
      _horizontalScrollControllers[sectionIndex] = ScrollController();
    }
    return _horizontalScrollControllers[sectionIndex]!;
  }

  // TV Remote control key event handler
  KeyEventResult _handleContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final provider = Provider.of<IndexScreenProvider>(context, listen: false);

    // Count available sections
    int sectionCount = 0;
    if (provider.banners.isNotEmpty) sectionCount++;
    if (provider.latestViewed.isNotEmpty) sectionCount++;
    if (provider.recommendedFilms.isNotEmpty) sectionCount++;
    if (provider.genresPreview.isNotEmpty) sectionCount++;
    if (provider.categories.isNotEmpty)
      sectionCount += provider.categories.length;

    if (sectionCount == 0) return KeyEventResult.ignored;

    // Handle arrow down - move to next section
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_selectedSectionIndex < sectionCount - 1) {
          _selectedSectionIndex++;
          _selectedItemIndex = 0;
        }
      });
      _scrollToSelectedSection();
      return KeyEventResult.handled;
    }

    // Handle arrow up - move to previous section
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_selectedSectionIndex > 0) {
          _selectedSectionIndex--;
          _selectedItemIndex = 0;
        }
      });
      _scrollToSelectedSection();
      return KeyEventResult.handled;
    }

    // Handle arrow right - move to next item in section
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        // Get the current section's item count
        int maxItems = _getMaxItemsForSection(_selectedSectionIndex, provider);
        if (_selectedItemIndex < maxItems - 1) {
          _selectedItemIndex++;
        }
      });
      _scrollToCurrentItem();
      return KeyEventResult.handled;
    }

    // Handle arrow left - move to previous item in section or let parent handle
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedItemIndex > 0) {
        setState(() {
          _selectedItemIndex--;
        });
        _scrollToCurrentItem();
        return KeyEventResult.handled;
      } else {
        // At the first item - let parent handle to open sidebar menu
        return KeyEventResult.ignored;
      }
    }

    // Handle select/enter - activate selected item
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _activateSelectedItem(provider);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int _getMaxItemsForSection(int sectionIndex, IndexScreenProvider provider) {
    int currentSection = 0;

    // Banner section
    if (provider.banners.isNotEmpty) {
      if (currentSection == sectionIndex) return provider.banners.length;
      currentSection++;
    }

    // Latest viewed section - limit to 7 items (6 + View All)
    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.latestViewed.length > 6
            ? 7
            : provider.latestViewed.length;
      }
      currentSection++;
    }

    // Recommended section - limit to 7 items (6 + View All)
    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.recommendedFilms.length > 6
            ? 7
            : provider.recommendedFilms.length;
      }
      currentSection++;
    }

    // Genres section - show all genres + View All
    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.genresPreview.length + 1; // All genres + "View All"
      }
      currentSection++;
    }

    // Category sections - barcha filmlar + View All
    for (var category in provider.categories) {
      final categoryId = category['id'];
      final films = provider.categoryFilms[categoryId] ?? [];
      if (currentSection == sectionIndex) {
        if (films.isEmpty) return 1;
        return films.length + 1;
      }
      currentSection++;
    }

    return 1;
  }

  void _activateSelectedItem(IndexScreenProvider provider) {
    int currentSection = 0;

    // Banner section
    if (provider.banners.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        final banner = provider.banners[_selectedItemIndex];
        final film = banner['film'] as Map<String, dynamic>? ?? {};
        final filmId = film['id'] ?? 0;
        if (filmId != 0) {
          Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
        }
        return;
      }
      currentSection++;
    }

    // Latest viewed section
    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        // Check if View All card is selected
        if (provider.latestViewed.length > 6 && _selectedItemIndex == 6) {
          Navigator.push(context, createSlideRoute(const LatestViewedScreen()));
          return;
        }
        final item = provider.latestViewed[_selectedItemIndex];
        final film = item['film'] as Map<String, dynamic>? ?? {};
        final filmId = film['id'] ?? 0;
        if (filmId != 0) {
          Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
        }
        return;
      }
      currentSection++;
    }

    // Recommended section
    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        // Check if View All card is selected
        if (provider.recommendedFilms.length > 6 && _selectedItemIndex == 6) {
          Navigator.push(
            context,
            createSlideRoute(const RecommendedFilmsScreen()),
          );
          return;
        }
        final film = provider.recommendedFilms[_selectedItemIndex];
        final filmId = film['id'];
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
        return;
      }
      currentSection++;
    }

    // Genres section - O'ZGARTIRILGAN
    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        // View All kartasi oxirgi element ekanligini tekshirish
        if (_selectedItemIndex == provider.genresPreview.length) {
          // Bu View All kartasi
          Navigator.push(context, createSlideRoute(const GenresScreen()));
          return;
        }
        // Oddiy janr kartasi
        if (_selectedItemIndex < provider.genresPreview.length) {
          final genre = provider.genresPreview[_selectedItemIndex];
          Navigator.push(
            context,
            createSlideRoute(GenresFilmsScreen(genre: genre)),
          );
        }
        return;
      }
      currentSection++;
    }

    // Category sections
    for (var category in provider.categories) {
      final categoryId = category['id'];
      final films = provider.categoryFilms[categoryId] ?? [];
      if (currentSection == _selectedSectionIndex && films.isNotEmpty) {
        // Check if View All card is selected
        if (_selectedItemIndex == films.length) {
          Navigator.push(
            context,
            createSlideRoute(CategoriesScreen(initialCategory: category)),
          );
          return;
        }
        final film = films[_selectedItemIndex];
        final filmId = film['id'];
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
        return;
      }
      currentSection++;
    }
  }

  int _getRecommendedSectionIndex() {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    int index = 0;
    if (provider.banners.isNotEmpty) index++;
    if (provider.latestViewed.isNotEmpty) index++;
    return index;
  }

  int _getGenresSectionIndex() {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    int index = 0;
    if (provider.banners.isNotEmpty) index++;
    if (provider.latestViewed.isNotEmpty) index++;
    if (provider.recommendedFilms.isNotEmpty) index++;
    return index;
  }

  int _getCategoriesSectionIndex() {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    int index = 0;
    if (provider.banners.isNotEmpty) index++;
    if (provider.latestViewed.isNotEmpty) index++;
    if (provider.recommendedFilms.isNotEmpty) index++;
    if (provider.genresPreview.isNotEmpty) index++;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);

    if (provider.globalError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ErrorScreen(
            errorMessage: provider.globalError!,
            onRetry: _onRetry,
          ),
        ),
      );
    }

    if (provider.isLoadingBanners ||
        provider.isLoadingLatestViewed ||
        provider.isLoadingRecommended ||
        provider.isLoadingGenres ||
        provider.isLoadingCategories) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _contentFocusNode,
        onKeyEvent: _handleContentKeyEvent,
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                provider.banners.isNotEmpty
                    ? Container(
                      key: _bannerKey,
                      child: BannerCarousel(
                        isSelected: _selectedSectionIndex == 0,
                        selectedIndex: _selectedItemIndex,
                      ),
                    )
                    : const SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          'Bannerlar mavjud emas',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                if (provider.latestViewed.isNotEmpty)
                  Container(
                    key: _latestViewedKey,
                    child: LatestViewedSection(
                      isSelected:
                          _selectedSectionIndex ==
                          (provider.banners.isNotEmpty ? 1 : 0),
                      selectedIndex: _selectedItemIndex,
                      scrollController: _getScrollControllerForSection(
                        provider.banners.isNotEmpty ? 1 : 0,
                      ),
                    ),
                  ),
                Container(
                  key: _recommendedKey,
                  child: RecommendedFilmsSection(
                    isSelected:
                        _selectedSectionIndex == _getRecommendedSectionIndex(),
                    selectedIndex: _selectedItemIndex,
                    scrollController: _getScrollControllerForSection(
                      _getRecommendedSectionIndex(),
                    ),
                  ),
                ),
                Container(
                  key: _genresKey,
                  child: GenresSection(
                    onRetry: _onRetry,
                    isSelected:
                        _selectedSectionIndex == _getGenresSectionIndex(),
                    selectedIndex: _selectedItemIndex,
                    scrollController: _getScrollControllerForSection(
                      _getGenresSectionIndex(),
                    ),
                  ),
                ),
                CategoriesSection(
                  baseSectionIndex: _getCategoriesSectionIndex(),
                  selectedSectionIndex: _selectedSectionIndex,
                  selectedItemIndex: _selectedItemIndex,
                  categoryKeys: _categoryKeys,
                  getScrollController: _getScrollControllerForSection,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Error Screen
class ErrorScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(fontSize: 20, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FocusScope(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        FocusScope.of(context).hasFocus
                            ? Colors.blue[500]
                            : Colors.blue[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Qayta urinish',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// BannerCarousel
class BannerCarousel extends StatefulWidget {
  final bool isSelected;
  final int selectedIndex;

  const BannerCarousel({
    super.key,
    this.isSelected = false,
    this.selectedIndex = 0,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addListener(() {
      setState(() {});
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync carousel with remote control selection
    if (widget.isSelected && widget.selectedIndex != _currentIndex) {
      _carouselController.animateToPage(widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final banners = provider.banners;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          carouselController: _carouselController,
          options: CarouselOptions(
            height: 300.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 6),
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
                _animationController.reset();
                _animationController.forward();
              });
            },
          ),
          items:
              banners.asMap().entries.map((entry) {
                final index = entry.key;
                final banner = entry.value;
                final isSelected =
                    widget.isSelected && widget.selectedIndex == index;
                return Builder(
                  builder: (BuildContext context) {
                    return BannerItem(banner: banner, isSelected: isSelected);
                  },
                );
              }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                banners.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child:
                        _currentIndex == index
                            ? _buildAnimatedIndicator()
                            : Container(
                              width: 10.0,
                              height: 10.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.withOpacity(0.5),
                              ),
                            ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedIndicator() {
    return SizedBox(
      width: 20.0,
      height: 20.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: CircleProgressPainter(_animationController.value),
            child: const SizedBox(width: 20.0, height: 20.0),
          ),
          Container(
            width: 10.0,
            height: 10.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Aylana animatsiyasi uchun CustomPainter
class CircleProgressPainter extends CustomPainter {
  final double progress;

  CircleProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Banner Item
class BannerItem extends StatelessWidget {
  final dynamic banner;
  final bool isSelected;

  const BannerItem({super.key, required this.banner, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final film = banner['film'] as Map<String, dynamic>? ?? {};
    final files = banner['files'] as List<dynamic>? ?? [];
    final imageUrl =
        files.isNotEmpty
            ? files[0]['link'] ?? 'https://placehold.co/640x360'
            : 'https://placehold.co/640x360';
    final title = film['name_uz'] ?? banner['title'] ?? 'Noma’lum';
    final year = film['year']?.toString() ?? 'Noma’lum';
    final kinopoiskRating = film['kinopoisk_rating']?.toString() ?? 'N/A';
    final imdbRating = film['imdb_rating']?.toString() ?? 'N/A';
    final filmId = film['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform:
            isSelected ? Matrix4.identity().scaled(1.05) : Matrix4.identity(),
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // Increased border-radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
          border:
              isSelected ? Border.all(color: Colors.yellow, width: 3) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                cacheManager: customCacheManager,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget:
                    (context, url, error) => Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text(
                          'Rasmni yuklashda xato',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ),
                    ),
              ),
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.length > 20
                          ? '${title.substring(0, 20)}...'
                          : title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      year,
                      style: TextStyle(color: Colors.grey[300], fontSize: 16),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Kinopoisk: ',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          kinopoiskRating,
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'IMDb: ',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          imdbRating,
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Latest Viewed Section - Improved with scroll handling
class LatestViewedSection extends StatefulWidget {
  final bool isSelected;
  final int selectedIndex;
  final ScrollController scrollController;

  const LatestViewedSection({
    super.key,
    this.isSelected = false,
    this.selectedIndex = 0,
    required this.scrollController,
  });

  @override
  State<LatestViewedSection> createState() => _LatestViewedSectionState();
}

class _LatestViewedSectionState extends State<LatestViewedSection> {
  int _previousSelectedIndex = -1;

  @override
  void didUpdateWidget(LatestViewedSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger scroll when selection changes
    if (widget.isSelected &&
        widget.selectedIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedIndex;

      // Schedule scroll after frame to ensure proper positioning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  // Scroll the selected item into view
  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    const double itemExtent = 250.0; // itemWidth (240) + margin (10)
    const double itemWidth = 240.0;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    // Calculate target offset to center the selected item
    final targetOffset =
        (widget.selectedIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    widget.scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final latestViewed = provider.latestViewed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ko'rishni davom ettirish",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140, // Adjusted for 16:9 aspect ratio
            child: ListView.builder(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              itemCount:
                  latestViewed.length > 6
                      ? 7
                      : latestViewed.length, // Limit to 6 + 1 for View All
              itemExtent: 250, // 16:9 uchun kengroq (250 x 140 ≈ 16:9)
              cacheExtent: 500,
              itemBuilder: (context, index) {
                // If we have more than 6 items and this is the 7th position, show View All card
                if (latestViewed.length > 6 && index == 6) {
                  final itemSelected =
                      widget.isSelected && widget.selectedIndex == index;
                  return ViewAllCard(
                    width: 240,
                    height: 135, // 240 * 9/16 ≈ 135
                    isSelected: itemSelected,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideRoute(const LatestViewedScreen()),
                      );
                    },
                  );
                }
                final itemSelected =
                    widget.isSelected && widget.selectedIndex == index;
                return LatestViewedItem(
                  item: latestViewed[index],
                  isSelected: itemSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Latest Viewed Item
class LatestViewedItem extends StatelessWidget {
  final dynamic item;
  final bool isSelected;

  const LatestViewedItem({
    super.key,
    required this.item,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final film = item['film'] as Map<String, dynamic>? ?? {};
    final screenshots = item['screenshots'] as List<dynamic>? ?? [];
    final second = item['second'] as Map<String, dynamic>? ?? {};
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
                : file['link'] ?? 'https://placehold.co/400x225')
            : 'https://placehold.co/400x225';
    final filmId = film['id'] ?? 0;
    final viewedTime = second['time'] ?? 0;
    final playbackTime = film['playback_time'] ?? 1;
    final viewedMinutes = (viewedTime / 60).floor();
    final viewedSeconds = viewedTime % 60;
    final viewedTimeString =
        '${viewedMinutes.toString().padLeft(2, '0')}:${viewedSeconds.toString().padLeft(2, '0')}';
    final double progress = viewedTime / (playbackTime * 60);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform:
            isSelected ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        width: 240,
        height: 135,
        margin: const EdgeInsets.only(right: 16),
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
              isSelected ? Border.all(color: Colors.yellow, width: 3) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheManager: customCacheManager,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
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
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        viewedTimeString,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.yellow,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Container(color: Colors.white.withOpacity(0.1)),
            ],
          ),
        ),
      ),
    );
  }
}

// Recommended Films Section
class RecommendedFilmsSection extends StatelessWidget {
  final bool isSelected;
  final int selectedIndex;
  final ScrollController scrollController;

  const RecommendedFilmsSection({
    super.key,
    this.isSelected = false,
    this.selectedIndex = 0,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final films = provider.recommendedFilms;

    return RecommendedFilmsWidget(
      films: films,
      isLoading: provider.isLoadingRecommended,
      isSelected: isSelected,
      selectedIndex: selectedIndex,
      scrollController: scrollController,
      onTap: (film) {
        final filmId = film['id'];
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
      },
      onMoreTap: () {
        Navigator.push(
          context,
          createSlideRoute(const RecommendedFilmsScreen()),
        );
      },
      isDark: true,
    );
  }
}

// Genres Section - Improved version with better scroll handling
// This widget displays genre cards in a horizontal scrollable list
// and ensures proper navigation and scrolling for TV remote control
class GenresSection extends StatefulWidget {
  final VoidCallback onRetry;
  final bool isSelected;
  final int selectedIndex;
  final ScrollController scrollController;

  const GenresSection({
    super.key,
    required this.onRetry,
    this.isSelected = false,
    this.selectedIndex = 0,
    required this.scrollController,
  });

  @override
  State<GenresSection> createState() => _GenresSectionState();
}

class _GenresSectionState extends State<GenresSection> {
  int _previousSelectedIndex = -1;

  @override
  void didUpdateWidget(GenresSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger scroll when selection changes
    if (widget.isSelected &&
        widget.selectedIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedIndex;

      // Schedule scroll after frame to ensure proper positioning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  // Scroll the selected item into view
  // This method centers the selected card in the viewport
  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 16.0;
    final availableWidth = screenWidth - horizontalPadding;
    final itemWidth = (availableWidth - itemMargin * 2) / 3;
    final itemExtent = itemWidth + itemMargin;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    // Calculate target offset to center the selected item
    final targetOffset =
        (widget.selectedIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    widget.scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final genres = provider.genresPreview;
    final isLoading = provider.isLoadingGenres;
    final error = provider.genresError;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: ErrorScreen(
          errorMessage: "Janrlarni yuklashda xato: $error",
          onRetry: widget.onRetry,
        ),
      );
    }
    if (genres.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "Janrlar topilmadi",
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      );
    }

    // Calculate item dimensions based on screen width
    // Display ~3 cards at a time for optimal viewing on TV
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2; // left + right padding
    const itemMargin = 16.0; // spacing between cards
    final availableWidth = screenWidth - horizontalPadding;
    final itemWidth = (availableWidth - itemMargin * 2) / 3; // ~3 cards visible
    final itemHeight = itemWidth * (9 / 16); // 16:9 aspect ratio

    // View All kartasini qo'shish uchun umumiy uzunlik
    // Barcha janrlarni va "View All" (oxirgi kartani) kiritishni ta'minlash
    final totalItems = genres.length + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Janrlar",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: itemHeight + 50, // Image + minimal text space
            child: ListView.builder(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 8),
              itemCount: totalItems, // Barcha janrlar + View All
              itemExtent:
                  itemWidth +
                  itemMargin, // Total width per item including margin
              cacheExtent: 800,
              itemBuilder: (context, index) {
                final bool itemSelected =
                    widget.isSelected && widget.selectedIndex == index;

                // View All kartasini oxirgi element sifatida ko'rsatish
                if (index == genres.length) {
                  return ViewAllCard(
                    width: itemWidth,
                    height: itemHeight,
                    isSelected: itemSelected,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideRoute(const GenresScreen()),
                      );
                    },
                  );
                }

                final genre = genres[index];
                return GenreFilmStyleCard(
                  genre: genre,
                  itemWidth: itemWidth,
                  itemHeight: itemHeight,
                  isSelected: itemSelected,
                  onTap: () async {
                    final connectivityResult =
                        await Connectivity().checkConnectivity();
                    if (connectivityResult.every(
                      (r) => r == ConnectivityResult.none,
                    )) {
                      _showErrorDialog(
                        context,
                        'Tarmoq aloqasi yo\'q. Iltimos, internet aloqasini tekshiring.',
                      );
                    } else {
                      Navigator.push(
                        context,
                        createSlideRoute(GenresFilmsScreen(genre: genre)),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Xato", style: TextStyle(fontSize: 22)),
            content: Text(message, style: const TextStyle(fontSize: 18)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
    );
  }
}

// Janr kartasini film kartasi dizaynida ko'rsatish uchun yangi widget
// GenreFilmStyleCard widget - yangilangan versiya
class GenreFilmStyleCard extends StatelessWidget {
  final Map<String, dynamic> genre;
  final double itemWidth;
  final double itemHeight;
  final bool isSelected;
  final VoidCallback onTap;

  const GenreFilmStyleCard({
    super.key,
    required this.genre,
    required this.itemWidth,
    required this.itemHeight,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photo = genre['photo'] as Map<String, dynamic>?;
    final thumbnails = photo?['thumbnails'] as Map<String, dynamic>?;
    final smallThumb = thumbnails?['normal'] as Map<String, dynamic>?;
    final imageUrl =
        smallThumb?['src'] ?? photo?['link'] ?? 'https://placehold.co/400x225';

    final name = genre['name_uz'] ?? 'Noma\'lum';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: SizedBox(
          width: itemWidth,
          height: itemHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
                        placeholder:
                            (context, url) =>
                                Container(color: Colors.grey[800]),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                      ),
                      // Gradient overlay
                      Container(
                        width: itemWidth,
                        height: itemHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                      // Janr nomi chap pastki burchakda
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      ),
    );
  }
}

// Categories Section
class CategoriesSection extends StatelessWidget {
  final int baseSectionIndex;
  final int selectedSectionIndex;
  final int selectedItemIndex;
  final Map<int, GlobalKey> categoryKeys;
  final ScrollController Function(int) getScrollController;

  const CategoriesSection({
    super.key,
    required this.baseSectionIndex,
    required this.selectedSectionIndex,
    required this.selectedItemIndex,
    required this.categoryKeys,
    required this.getScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final categories = provider.categories;
    final categoryFilms = provider.categoryFilms;
    final isLoadingCategoryFilms = provider.isLoadingCategoryFilms;

    if (provider.isLoadingCategories) {
      return const SizedBox.shrink();
    }
    return Column(
      children:
          categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final categoryId = category['id'];
            final films = categoryFilms[categoryId] ?? [];
            final isLoading = isLoadingCategoryFilms[categoryId] ?? true;
            final sectionIndex = baseSectionIndex + index;
            final isSectionSelected = selectedSectionIndex == sectionIndex;

            // Create or get the key for this category
            if (!categoryKeys.containsKey(index)) {
              categoryKeys[index] = GlobalKey();
            }

            return Container(
              key: categoryKeys[index],
              child: CategorySection(
                category: category,
                films: films,
                isLoading: isLoading,
                isDarkMode: true,
                isSelected: isSectionSelected,
                selectedItemIndex: selectedItemIndex,
                scrollController: getScrollController(sectionIndex),
              ),
            );
          }).toList(),
    );
  }
}

// Category Section
// Category Section - Improved with scroll handling
class CategorySection extends StatefulWidget {
  final dynamic category;
  final List<dynamic> films;
  final bool isLoading;
  final bool isDarkMode;
  final bool isSelected;
  final int selectedItemIndex;
  final ScrollController scrollController;

  const CategorySection({
    super.key,
    required this.category,
    required this.films,
    required this.isLoading,
    required this.isDarkMode,
    this.isSelected = false,
    this.selectedItemIndex = 0,
    required this.scrollController,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  int _previousSelectedIndex = -1;

  @override
  void didUpdateWidget(CategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger scroll when selection changes
    if (widget.isSelected &&
        widget.selectedItemIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedItemIndex;

      // Schedule scroll after frame to ensure proper positioning
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  // Scroll the selected item into view
  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 8.0;
    final itemWidth =
        (screenWidth - horizontalPadding - itemMargin * 5.5) / 5.5;
    final itemExtent = itemWidth + itemMargin;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    // Calculate target offset to center the selected item
    final targetOffset =
        (widget.selectedItemIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    widget.scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 8.0; // Spacing between cards
    final itemWidth =
        (screenWidth - horizontalPadding - itemMargin * 5.5) /
        5.5; // Display ~5.5 cards on screen
    final itemHeight = itemWidth * 1.5;

    // Increase section height for text
    final sectionHeight = itemHeight + 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category['title_uz'] ?? 'Noma\'lum',
            style: const TextStyle(
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
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : widget.films.isEmpty
                    ? const Center(
                      child: Text(
                        "Kontent mavjud emas",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(left: 8, right: 24),
                      controller: widget.scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          widget.films.length +
                          (widget.films.isNotEmpty ? 1 : 0),
                      itemExtent:
                          itemWidth +
                          itemMargin, // Add spacing between elements
                      cacheExtent: 500,
                      itemBuilder: (context, index) {
                        if (index == widget.films.length) {
                          final itemSelected =
                              widget.isSelected &&
                              widget.selectedItemIndex == index;
                          return ViewAllCard(
                            width: itemWidth,
                            height: itemHeight,
                            isSelected: itemSelected,
                            onTap: () {
                              Navigator.push(
                                context,
                                createSlideRoute(
                                  CategoriesScreen(
                                    initialCategory: widget.category,
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        final itemSelected =
                            widget.isSelected &&
                            widget.selectedItemIndex == index;
                        return FilmItem(
                          film: widget.films[index],
                          itemWidth: itemWidth,
                          itemHeight: itemHeight,
                          isSelected: itemSelected,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// Film Item
class FilmItem extends StatelessWidget {
  final dynamic film;
  final double itemWidth;
  final double itemHeight;
  final bool isSelected;

  const FilmItem({
    super.key,
    required this.film,
    required this.itemWidth,
    required this.itemHeight,
    this.isSelected = false,
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
    final title = film['name_uz'] ?? 'Noma\'lum';
    final year = film['year']?.toString() ?? '';
    final genres = film['genres'] ?? [];
    final genreName = genres.isNotEmpty ? genres[0]['name_uz'] ?? '' : '';
    final filmId = film['id'];

    return GestureDetector(
      onTap: () {
        Navigator.push(context, createSlideRoute(FilmScreen(filmId: filmId)));
      },
      child: Padding(
        padding: const EdgeInsets.only(
          right: 3,
        ), // 4 → 3 px ga o'zgartirdik (yoki 2 kiritishingiz mumkin)
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartani alohida SizedBox ichiga o'rab, faqat uni kattalashtiramiz
            SizedBox(
              width: itemWidth,
              height: itemHeight + 16, // Border uchun qo'shimcha joy
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

            // Matnlar qimirlamaydi, chunki ular SizedBox tashqarisida
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

// GenreCard
class GenreCard extends StatelessWidget {
  final Map<String, dynamic> genre;
  final VoidCallback onTap;
  final bool isSelected;

  const GenreCard({
    super.key,
    required this.genre,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        genre['photo'] != null
            ? (genre['photo']['thumbnails'] != null &&
                    genre['photo']['thumbnails']['small'] != null &&
                    genre['photo']['thumbnails']['small']['src'] != null
                ? genre['photo']['thumbnails']['small']['src']
                : genre['photo']['link'] ?? 'https://placehold.co/350x250')
            : 'https://placehold.co/350x250';
    final name = genre['name_uz'] ?? 'Noma’lum';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform:
            isSelected ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
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
              isSelected ? Border.all(color: Colors.yellow, width: 3) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: 350,
                height: 250,
                fit: BoxFit.cover,
                cacheManager: customCacheManager,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget:
                    (context, url, error) => Container(
                      width: 350,
                      height: 250,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text(
                          'Rasmni yuklashda xato',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ),
                    ),
              ),
              Container(
                width: 350,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                    stops: const [0.7, 1.0],
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
    );
  }
}

// View All Card - navigates to full content screen
class ViewAllCard extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;
  final bool isSelected;

  const ViewAllCard({
    super.key,
    required this.width,
    required this.height,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: height + 16, // Border uchun qo'shimcha joy
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
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            width: width,
                            height: height,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 48,
                                    color:
                                        isSelected
                                            ? const Color.fromARGB(
                                              255,
                                              255,
                                              59,
                                              108,
                                            )
                                            : Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Barchasini ko'rish",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected
                                              ? const Color.fromARGB(
                                                255,
                                                255,
                                                59,
                                                108,
                                              )
                                              : Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: width,
                              height: height,
                              color: Colors.white.withOpacity(0.12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
