import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tplaytv/screens/auth_screen.dart';
import 'package:tplaytv/screens/index_screen.dart';
import 'package:tplaytv/screens/tv_channels_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RiyaPlayApp());
}

class RiyaPlayApp extends StatefulWidget {
  const RiyaPlayApp({super.key});

  @override
  State<RiyaPlayApp> createState() => _RiyaPlayAppState();
}

class _RiyaPlayAppState extends State<RiyaPlayApp> with WidgetsBindingObserver {
  Future<String?> _checkAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPlay TV',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        textTheme: GoogleFonts.robotoTextTheme(
          ThemeData.dark().textTheme.copyWith(
            displayLarge: const TextStyle(fontSize: 24.0, color: Colors.white),
            displayMedium: const TextStyle(fontSize: 20.0, color: Colors.white),
            bodyLarge: const TextStyle(fontSize: 14.0, color: Colors.white),
            bodyMedium: const TextStyle(fontSize: 12.0, color: Colors.white),
            labelLarge: const TextStyle(fontSize: 14.0, color: Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24.0),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F0F0F),
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0), boldText: false),
          child: child!,
        );
      },
      home: FutureBuilder<String?>(
        future: _checkAuthToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F0F0F),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return const MainScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, RouteAware {
  static const int _indexScreenIndex = 0;
  static const int _tvChannelsScreenIndex = 1;
  
  int _selectedIndex = 0;
  bool _isSidebarExpanded = false;

  // ✅ Create the screens with keys so we can access them
  final GlobalKey<IndexScreenContentState> _indexScreenKey = GlobalKey();
  final GlobalKey<TVChannelsScreenState> _tvChannelsScreenKey = GlobalKey();
  
  late final List<Widget> _screens;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Icons.home_outlined,
      'activeIcon': Icons.home,
      'label': 'Bosh sahifa',
    },
    {
      'icon': Icons.video_library_outlined,
      'activeIcon': Icons.video_library,
      'label': 'TV Kanallar',
    },
    {'icon': Icons.apps_outlined, 'activeIcon': Icons.apps, 'label': 'Katalog'},
    {
      'icon': Icons.favorite_border,
      'activeIcon': Icons.favorite,
      'label': 'Sevimlilar',
    },
  ];

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late FocusNode _contentFocusNode;
  late FocusNode _sidebarFocusNode;

  FocusNode? _lastFocusedContentNode;

  // Exit menu
  bool _isExitMenuOpen = false;
  int _exitSelectedIndex = 0;
  late AnimationController _exitMenuController;
  late Animation<Offset> _exitMenuSlide;
  late FocusNode _exitMenuFocusNode;
  FocusNode? _lastFocusBeforeExitMenu;
  bool _ignoreNextWillPop = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize screens with keys
    _screens = [
      IndexScreen(key: _indexScreenKey),
      TVChannelsScreen(key: _tvChannelsScreenKey),
    ];
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _contentFocusNode = FocusNode();
    _sidebarFocusNode = FocusNode();

    _exitMenuController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _exitMenuSlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _exitMenuController, curve: Curves.easeOutCubic),
    );
    _exitMenuFocusNode = FocusNode(debugLabel: 'ExitMenu');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _expandController.dispose();
    _contentFocusNode.dispose();
    _sidebarFocusNode.dispose();
    _exitMenuController.dispose();
    _exitMenuFocusNode.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _restoreLastContentFocus();
  }

  void _restoreLastContentFocus() {
    Future.microtask(() {
      if (!mounted) return;
      
      // If we changed screens or don't have a saved focus node, request focus on the current screen
      if (_lastFocusedContentNode == null ||
          !_lastFocusedContentNode!.canRequestFocus) {
        _requestFocusOnCurrentScreen();
      } else {
        // Otherwise, try to restore the saved focus node
        _lastFocusedContentNode!.requestFocus();
        debugPrint('🎯 Main: Restored focus to saved node');
      }
    });
  }
  
  void _requestFocusOnCurrentScreen() {
    debugPrint('🎯 Main: Requesting focus on screen index $_selectedIndex');
    
    // Request focus on the appropriate screen
    if (_selectedIndex == _indexScreenIndex && _indexScreenKey.currentState != null) {
      _indexScreenKey.currentState!.requestFocus();
      debugPrint('🎯 Main: Requested focus on IndexScreen');
    } else if (_selectedIndex == _tvChannelsScreenIndex && _tvChannelsScreenKey.currentState != null) {
      _tvChannelsScreenKey.currentState!.requestFocus();
      debugPrint('🎯 Main: Requested focus on TVChannelsScreen');
    } else {
      // Fallback: request focus on the content node
      _contentFocusNode.requestFocus();
      debugPrint('🎯 Main: Fallback - requested focus on content node');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
      if (_isSidebarExpanded) {
        _lastFocusedContentNode = FocusManager.instance.primaryFocus;
        _expandController.forward();
        _sidebarFocusNode.requestFocus();
      } else {
        _expandController.reverse();
        Future.microtask(() {
          _sidebarFocusNode.unfocus();
          _restoreLastContentFocus();
        });
      }
    });
  }

  KeyEventResult _handleContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.navigatePrevious;
  }

  KeyEventResult _handleSidebarKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent &&
        event is! KeyRepeatEvent &&
        event is! KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_isBackKey(key)) {
      if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
          _isSidebarExpanded) {
        _toggleSidebar();
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _menuItems.length;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _menuItems.length) % _menuItems.length;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      _onMenuItemSelected(_selectedIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onMenuItemSelected(int index) {
    // Catalog va Favorites vaqtincha disabled (index 2 va 3)
    if (index > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu sahifa hozircha mavjud emas'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      // If we're changing screens, clear the last focused node
      // so we don't try to restore focus to the wrong screen
      if (_selectedIndex != index) {
        _lastFocusedContentNode = null;
      }
      _selectedIndex = index;
    });
    _toggleSidebar();
  }

  Future<bool> _onWillPop() async {
    if (_ignoreNextWillPop) {
      _ignoreNextWillPop = false;
      return false;
    }
    if (_isExitMenuOpen) {
      _closeExitMenu();
      return false;
    }
    if (_isSidebarExpanded) {
      _toggleSidebar();
      return false;
    }
    _openExitMenu();
    return false;
  }

  void _openExitMenu() {
    if (_isExitMenuOpen) return;
    setState(() {
      _isExitMenuOpen = true;
      _exitSelectedIndex = 0;
      _lastFocusBeforeExitMenu = FocusManager.instance.primaryFocus;
    });
    _exitMenuController.forward();
    Future.microtask(() {
      if (mounted && _isExitMenuOpen) {
        _exitMenuFocusNode.requestFocus();
      }
    });
  }

  void _closeExitMenu() {
    if (!_isExitMenuOpen) return;
    setState(() {
      _isExitMenuOpen = false;
    });
    _exitMenuController.reverse();
    Future.microtask(() {
      final node = _lastFocusBeforeExitMenu;
      _lastFocusBeforeExitMenu = null;
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      } else {
        _restoreLastContentFocus();
      }
    });
  }

  void _activateExitSelection() {
    if (_exitSelectedIndex == 0) {
      SystemNavigator.pop();
    } else {
      _closeExitMenu();
    }
  }

  KeyEventResult _handleExitMenuKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent &&
        event is! KeyRepeatEvent &&
        event is! KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_isBackKey(key)) {
      _ignoreNextWillPop = true;
      _closeExitMenu();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _closeExitMenu();
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _exitSelectedIndex = _exitSelectedIndex == 0 ? 1 : 0;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      _activateExitSelection();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildExitOption({
    required String label,
    required int index,
    required IconData icon,
  }) {
    final isSelected = _exitSelectedIndex == index;
    return InkWell(
      onTap: _isExitMenuOpen ? () => _onExitOptionTapped(index) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white70 : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onExitOptionTapped(int index) {
    setState(() {
      _exitSelectedIndex = index;
    });
    _activateExitSelection();
  }

  Widget _buildExitMenuOverlay() {
    return AnimatedBuilder(
      animation: _exitMenuController,
      builder: (context, child) {
        final visible = _exitMenuController.value > 0.0 || _isExitMenuOpen;
        if (!visible) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: !_isExitMenuOpen,
          child: Stack(
            children: [
              Opacity(
                opacity: 0.4 * _exitMenuController.value,
                child: GestureDetector(
                  onTap: _closeExitMenu,
                  child: Container(color: Colors.black),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SlideTransition(
                  position: _exitMenuSlide,
                  child: Container(
                    width: 320,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1C),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 12,
                          offset: Offset(-6, 0),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: Focus(
                      focusNode: _exitMenuFocusNode,
                      onKeyEvent: _handleExitMenuKeyEvent,
                      canRequestFocus: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ilovadan chiqasizmi? ',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildExitOption(
                            label: 'Ha, chiqaman',
                            index: 0,
                            icon: Icons.exit_to_app,
                          ),
                          const SizedBox(height: 12),
                          _buildExitOption(
                            label: "Yo'q",
                            index: 1,
                            icon: Icons.close,
                          ),
                          const Spacer(),
                          Text(
                            'Back tugmasi bilan bu oynani yopishingiz mumkin.',
                            style: GoogleFonts.roboto(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Stack(
          children: [
            // ✅ Main content - main. dart.bak dagi kabi
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                autofocus: true,
                focusNode: _contentFocusNode,
                onKeyEvent: _handleContentKeyEvent,
                skipTraversal: false,
                descendantsAreFocusable: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(left: _isSidebarExpanded ? 240 : 72),
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ),
            ),

            // Sidebar
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                final width = 72 + (_expandAnimation.value * 168);
                return Container(
                  width: width,
                  decoration: const BoxDecoration(color: Color(0xFF212121)),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Focus(
                      focusNode: _sidebarFocusNode,
                      onKeyEvent: _handleSidebarKeyEvent,
                      child: Column(
                        children: [
                          // Logo
                          Container(
                            height: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                if (_isSidebarExpanded) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'TPlay TV',
                                      style: GoogleFonts.roboto(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.fade,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),

                          const SizedBox(height: 8),

                          // Menu items
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _menuItems.length,
                              itemBuilder: (context, index) {
                                final item = _menuItems[index];
                                final isSelected = _selectedIndex == index;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      focusColor: Colors.white.withOpacity(
                                        0.12,
                                      ),
                                      hoverColor: Colors.white.withOpacity(
                                        0.06,
                                      ),
                                      highlightColor: Colors.white.withOpacity(
                                        0.08,
                                      ),
                                      onTap: () => _onMenuItemSelected(index),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        height: 56,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? item['activeIcon']
                                                  : item['icon'],
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                            if (_isSidebarExpanded) ...[
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child: Text(
                                                  item['label'],
                                                  style: GoogleFonts.roboto(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                  ),
                                                  overflow: TextOverflow.fade,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Settings
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                focusColor: Colors.white.withOpacity(0.12),
                                hoverColor: Colors.white.withOpacity(0.06),
                                highlightColor: Colors.white.withOpacity(0.08),
                                onTap: () {},
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.settings_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      if (_isSidebarExpanded) ...[
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Text(
                                            'Sozlamalar',
                                            style: GoogleFonts.roboto(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            overflow: TextOverflow.fade,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Exit menu
            _buildExitMenuOverlay(),
          ],
        ),
      ),
    );
  }
}
