import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tplaytv/services/api_service.dart';
import 'package:tplaytv/main.dart';
import 'package:tplaytv/utils/navigation.dart';
import 'package:tplaytv/utils/generate_hash.dart';

class QrAuthScreen extends StatefulWidget {
  /// If your TV crops edges, open this screen with showLogo=false to move content higher.
  final bool showLogo;
  const QrAuthScreen({super.key, this.showLogo = false});

  @override
  State<QrAuthScreen> createState() => _QrAuthScreenState();
}

class _QrAuthScreenState extends State<QrAuthScreen> {
  String? _hash;
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _isLoading = false;

  static const int _initialCooldown = 60;
  int _cooldownSeconds = 0;

  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _startNewQrFlow();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startNewQrFlow() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _statusText = 'Hash yaratilmoqda...';
    });

    final newHash = generateHash(length: 32);
    setState(() {
      _hash = newHash;
    });

    try {
      final deviceName = await ApiService.getCurrentDeviceName();
      final resp = await ApiService.registerQr(newHash, deviceName: deviceName);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (resp is Map) {
        setState(() {
          _statusText = 'QR tayyor. Mobil ilovadan skanerlang.';
        });
        _startCooldown();
        _startPolling();
      } else {
        setState(() {
          _statusText = 'Roʻyxatga olishda xatolik';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusText = 'Tarmoq xatosi';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (_hash == null) return;
      final resp = await ApiService.registerQr(
        _hash!,
        deviceName: await ApiService.getCurrentDeviceName(),
      );
      if (!mounted) return;
      if (resp is Map<String, dynamic>) {
        setState(() {});
        final status = resp['status'];
        if (status == 10 && resp['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', resp['token']);
          await prefs.setString('token_id', resp['id']?.toString() ?? '');
          _pollTimer?.cancel();
          _cooldownTimer?.cancel();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            createSlideRoute(const MainScreen()),
          );
        }
      }
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _initialCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  bool get _canGenerate => _cooldownSeconds == 0 && !_isLoading;

  void _onRegeneratePressed() {
    if (!_canGenerate) {
      final remaining = Duration(seconds: _cooldownSeconds);
      final mm = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      final msg =
          'Iltimos kuting — yangi QR $mm:$ss dan keyin yaratishingiz mumkin';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    _pollTimer?.cancel();
    _startNewQrFlow();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yangi QR yaratildi'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        backgroundColor: Colors.black87,
      ),
    );
  }

  String _cooldownLabel() {
    if (_cooldownSeconds == 0) return 'Yangi QR yaratish';
    final mm = (_cooldownSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_cooldownSeconds % 60).toString().padLeft(2, '0');
    return 'Yangi QR ($mm:$ss)';
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder + SafeArea + viewPadding to avoid overscan and keep button visible.
    final viewPadding = MediaQuery.of(context).viewPadding;
    // treat bottom safe area (overscan) and add a small extra margin
    final bottomInset = max(viewPadding.bottom, 12.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0f3460),
      body: SafeArea(
        bottom:
            false, // we'll handle bottom padding ourselves using viewPadding
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;

            // compute available height excluding top/bottom system paddings and an extra margin
            final availableHeight =
                maxHeight - viewPadding.top - viewPadding.bottom - 24;

            // constrain container width so it doesn't stretch too much on wide TVs
            final containerMaxWidth = min(maxWidth * 0.78, 720.0);

            // reserve vertical space required for texts + button (so QR won't push button off-screen)
            // these numbers are conservative; adjust if you change text sizes
            const reservedForTextsAndButton = 170.0;

            // compute a safe QR size that fits both width and height constraints
            final maxQrByWidth = containerMaxWidth * 0.8;
            final maxQrByHeight = availableHeight - reservedForTextsAndButton;
            final qrSize = max(
              130.0,
              min(300.0, min(maxQrByWidth, maxQrByHeight)),
            );

            // final content height we want centered inside availableHeight
            final contentHeight = qrSize + reservedForTextsAndButton;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: maxWidth * 0.06,
                right: maxWidth * 0.06,
                top: 12,
                bottom:
                    bottomInset +
                    12, // ensure space for overscan + little margin
              ),
              child: SizedBox(
                // ensure the box takes at least availableHeight so centering works,
                // but allow it to grow for narrow screens
                height: max(availableHeight, contentHeight + 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: containerMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // optional logo
                        if (widget.showLogo) ...[
                          SizedBox(
                            height: min(84.0, containerMaxWidth * 0.14),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Card with QR + texts + button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // QR area
                              SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child:
                                    (_hash ?? '').isNotEmpty
                                        ? QrImageView(
                                          data: _hash!,
                                          version: QrVersions.auto,
                                          size: qrSize * 0.96,
                                          gapless: false,
                                          backgroundColor: Colors.white,
                                        )
                                        : Center(
                                          child: SizedBox(
                                            width: min(56.0, qrSize * 0.22),
                                            height: min(56.0, qrSize * 0.22),
                                            child: CircularProgressIndicator(
                                              color: Colors.white.withOpacity(
                                                0.9,
                                              ),
                                            ),
                                          ),
                                        ),
                              ),

                              const SizedBox(height: 12),
                              const Text(
                                'QR Kod orqali faollashtiring',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Mobil ilova orqali skanerlang',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Profilni oching va QR-kodni skanerlang',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),

                              // button - width fits text (IntrinsicWidth) and centered
                              IntrinsicWidth(
                                child: ElevatedButton(
                                  onPressed: _onRegeneratePressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _canGenerate
                                            ? const Color(0xFFe94560)
                                            : Colors.white12,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    minimumSize: const Size(0, 0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    _cooldownLabel(),
                                    style: TextStyle(
                                      color:
                                          _canGenerate
                                              ? Colors.white
                                              : Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              if (_statusText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _statusText,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
