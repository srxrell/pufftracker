import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/features/floating_mascot.dart';
import 'package:untitled/features/puff_detect.dart';
import 'package:untitled/screens/live_share.dart';
import 'package:untitled/screens/main_navigation.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/deep_link_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/sound_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int narko_count = 0;
  double dizzyProgress = 0.0;
  double maxPuffSeconds = 0.0;
  bool isTracking = false;
  String _lastStatus = "";
  bool _isOpeningLiveRoom = false;

  CameraController? _cameraController;
  final PuffDetector _detector = PuffDetector();
  Timer? _decayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    narko_count = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
    _decayTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (dizzyProgress > 0 && mounted) {
        setState(() {
          dizzyProgress = (dizzyProgress - 0.005).clamp(0.0, 1.0);
        });
      }
    });

    DeepLinkService.pendingRoomCode.addListener(_onPendingDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPendingDeepLink();
      DeepLinkService.checkClipboardForInvite();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onPendingDeepLink();
      DeepLinkService.checkClipboardForInvite();
    }
  }

  void _onPendingDeepLink() {
    if (!mounted || _isOpeningLiveRoom) return;
    final code = DeepLinkService.consumePendingRoomCode();
    if (code != null && code.isNotEmpty) {
      _openLiveWithRoomCode(code);
    }
  }

  Future<void> _openLiveWithRoomCode(String roomCode) async {
    if (_isOpeningLiveRoom || !mounted) return;
    _isOpeningLiveRoom = true;
    DeepLinkService.dismissClipboardInvite(roomCode);
    if (isTracking) {
      await _toggleTracking();
    }
    if (!mounted) {
      _isOpeningLiveRoom = false;
      return;
    }
    MainNavigation.toTab(0);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveShare(initialRoomCode: roomCode),
      ),
    );
    _isOpeningLiveRoom = false;
    if (!mounted) return;
    setState(() {
      narko_count = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
    });
  }

  Future<void> _toggleTracking() async {
    if (isTracking) {
      await _detector.stopAudioListening();
      final oldController = _cameraController;
      setState(() {
        _cameraController = null;
        isTracking = false;
      });
      await oldController?.stopImageStream();
      await oldController?.dispose();
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _lastStatus = tr("Camera not found", "Камера не найдена");
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) return;

      _detector.startAudioListening();

      setState(() {
        _cameraController = controller;
        isTracking = true;
      });

      controller.startImageStream((CameraImage image) async {
        if (!isTracking) return;
        try {
          final puffDuration = await _detector.processCameraImage(
            image,
            frontCamera,
            controller.value.deviceOrientation,
          );

          if (puffDuration != null && mounted && isTracking) {
            _registerPuff(puffDuration);
          } else if (mounted && _lastStatus != _detector.currentStatus) {
            setState(() {
              _lastStatus = _detector.currentStatus;
            });
          }
        } catch (_) {}
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          isTracking = false;
          _cameraController = null;
          _lastStatus = tr("No camera access", "Нет доступа к камере");
        });
      }
    }
  }

  void _registerPuff([double durationSec = 2.0]) {
    SoundService.playPuffSound();
    setState(() {
      narko_count++;
      if (durationSec > maxPuffSeconds) {
        maxPuffSeconds = durationSec;
      }
      dizzyProgress = (dizzyProgress + ToleranceService.calculateDizzyIncrement(durationSec))
          .clamp(0.0, 1.0);
    });
    AuthService.updatePuffs(narko_count);
    MascotService.evaluatePuff(
      durationSec: durationSec,
      dizzyProgress: dizzyProgress,
    );
  }

  void _unregisterPuff([double durationSec = 2.0]) {
    if (narko_count <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      narko_count--;
      if (durationSec > maxPuffSeconds) {
        maxPuffSeconds = durationSec;
      }
    });
    AuthService.updatePuffs(narko_count);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService.pendingRoomCode.removeListener(_onPendingDeepLink);
    _decayTimer?.cancel();
    _cameraController?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final primaryColor = ThemeService.primaryColor;
    final onPrimary = ThemeService.onPrimaryColor;
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final isDanger = dizzyProgress >= 0.75;
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "PuffTrack",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: CircleAvatar(
                radius: 12,
                backgroundColor: primaryColor,
                child: Text(
                  user != null && user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : "?",
                  style: TextStyle(fontSize: 11, color: onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              label: Text(
                user?.username ?? tr("Guest", "Гость"),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
              ),
              side: BorderSide.none,
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                MainNavigation.toTab(2);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: DeepLinkService.clipboardRoomInvite,
                    builder: (context, inviteCode, _) {
                      if (inviteCode == null || inviteCode.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: ThemeService.accentLight(isDark),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sensors_rounded, color: primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(
                                      "Room invite found: puff.gg/$inviteCode",
                                      "Приглашение в эфир: puff.gg/$inviteCode",
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    tr(
                                      "Tap Join to connect with your friend",
                                      "Нажми «Войти», чтобы подключиться к другу",
                                    ),
                                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 34),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _openLiveWithRoomCode(inviteCode),
                              child: Text(
                                tr("Join", "Войти"),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: onPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                              onPressed: () => DeepLinkService.dismissClipboardInvite(inviteCode),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 215,
                      width: double.infinity,
                      color: cardBg,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isTracking &&
                              _cameraController != null &&
                              _cameraController!.value.isInitialized) ...[
                            SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _cameraController!.value.previewSize!.height,
                                  height: _cameraController!.value.previewSize!.width,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _detector.currentStatus,
                                  style: TextStyle(
                                    color: _detector.isPuffing ? Colors.greenAccent : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            Icon(
                              Icons.videocam_off_outlined,
                              size: 34,
                              color: textSecondary.withValues(alpha: 0.45),
                            ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: onPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    if (isTracking) {
                                      await _toggleTracking();
                                    }
                                    if (!context.mounted) return;
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => const LiveShare()),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      narko_count = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sensors, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        tr("Live", "Эфир"),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isTracking
                                        ? (isDark ? const Color(0xFF44413E) : const Color(0xFF333333))
                                        : ThemeService.accentLight(isDark),
                                    foregroundColor: isTracking ? Colors.white : textPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _toggleTracking,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isTracking ? Icons.stop_rounded : Icons.videocam_outlined, size: 17),
                                      const SizedBox(width: 5),
                                      Text(
                                        isTracking ? tr("Stop", "Стоп") : tr("AI Cam", "Камера"),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: ThemeService.accentLight(isDark),
                                foregroundColor: textPrimary,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _unregisterPuff(),
                              icon: Icon(Icons.remove_rounded, color: textPrimary),
                            ),
                            Column(
                              children: [
                                Text(
                                  "$narko_count",
                                  style: TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr("puffs tracked", "затяжек"),
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: onPrimary,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _registerPuff(),
                              icon: Icon(Icons.add_rounded, color: onPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isDanger
                                  ? tr("High intensity — take a break", "Сейчас даст в бошку")
                                  : tr("Session Intensity", "Накур"),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDanger ? const Color(0xFFD32F2F) : textSecondary,
                              ),
                            ),
                            Text(
                              "${(dizzyProgress * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDanger ? const Color(0xFFD32F2F) : textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: dizzyProgress,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF33312E) : const Color(0xFFECE6DA),
                            color: isDanger ? const Color(0xFFD32F2F) : primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Floating Mascot at the bottom of the screen with thought bubble
            Positioned(
              bottom: 8,
              left: 4,
              right: 4,
              child: FloatingMascot(
                currentPuffs: narko_count,
                onPuffsBoosted: (newTotal) {
                  setState(() {
                    narko_count = newTotal;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
