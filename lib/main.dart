import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tplaytv/screens/auth_screen.dart';
import 'package:tplaytv/screens/index_screen.dart';
import 'package:tplaytv/screens/tv_channels_screen.dart';
import 'package:tplaytv/screens/catalog_screen.dart';
import 'package:tplaytv/screens/favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dpad/dpad.dart';

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
    return DpadNavigator(
      enabled: true,
      child: MaterialApp(
        title: 'TPlay TV',
        debugShowCheckedModeBanner: false,
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return const MainScreen();
            }
            return const AuthScreen();
          },
        ),
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
  bool _isSidebarExpanded = false;

  final List<Widget> _screens = [
    const IndexScreen(),
    const TVChannelsScreen(),
    const CatalogScreen(),
    const FavoritesScreen(),
  ];

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
    {
      'icon': Icons.person_outline,
      'activeIcon': Icons.person,
      'label': 'Profil',
    },
  ];

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
      if (_isSidebarExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Asosiy kontent - wrapped with DpadFocusable to handle left arrow
          DpadFocusable(
            autofocus: !_isSidebarExpanded,
            onFocus: () {
              // When content gets focus and sidebar is expanded, close it
              if (_isSidebarExpanded) {
                _toggleSidebar();
              }
            },
            builder: (context, isFocused, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(left: _isSidebarExpanded ? 240 : 72),
                child: IndexedStack(index: _selectedIndex, children: _screens),
              );
            },
          ),

          // YouTube TV Style Sidebar
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              final width = 72 + (_expandAnimation.value * 168); // 72 to 240
              return Container(
                width: width,
                decoration: const BoxDecoration(color: Color(0xFF212121)),
                child: Column(
                  children: [
                    // Logo section
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

                    // Divider
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

                          return DpadFocusable(
                            autofocus: index == 0 && _isSidebarExpanded,
                            onSelect: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                              if (_isSidebarExpanded) {
                                _toggleSidebar();
                              }
                            },
                            builder: (context, isFocused, child) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? Colors.white.withOpacity(0.25)
                                      : (isSelected
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.transparent),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFocused
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                       Icon(
                                        isSelected || isFocused
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
                                                  (isSelected || isFocused)
                                                      ? FontWeight.w500
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
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Settings at bottom
                    DpadFocusable(
                      onSelect: () {
                        // Handle settings
                      },
                      builder: (context, isFocused, child) {
                        return Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? Colors.white.withOpacity(0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFocused
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
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
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
