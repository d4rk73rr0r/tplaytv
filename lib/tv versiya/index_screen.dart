import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';

class Movie {
  final String title;
  final String year;
  final String rating;
  final String imageUrl;
  final String category;

  Movie({
    required this.title,
    required this.year,
    required this.rating,
    required this.imageUrl,
    required this.category,
  });
}

class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen>
    with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  int _selectedMenuIndex = 0;
  int _selectedMovieIndex = 0;
  int _selectedSectionIndex = 0;
  Color _backgroundColor = const Color(0xFF1a1a1a);
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Timer? _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  // Focus nodes
  final FocusNode _menuFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  late FocusNode _appBarFocusNode;
  final List<FocusNode> _appBarItemFocusNodes = [];

  late ScrollController _scrollController;
  final GlobalKey _nowWatchingKey = GlobalKey();
  final GlobalKey _recommendedKey = GlobalKey();

  // Horizontal scroll controllers (nullable emas)
  final Map<int, ScrollController> _horizontalControllers = {};

  final List<String> _menuItems = [
    'Главная',
    'Лента',
    'Фильмы',
    'Мультфильмы',
    'Сериалы',
    'Персоны',
    'Каталог',
    'Фильтр',
    'Релизы',
    'Аниме',
    'Избранное',
    'История',
  ];

  final List<IconData> _menuIcons = [
    Icons.home_outlined,
    Icons.star_outline,
    Icons.movie_outlined,
    Icons.child_care_outlined,
    Icons.tv_outlined,
    Icons.people_outline,
    Icons.category_outlined,
    Icons.filter_alt_outlined,
    Icons.new_releases_outlined,
    Icons.animation_outlined,
    Icons.bookmark_border,
    Icons.history,
  ];

  final List<Movie> _nowWatchingMovies = List.generate(
    12,
    (i) => Movie(
      title: 'Фильм ${i + 1}',
      year: '2025',
      rating: (6.0 + (i % 5)).toStringAsFixed(1),
      imageUrl: 'https://picsum.photos/300/450?random=${i + 10}',
      category: 'Сейчас смотрят',
    ),
  );

  final List<Movie> _recommendedMovies = List.generate(
    15,
    (i) => Movie(
      title: 'Рекомендация ${i + 1}',
      year: '202${3 + i % 3}',
      rating: (7.0 + (i % 6) / 2).toStringAsFixed(1),
      imageUrl: 'https://picsum.photos/300/450?random=${i + 30}',
      category: 'Рекомендуем посмотреть',
    ),
  );

  List<List<Movie>> get _allSections => [
    _nowWatchingMovies,
    _recommendedMovies,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _appBarFocusNode = FocusNode();
    _appBarItemFocusNodes.addAll(List.generate(5, (_) => FocusNode()));

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _updateDateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDateTime(),
    );

    // Horizontal controllers
    for (int i = 0; i < _allSections.length; i++) {
      _horizontalControllers[i] = ScrollController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
      _updateBackgroundColor(0, 0);
    });
  }

  void _updateDateTime() {
    setState(() {
      final now = DateTime.now();
      _currentTime = DateFormat('HH:mm').format(now);
      _currentDate = DateFormat('dd MMMM yyyy\nEEEE', 'ru_RU').format(now);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _menuFocusNode.dispose();
    _contentFocusNode.dispose();
    _appBarFocusNode.dispose();
    for (final node in _appBarItemFocusNodes) node.dispose();
    _clockTimer?.cancel();
    _scrollController.dispose();
    for (final c in _horizontalControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _updateBackgroundColor(int sectionIndex, int movieIndex) async {
    final movie = _allSections[sectionIndex][movieIndex];
    final palette = await PaletteGenerator.fromImageProvider(
      NetworkImage(movie.imageUrl),
      maximumColorCount: 20,
    );
    if (mounted) {
      setState(() {
        _backgroundColor =
            palette.dominantColor?.color ?? const Color(0xFF1a1a1a);
      });
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
        _menuFocusNode.requestFocus();
      } else {
        _animationController.reverse();
        _contentFocusNode.requestFocus();
      }
    });
  }

  void _scrollToSection(int sectionIndex) {
    final key = sectionIndex == 0 ? _nowWatchingKey : _recommendedKey;
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  // Nullable emas – hasClients tekshiruvi bilan xavfsiz scroll
  void _scrollToCurrentItem() {
    final controller = _horizontalControllers[_selectedSectionIndex];
    if (controller == null) return;

    if (controller.hasClients) {
      const double itemWidth = 200.0; // 180 + 20 margin
      final double target = _selectedMovieIndex * itemWidth;
      final double max = controller.position.maxScrollExtent;
      final double offset = target.clamp(0.0, max);

      controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedMovieIndex == 0) {
        _toggleMenu();
        return KeyEventResult.handled;
      }
      setState(() {
        _selectedMovieIndex--;
        _updateBackgroundColor(_selectedSectionIndex, _selectedMovieIndex);
        _scrollToCurrentItem();
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _selectedMovieIndex++;
        if (_selectedMovieIndex >= _allSections[_selectedSectionIndex].length) {
          _selectedMovieIndex = 0;
        }
        _updateBackgroundColor(_selectedSectionIndex, _selectedMovieIndex);
        _scrollToCurrentItem();
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_selectedSectionIndex == 0) {
        _appBarFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      setState(() {
        _selectedSectionIndex--;
        _selectedMovieIndex = 0;
        _updateBackgroundColor(_selectedSectionIndex, _selectedMovieIndex);
        _scrollToSection(_selectedSectionIndex);
        _scrollToCurrentItem();
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_selectedSectionIndex < _allSections.length - 1) {
        setState(() {
          _selectedSectionIndex++;
          _selectedMovieIndex = 0;
          _updateBackgroundColor(_selectedSectionIndex, _selectedMovieIndex);
          _scrollToSection(_selectedSectionIndex);
          _scrollToCurrentItem();
        });
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Blur background
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _backgroundColor,
                  _backgroundColor.withOpacity(0.7),
                  Colors.black,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main content (push effect)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.translationValues(_isMenuOpen ? 280 : 0, 0, 0),
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Focus(
                    focusNode: _contentFocusNode,
                    onKeyEvent: _handleContentKeyEvent,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMovieSection(
                            'Сейчас смотрят',
                            _nowWatchingMovies,
                            0,
                            _nowWatchingKey,
                          ),
                          const SizedBox(height: 40),
                          _buildMovieSection(
                            'Рекомендуем посмотреть',
                            _recommendedMovies,
                            1,
                            _recommendedKey,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sidebar menu
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: 280,
              color: const Color(0xFF1c1c1e),
              child: Focus(
                focusNode: _menuFocusNode,
                child: ListView.builder(
                  itemCount: _menuItems.length,
                  itemBuilder: (context, i) {
                    final selected = _selectedMenuIndex == i;
                    return ListTile(
                      leading: Icon(
                        _menuIcons[i],
                        color: selected ? Colors.white : Colors.white70,
                      ),
                      title: Text(
                        _menuItems[i],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: selected,
                      onTap: () => setState(() => _selectedMenuIndex = i),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.radar, size: 40, color: Colors.white),
          const SizedBox(width: 15),
          const Text(
            'Главная - TMDB',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          _appBarIcon(Icons.search, 0),
          _appBarIcon(Icons.flash_on, 1),
          _appBarIcon(Icons.notifications_outlined, 2),
          _appBarIcon(Icons.settings_outlined, 3),
          _appBarIcon(Icons.account_circle, 4, size: 32),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _currentDate.split('\n')[0],
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                _currentDate.split('\n')[1],
                style: const TextStyle(fontSize: 10, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon(IconData icon, int index, {double size = 28}) {
    return Focus(
      focusNode: _appBarItemFocusNodes[index],
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _contentFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
            _appBarItemFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight && index < 4) {
            _appBarItemFocusNodes[index + 1].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return IconButton(
            icon: Icon(icon, size: size),
            color: hasFocus ? Colors.cyanAccent : Colors.white,
            onPressed: () {},
          );
        },
      ),
    );
  }

  Widget _buildMovieSection(
    String title,
    List<Movie> movies,
    int sectionIndex,
    GlobalKey key,
  ) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (title == 'Сейчас смотрят')
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Еще',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: ListView.builder(
              controller: _horizontalControllers[sectionIndex],
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                final isSelected =
                    _selectedSectionIndex == sectionIndex &&
                    _selectedMovieIndex == index;

                return Focus(
                  onFocusChange: (focused) {
                    if (focused) {
                      setState(() {
                        _selectedSectionIndex = sectionIndex;
                        _selectedMovieIndex = index;
                        _updateBackgroundColor(sectionIndex, index);
                      });
                      _scrollToCurrentItem();
                    }
                  },
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 20),
                    child: Column(
                      children: [
                        Container(
                          height: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.cyanAccent
                                      : Colors.transparent,
                              width: 4,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.6,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                    : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  movie.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, _, __) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.movie,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      movie.rating,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          movie.year,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
