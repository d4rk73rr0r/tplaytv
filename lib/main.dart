import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tplaytv/screens/auth_screen.dart';
import 'package:tplaytv/screens/index_screen.dart';
import 'package:tplaytv/screens/tv_channels_screen.dart';
import 'package:tplaytv/screens/catalog_screen.dart';
import 'package:tplaytv/screens/favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RiyaPlayApp());
}

class RiyaPlayApp extends StatefulWidget {
  const RiyaPlayApp({super.key});

  @override
  State<RiyaPlayApp> createState() => _RiyaPlayAppState();
}

class _RiyaPlayAppState extends State<RiyaPlayApp> {
  Future<String?> _checkAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TPlay TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF111827),
        textTheme: GoogleFonts.poppinsTextTheme(
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
          backgroundColor: const Color(0xFF111827),
          titleTextStyle: GoogleFonts.poppins(
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
            return const Center(child: CircularProgressIndicator());
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;

  final List<Widget> _screens = [
    const IndexScreen(),
    const TVChannelsScreen(),
    const CatalogScreen(),
    const FavoritesScreen(),
    // const ProfileScreen(),
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': IconlyLight.home,
      'activeIcon': IconlyBold.home,
      'label': 'Bosh sahifa',
    },
    {'icon': IconlyLight.video, 'activeIcon': IconlyBold.video, 'label': 'TV'},
    {
      'icon': IconlyLight.category,
      'activeIcon': IconlyBold.category,
      'label': 'Katalog',
    },
    {
      'icon': IconlyLight.heart,
      'activeIcon': IconlyBold.heart,
      'label': 'Sevimlilar',
    },
    {
      'icon': IconlyLight.profile,
      'activeIcon': IconlyBold.profile,
      'label': 'Profil',
    },
  ];

  late AnimationController _glowController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late FocusNode _contentFocusNode;
  late FocusNode _sidebarFocusNode;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );

    _contentFocusNode = FocusNode();
    _sidebarFocusNode = FocusNode();

    // Ilova ochilganda content fokusda bo'lsin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _slideController.dispose();
    _contentFocusNode.dispose();
    _sidebarFocusNode.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _slideController.forward();
        _sidebarFocusNode.requestFocus();
      } else {
        _slideController.reverse();
        _contentFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSidebarKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _menuItems.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _menuItems.length) % _menuItems.length;
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _toggleSidebar();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        children: [
          // Asosiy kontent
          Focus(
            focusNode: _contentFocusNode,
            onKeyEvent: _handleContentKeyEvent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              margin: EdgeInsets.only(left: _isSidebarOpen ? 280 : 0),
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ),

          // Slide Sidebar
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-280 + (_slideAnimation.value * 280), 0),
                child: child,
              );
            },
            child: Focus(
              focusNode: _sidebarFocusNode,
              onKeyEvent: _handleSidebarKeyEvent,
              child: Container(
                width: 280,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(5, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Logo va sarlavha
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.cyanAccent, Colors.blue],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              IconlyBold.video,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TPlay TV',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Menyu',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.cyanAccent.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Menu items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) {
                          final item = _menuItems[index];
                          final isSelected = _selectedIndex == index;

                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween(
                              begin: 0.0,
                              end: isSelected ? 1.0 : 0.0,
                            ),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 1.0 + value * 0.05,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient:
                                        isSelected
                                            ? LinearGradient(
                                              colors: [
                                                Colors.cyanAccent.withOpacity(
                                                  0.2,
                                                ),
                                                Colors.blue.withOpacity(0.1),
                                              ],
                                            )
                                            : null,
                                    border:
                                        isSelected
                                            ? Border.all(
                                              color: Colors.cyanAccent,
                                              width: 2,
                                            )
                                            : Border.all(
                                              color: Colors.transparent,
                                              width: 2,
                                            ),
                                    boxShadow:
                                        isSelected
                                            ? [
                                              BoxShadow(
                                                color: Colors.cyanAccent
                                                    .withOpacity(
                                                      0.3 +
                                                          _glowController
                                                                  .value *
                                                              0.2,
                                                    ),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedBuilder(
                                        animation: _glowController,
                                        builder: (context, child) {
                                          return Icon(
                                            isSelected
                                                ? item['activeIcon']
                                                : item['icon'],
                                            color:
                                                isSelected
                                                    ? Colors.cyanAccent
                                                    : Colors.white70,
                                            size: 28,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          item['label'],
                                          style: GoogleFonts.poppins(
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : Colors.white70,
                                            fontSize: 16,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.cyanAccent,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Ko'rsatma
                    Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_back,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Menu',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yopish',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
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

          // Menu indicator (yopilgan holatda)
          if (!_isSidebarOpen)
            Positioned(
              left: 0,
              top: MediaQuery.of(context).size.height / 2 - 60,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSidebarOpen ? 0.0 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(color: Colors.cyanAccent, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MENU',
                        style: GoogleFonts.poppins(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
