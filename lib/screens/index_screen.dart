import 'dart:async';
import 'dart:io';
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

// Yordamchi:  navigator popdan keyin fokusni tiklash uchun
void _requestIndexFocus(BuildContext context) {
  final state = context.findAncestorStateOfType<_IndexScreenContentState>();
  state?._requestContentFocus();
}

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

// ✅ YANGI:  focusNode parametr qo'shildi
class IndexScreen extends StatelessWidget {
  final FocusNode? focusNode;

  const IndexScreen({super.key, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IndexScreenProvider(),
      child: IndexScreenContent(focusNode: focusNode), // ✅ Uzatish
    );
  }
}

// ✅ YANGI: focusNode parametr qo'shildi
class IndexScreenContent extends StatefulWidget {
  final FocusNode? focusNode;

  const IndexScreenContent({super.key, this.focusNode});

  @override
  State<IndexScreenContent> createState() => _IndexScreenContentState();
}

class _IndexScreenContentState extends State<IndexScreenContent> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ✅ YANGI: Internal yoki external FocusNode
  late final FocusNode _internalFocusNode = FocusNode(
    debugLabel: 'IndexInternal',
  );
  FocusNode get _contentFocusNode => widget.focusNode ?? _internalFocusNode;
  bool get _ownsFocusNode => widget.focusNode == null;

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
          'Tarmoq aloqasi yo\'q.  Iltimos, internet aloqasini tekshiring.',
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Re-request focus when widget becomes active again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_contentFocusNode.hasFocus &&
          ModalRoute.of(context)?.isCurrent == true) {
        _contentFocusNode.requestFocus();
        debugPrint('🎯 IndexScreen: Focus requested');
      }
    });
  }

  @override
  void didUpdateWidget(IndexScreenContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Focus'ni tiklash widget yangilanganda
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_contentFocusNode.hasFocus &&
          ModalRoute.of(context)?.isCurrent == true) {
        _contentFocusNode.requestFocus();
      }
    });
  }

  void _requestContentFocus() {
    Future.microtask(() {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _contentFocusNode.requestFocus();
      }
    });
  }
  
  /// Requests focus on this screen's content area.
  /// 
  /// Call this when the screen becomes visible (e.g., after returning from another screen
  /// or switching from sidebar) to ensure keyboard/remote navigation works properly.
  void requestFocus() {
    _requestContentFocus();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scrollController.dispose();
    for (final controller in _horizontalScrollControllers.values) {
      controller.dispose();
    }
    // ✅ Faqat o'zimizniki bo'lsa dispose qilish
    if (_ownsFocusNode) {
      _contentFocusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    provider.clearGlobalError();
    if (!(await _checkInternetConnection())) {
      provider.setGlobalError('Tarmoq xatosi', null);
      _showErrorDialog(
        'Tarmoq aloqasi yo\'q. Iltimos, internet aloqasini tekshiring.',
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
                    'name_uz,name_ru,name_en,id,films. id,films.name_uz,films.name_ru,films.publish_time,films.type,films.paid,films.year,films.tags. id,films.tags.title_uz,films.tags.title_en,films.files.thumbnails',
              ),
          onSuccess: (response) {
            final films = response['data'] ?? [];
            provider.updateLatestViewed(films);
          },
          onError:
              (error, statusCode) => provider.setGlobalError(error, statusCode),
          errorMessage: 'So\'ngi ko\'rilganlarni yuklashda xato',
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
      provider.setGlobalError('Umumiy xato:  $e', null);
      _showErrorDialog('Ma\'lumotlarni yuklashda xato:  $e');
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
        final error = data['error']?.toString() ?? 'Noma\'lum xato';
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
        'Tarmoq aloqasi yo\'q.  Iltimos, internet aloqasini tekshiring.',
      );
      return;
    }

    provider.reset();
    await _fetchInitialData();
    _requestContentFocus();
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

    if (provider.categories.isNotEmpty &&
        _selectedSectionIndex >= currentSection &&
        _selectedSectionIndex < currentSection + provider.categories.length) {
      final categoryIndex = _selectedSectionIndex - currentSection;
      if (!_categoryKeys.containsKey(categoryIndex)) {
        _categoryKeys[categoryIndex] = GlobalKey();
      }
      key = _categoryKeys[categoryIndex];
    }

    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  void _scrollToCurrentItem() {
    final controller = _horizontalScrollControllers[_selectedSectionIndex];
    if (controller == null || !controller.hasClients) return;

    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    final double viewportWidth = controller.position.viewportDimension;

    final itemDimensions = _getItemDimensionsForSection(
      _selectedSectionIndex,
      provider,
      viewportWidth,
    );
    final double itemWidth = itemDimensions['width']!;
    final double itemMargin = itemDimensions['margin']!;

    final double itemExtent = itemWidth + itemMargin;
    final double targetOffset =
        (_selectedItemIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final double maxOffset = controller.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxOffset);
    final double distance = (clampedOffset - controller.offset).abs();

    if (distance > 400) {
      controller.jumpTo(clampedOffset);
    } else {
      controller.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Map<String, double> _getItemDimensionsForSection(
    int sectionIndex,
    IndexScreenProvider provider,
    double viewportWidth,
  ) {
    int currentSection = 0;
    final double screenWidth = MediaQuery.of(context).size.width;

    if (provider.banners.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return {'width': viewportWidth * 0.9, 'margin': 16.0};
      }
      currentSection++;
    }

    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return {'width': 240.0, 'margin': 16.0};
      }
      currentSection++;
    }

    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == sectionIndex) {
        const horizontalPadding = 24.0 * 2;
        const itemMargin = 8.0;
        const visibleCardsCount = 5.5;
        final itemWidth =
            (screenWidth - horizontalPadding - itemMargin * visibleCardsCount) /
            visibleCardsCount;
        return {'width': itemWidth, 'margin': itemMargin};
      }
      currentSection++;
    }

    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == sectionIndex) {
        const horizontalPadding = 24.0 * 2;
        const itemMargin = 16.0;
        final availableWidth = screenWidth - horizontalPadding;
        final itemWidth = (availableWidth - itemMargin * 2) / 3;
        return {'width': itemWidth, 'margin': itemMargin};
      }
      currentSection++;
    }

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

    return {'width': 200.0, 'margin': 16.0};
  }

  ScrollController _getScrollControllerForSection(int sectionIndex) {
    if (!_horizontalScrollControllers.containsKey(sectionIndex)) {
      _horizontalScrollControllers[sectionIndex] = ScrollController();
    }
    return _horizontalScrollControllers[sectionIndex]!;
  }

  // TV Remote control key event handler
  KeyEventResult _handleContentKeyEvent(FocusNode node, KeyEvent event) {
    // KeyDown + KeyRepeat ni qo'llab-quvvatlash
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final provider = Provider.of<IndexScreenProvider>(context, listen: false);

    int sectionCount = 0;
    if (provider.banners.isNotEmpty) sectionCount++;
    if (provider.latestViewed.isNotEmpty) sectionCount++;
    if (provider.recommendedFilms.isNotEmpty) sectionCount++;
    if (provider.genresPreview.isNotEmpty) sectionCount++;
    if (provider.categories.isNotEmpty)
      sectionCount += provider.categories.length;

    if (sectionCount == 0) return KeyEventResult.ignored;

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

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        int maxItems = _getMaxItemsForSection(_selectedSectionIndex, provider);
        if (_selectedItemIndex < maxItems - 1) {
          _selectedItemIndex++;
        }
      });
      _scrollToCurrentItem();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedItemIndex > 0) {
        setState(() {
          _selectedItemIndex--;
        });
        _scrollToCurrentItem();
        return KeyEventResult.handled;
      } else {
        return KeyEventResult.ignored;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _activateSelectedItem(provider);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int _getMaxItemsForSection(int sectionIndex, IndexScreenProvider provider) {
    int currentSection = 0;

    if (provider.banners.isNotEmpty) {
      if (currentSection == sectionIndex) return provider.banners.length;
      currentSection++;
    }

    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.latestViewed.length + 1;
      }
      currentSection++;
    }

    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.recommendedFilms.length + 1;
      }
      currentSection++;
    }

    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == sectionIndex) {
        return provider.genresPreview.length;
      }
      currentSection++;
    }

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

  Future<void> _pushAndRefocus(Widget page) async {
    await Navigator.push(context, createSlideRoute(page));
    _requestContentFocus();
  }

  void _activateSelectedItem(IndexScreenProvider provider) {
    int currentSection = 0;

    if (provider.banners.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        final banner = provider.banners[_selectedItemIndex];
        final film = banner['film'] as Map<String, dynamic>? ?? {};
        final filmId = film['id'] ?? 0;
        if (filmId != 0) {
          _pushAndRefocus(FilmScreen(filmId: filmId));
        }
        return;
      }
      currentSection++;
    }

    if (provider.latestViewed.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        if (_selectedItemIndex == provider.latestViewed.length) {
          _pushAndRefocus(const LatestViewedScreen());
          return;
        }
        final item = provider.latestViewed[_selectedItemIndex];
        final film = item['film'] as Map<String, dynamic>? ?? {};
        final filmId = film['id'] ?? 0;
        if (filmId != 0) {
          _pushAndRefocus(FilmScreen(filmId: filmId));
        }
        return;
      }
      currentSection++;
    }

    if (provider.recommendedFilms.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        if (_selectedItemIndex == provider.recommendedFilms.length) {
          _pushAndRefocus(const RecommendedFilmsScreen());
          return;
        }
        final film = provider.recommendedFilms[_selectedItemIndex];
        final filmId = film['id'];
        _pushAndRefocus(FilmScreen(filmId: filmId));
        return;
      }
      currentSection++;
    }

    if (provider.genresPreview.isNotEmpty) {
      if (currentSection == _selectedSectionIndex) {
        if (_selectedItemIndex < provider.genresPreview.length) {
          final genre = provider.genresPreview[_selectedItemIndex];
          _pushAndRefocus(GenresFilmsScreen(genre: genre));
        }
        return;
      }
      currentSection++;
    }

    for (var category in provider.categories) {
      final categoryId = category['id'];
      final films = provider.categoryFilms[categoryId] ?? [];
      if (currentSection == _selectedSectionIndex && films.isNotEmpty) {
        if (_selectedItemIndex == films.length) {
          _pushAndRefocus(CategoriesScreen(initialCategory: category));
          return;
        }
        final film = films[_selectedItemIndex];
        final filmId = film['id'];
        _pushAndRefocus(FilmScreen(filmId: filmId));
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
      body: FocusTraversalGroup(
        child: Focus(
          autofocus: false, // ✅ Parent nazorat qiladi
          focusNode: _contentFocusNode,
          onKeyEvent: _handleContentKeyEvent,
          skipTraversal: false,
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
                            // Qism 1 ning davomi...
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
                  if (provider.recommendedFilms.isNotEmpty)
                    Container(
                      key: _recommendedKey,
                      child: RecommendedFilmsSection(
                        isSelected:
                            _selectedSectionIndex ==
                            _getRecommendedSectionIndex(),
                        selectedIndex: _selectedItemIndex,
                        scrollController: _getScrollControllerForSection(
                          _getRecommendedSectionIndex(),
                        ),
                      ),
                    ),
                  if (provider.genresPreview.isNotEmpty)
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

class _BannerCarouselState extends State<BannerCarousel> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  final List<FocusNode> _buttonFocusNodes = [];

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<IndexScreenProvider>(context, listen: false);
      final bannersCount = provider.banners.length;
      for (int i = 0; i < bannersCount; i++) {
        _buttonFocusNodes.add(FocusNode());
      }
      if (_buttonFocusNodes.isNotEmpty) {
        _buttonFocusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _buttonFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final provider = Provider.of<IndexScreenProvider>(context, listen: false);
    final banners = provider.banners;

    if (_buttonFocusNodes.length < banners.length) {
      final missingCount = banners.length - _buttonFocusNodes.length;
      for (int i = 0; i < missingCount; i++) {
        _buttonFocusNodes.add(FocusNode());
      }
    }

    final bool becameSelected = widget.isSelected && !oldWidget.isSelected;
    final bool selectedIndexChanged =
        widget.selectedIndex != oldWidget.selectedIndex;
    final bool pageMismatch = widget.selectedIndex != _currentPage;

    if (widget.isSelected &&
        (becameSelected || selectedIndexChanged || pageMismatch)) {
      _carouselController.animateToPage(widget.selectedIndex);
      if (widget.selectedIndex < _buttonFocusNodes.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _buttonFocusNodes[widget.selectedIndex].canRequestFocus) {
            _buttonFocusNodes[widget.selectedIndex].requestFocus();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<IndexScreenProvider>(context);
    final banners = provider.banners;

    return CarouselSlider(
      carouselController: _carouselController,
      options: CarouselOptions(
        height: 400.0,
        autoPlay: false,
        enlargeCenterPage: false,
        viewportFraction: 1.0,
        onPageChanged: (index, reason) {
          _currentPage = index;
          if (index < _buttonFocusNodes.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _buttonFocusNodes[index].canRequestFocus) {
                _buttonFocusNodes[index].requestFocus();
              }
            });
          }
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
                return BannerItem(
                  banner: banner,
                  isSelected: isSelected,
                  buttonFocusNode:
                      index < _buttonFocusNodes.length
                          ? _buttonFocusNodes[index]
                          : null,
                );
              },
            );
          }).toList(),
    );
  }
}

// Banner Item
class BannerItem extends StatelessWidget {
  final dynamic banner;
  final bool isSelected;
  final FocusNode? buttonFocusNode;

  const BannerItem({
    super.key,
    required this.banner,
    this.isSelected = false,
    this.buttonFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final film = banner['film'] as Map<String, dynamic>? ?? {};
    final files = banner['files'] as List<dynamic>? ?? [];
    final imageUrl =
        files.isNotEmpty
            ? files[0]['link'] ?? 'https://placehold.co/640x360'
            : 'https://placehold.co/640x360';
    final filmId = film['id'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          createSlideRoute(FilmScreen(filmId: filmId)),
        ).then((_) => _requestIndexFocus(context));
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: 400,
              fit: BoxFit.cover,
              cacheManager: customCacheManager,
              placeholder:
                  (context, url) =>
                      const Center(child: CircularProgressIndicator()),
              errorWidget:
                  (context, url, error) => Container(
                    width: double.infinity,
                    height: 400,
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
              height: 400,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 40,
              child: Focus(
                focusNode: buttonFocusNode,
                child: Builder(
                  builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          createSlideRoute(FilmScreen(filmId: filmId)),
                        ).then((_) => _requestIndexFocus(context));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 59, 108),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow:
                              isFocused
                                  ? [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      spreadRadius: 2,
                                      blurRadius: 4,
                                    ),
                                  ]
                                  : [
                                    const BoxShadow(
                                      color: Color.fromARGB(255, 255, 59, 108),
                                      spreadRadius: 1,
                                      blurRadius: 0,
                                    ),
                                  ],
                        ),
                        child: const Text(
                          'Tomosha qilish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Latest Viewed Section
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

    if (widget.isSelected &&
        widget.selectedIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    const double itemExtent = 250.0;
    const double itemWidth = 240.0;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    final targetOffset =
        (widget.selectedIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    final distance = (clampedOffset - widget.scrollController.offset).abs();

    if (distance > 400) {
      widget.scrollController.jumpTo(clampedOffset);
    } else {
      widget.scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
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
            height: 151,
            child: ListView.builder(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              itemCount:
                  latestViewed.length + (latestViewed.isNotEmpty ? 1 : 0),
              itemExtent: 250,
              cacheExtent: 500,
              itemBuilder: (context, index) {
                if (index == latestViewed.length) {
                  final itemSelected =
                      widget.isSelected && widget.selectedIndex == index;
                  return ViewAllCard(
                    width: 240,
                    height: 135,
                    isSelected: itemSelected,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideRoute(const LatestViewedScreen()),
                      ).then((_) => _requestIndexFocus(context));
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
        Navigator.push(
          context,
          createSlideRoute(FilmScreen(filmId: filmId)),
        ).then((_) => _requestIndexFocus(context));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: SizedBox(
          width: 240,
          height: 151,
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
                  child: SizedBox(
                    width: 240,
                    height: 135,
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
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
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
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color.fromARGB(255, 255, 59, 108),
                                      ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 240,
                            height: 135,
                            color: Colors.white.withOpacity(0.12),
                          ),
                      ],
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
        Navigator.push(
          context,
          createSlideRoute(FilmScreen(filmId: filmId)),
        ).then((_) => _requestIndexFocus(context));
      },
      onMoreTap: () {
        Navigator.push(
          context,
          createSlideRoute(const RecommendedFilmsScreen()),
        ).then((_) => _requestIndexFocus(context));
      },
      isDark: true,
    );
  }
}

// Genres Section
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

    if (widget.isSelected &&
        widget.selectedIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 16.0;
    final availableWidth = screenWidth - horizontalPadding;
    final itemWidth = (availableWidth - itemMargin * 2) / 3;
    final itemExtent = itemWidth + itemMargin;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    final targetOffset =
        (widget.selectedIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    final distance = (clampedOffset - widget.scrollController.offset).abs();

    if (distance > 400) {
      widget.scrollController.jumpTo(clampedOffset);
    } else {
      widget.scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
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
          errorMessage: "Janrlarni yuklashda xato:  $error",
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

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 16.0;
    final availableWidth = screenWidth - horizontalPadding;
    final itemWidth = (availableWidth - itemMargin * 2) / 3;
    final itemHeight = itemWidth * (9 / 16);

    final totalItems = genres.length;

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
            height: itemHeight + 50,
            child: ListView.builder(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 8),
              itemCount: totalItems,
              itemExtent: itemWidth + itemMargin,
              cacheExtent: 800,
              itemBuilder: (context, index) {
                final bool itemSelected =
                    widget.isSelected && widget.selectedIndex == index;

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
                        'Tarmoq aloqasi yo\'q.  Iltimos, internet aloqasini tekshiring.',
                      );
                    } else {
                      Navigator.push(
                        context,
                        createSlideRoute(GenresFilmsScreen(genre: genre)),
                      ).then((_) => _requestIndexFocus(context));
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

// Genre Film Style Card
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: itemWidth,
              height: itemHeight + 16,
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
          ],
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

    if (widget.isSelected &&
        widget.selectedItemIndex != _previousSelectedIndex &&
        widget.scrollController.hasClients) {
      _previousSelectedIndex = widget.selectedItemIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  void _scrollToSelectedItem() {
    if (!widget.scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 8.0;
    final itemWidth =
        (screenWidth - horizontalPadding - itemMargin * 5.5) / 5.5;
    final itemExtent = itemWidth + itemMargin;

    final viewportWidth = widget.scrollController.position.viewportDimension;

    final targetOffset =
        (widget.selectedItemIndex * itemExtent) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxOffset = widget.scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    final distance = (clampedOffset - widget.scrollController.offset).abs();

    if (distance > 400) {
      widget.scrollController.jumpTo(clampedOffset);
    } else {
      widget.scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 24.0 * 2;
    const itemMargin = 8.0;
    final itemWidth =
        (screenWidth - horizontalPadding - itemMargin * 5.5) / 5.5;
    final itemHeight = itemWidth * 1.5;

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
                      itemExtent: itemWidth + itemMargin,
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
                              ).then((_) => _requestIndexFocus(context));
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
        Navigator.push(
          context,
          createSlideRoute(FilmScreen(filmId: filmId)),
        ).then((_) => _requestIndexFocus(context));
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: itemWidth,
              height: itemHeight + 16,
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

// View All Card
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
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: height + 16,
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
