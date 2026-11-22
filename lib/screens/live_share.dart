import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:delightful_toast/delight_toast.dart';
import 'package:delightful_toast/toast/components/toast_card.dart';
import 'package:delightful_toast/toast/utils/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled/features/puff_detect.dart';
import 'package:untitled/screens/legal_screen.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/compliance_service.dart';
import 'package:untitled/services/deep_link_service.dart';
import 'package:untitled/services/device_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/sound_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

enum LiveMode { roulette, link }

class _ChatMessage {
  final String sender;
  final String text;
  final bool isMe;

  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
  });
}

class _FloatingReaction {
  final int id;
  final String emoji;
  final double startX;
  final bool fromPeer;

  const _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.fromPeer,
  });
}

class LiveShare extends StatefulWidget {
  final String? initialRoomCode;

  const LiveShare({super.key, this.initialRoomCode});

  @override
  State<LiveShare> createState() => _LiveShareState();
}

class _LiveShareState extends State<LiveShare> with TickerProviderStateMixin, WidgetsBindingObserver {
  LiveMode _mode = LiveMode.roulette;
  bool _rulesAccepted = ComplianceService.hasAcceptedLiveTerms;

  late String _myShortCode;
  late String _activeRoomCode;

  late final String _myPeerId;
  late final String _myUsername;
  int _mySessionPuffs = 0;
  double _dizzyProgress = 0.0;
  bool _myIsPuffingNow = false;

  // Camera
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  CameraController? _cameraController;
  bool _cameraEnabled = true;
  final PuffDetector _detector = PuffDetector();
  DateTime _lastFrameSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isEncodingFrame = false;

  // Real Peer state
  bool _isSearching = true;
  bool _isConnected = false;
  String? _connectedPeerId;
  String _peerName = "";
  String _peerDevice = "";
  String _peerDeviceType = 'vape';
  int _peerSessionPuffs = 0;
  bool _peerIsPuffingNow = false;
  Uint8List? _peerFrameBytes;
  DateTime? _lastPeerHeartbeat;
  int _onlineInLiveCount = 1;

  String? _lastSkippedPeerId;
  DateTime? _lastSkipTime;

  // PK Battle 60s
  bool _battleActive = false;
  int _battleSecondsLeft = 60;
  int _myBattlePuffs = 0;
  int _peerBattlePuffs = 0;
  Timer? _battleTimer;

  // Chat & Reactions
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  final List<_FloatingReaction> _reactions = [];
  int _reactionSeq = 0;

  // Supabase Realtime Channels
  RealtimeChannel? _lobbyChannel;
  bool _lobbySubscribed = false;
  RealtimeChannel? _roomChannel;
  String? _subscribedRoomTopic;

  Timer? _matchmakingLoopTimer;
  Timer? _roomHeartbeatTimer;
  late final AnimationController _pulseAnimController;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _myPeerId = 'peer_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(9000) + 1000}';
    _myUsername = AuthService.currentUser?.username ?? 'user_${rng.nextInt(900) + 100}';
    _myShortCode = (rng.nextInt(900) + 100).toString();
    _activeRoomCode = widget.initialRoomCode ?? _myShortCode;
    _peerName = tr("Searching...", "Поиск...");

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addObserver(this);
    DeepLinkService.pendingRoomCode.addListener(_onIncomingDeepLinkInLive);
    DeepLinkService.checkClipboardForInvite(currentActiveCode: _activeRoomCode);

    if (_rulesAccepted) {
      _startLiveServices();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onIncomingDeepLinkInLive();
      DeepLinkService.checkClipboardForInvite(currentActiveCode: _activeRoomCode);
    }
  }

  void _onIncomingDeepLinkInLive() {
    if (!mounted) return;
    final code = DeepLinkService.consumePendingRoomCode();
    if (code != null && code.isNotEmpty) {
      if (_rulesAccepted) {
        _startLinkRoom(code);
      } else {
        _activeRoomCode = code;
        _mode = LiveMode.link;
      }
    }
  }

  void _startLiveServices() {
    _initCamera();
    _initGlobalLobbyChannel();

    if (widget.initialRoomCode != null) {
      _mode = LiveMode.link;
      _startLinkRoom(widget.initialRoomCode!);
    } else {
      _startRouletteSearch();
    }

    _matchmakingLoopTimer?.cancel();
    _matchmakingLoopTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted || !_rulesAccepted) return;
      if (_mode == LiveMode.roulette && _isSearching && !_isConnected) {
        _broadcastRouletteSeek();
        _tryMatchFromLobbyPresence();
      }
    });

    _roomHeartbeatTimer?.cancel();
    _roomHeartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_rulesAccepted) return;
      _sendRoomHeartbeat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService.pendingRoomCode.removeListener(_onIncomingDeepLinkInLive);
    _battleTimer?.cancel();
    _matchmakingLoopTimer?.cancel();
    _roomHeartbeatTimer?.cancel();
    _pulseAnimController.dispose();
    _disposeChannels();
    _detector.stopAudioListening();
    _cameraController?.dispose();
    _detector.dispose();
    _chatController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _disposeChannels() async {
    final client = Supabase.instance.client;
    try {
      if (_roomChannel != null) {
        final room = _roomChannel!;
        _roomChannel = null;
        await room.sendBroadcastMessage(
          event: 'peer_leave',
          payload: {'peerId': _myPeerId},
        );
        await client.removeChannel(room);
      }
    } catch (_) {}
    try {
      if (_lobbyChannel != null) {
        final lobby = _lobbyChannel!;
        _lobbyChannel = null;
        await lobby.untrack();
        await client.removeChannel(lobby);
      }
    } catch (_) {}
  }

  Future<void> _closeCurrentRoomChannel({bool notifyLeave = true}) async {
    if (_roomChannel == null) return;
    final room = _roomChannel!;
    _roomChannel = null;
    _subscribedRoomTopic = null;
    try {
      if (notifyLeave) {
        await room.sendBroadcastMessage(
          event: 'peer_leave',
          payload: {'peerId': _myPeerId},
        );
      }
      await Supabase.instance.client.removeChannel(room);
    } catch (_) {}
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return raw;
  }

  // ===========================================================================
  // GLOBAL ROULETTE LOBBY (REAL PLAYERS MATCHMAKING)
  // ===========================================================================

  void _initGlobalLobbyChannel() {
    try {
      final client = Supabase.instance.client;
      final lobby = client.channel(
        'puff_roulette_lobby_live',
        opts: const RealtimeChannelConfig(self: false),
      );

      lobby
          .onPresenceSync((_) {
            if (!mounted) return;
            _updateLobbyPresenceCount();
            if (_mode == LiveMode.roulette && _isSearching && !_isConnected) {
              _tryMatchFromLobbyPresence();
            }
          })
          .onPresenceJoin((_) {
            if (!mounted) return;
            _updateLobbyPresenceCount();
            if (_mode == LiveMode.roulette && _isSearching && !_isConnected) {
              _tryMatchFromLobbyPresence();
            }
          })
          .onPresenceLeave((_) {
            if (!mounted) return;
            _updateLobbyPresenceCount();
          })
          .onBroadcast(
            event: 'roulette_seek',
            callback: (rawPayload) {
              if (!mounted || _mode != LiveMode.roulette || !_isSearching || _isConnected) {
                return;
              }
              final data = _unwrapPayload(rawPayload);
              final otherPeerId = data['peerId']?.toString();
              final otherRoomCode = data['roomCode']?.toString();
              if (otherPeerId == null || otherPeerId == _myPeerId || otherRoomCode == null) {
                return;
              }
              if (ComplianceService.isPeerBlocked(otherPeerId)) return;
              if (_isPeerOnSkipCooldown(otherPeerId)) return;

              _pairWithRealPeer(
                otherPeerId: otherPeerId,
                otherRoomCode: otherRoomCode,
                otherUsername: data['username']?.toString() ?? tr('User', 'Смокер'),
                otherDevice: data['device']?.toString() ?? '',
                otherDeviceType: data['deviceType']?.toString() ?? 'vape',
              );
            },
          )
          .onBroadcast(
            event: 'roulette_pair',
            callback: (rawPayload) {
              if (!mounted || _mode != LiveMode.roulette) return;
              final data = _unwrapPayload(rawPayload);
              final toPeerId = data['toPeerId']?.toString();
              final fromPeerId = data['fromPeerId']?.toString();
              final agreedRoom = data['roomCode']?.toString();

              if (toPeerId != _myPeerId || fromPeerId == null || agreedRoom == null) {
                return;
              }
              if (ComplianceService.isPeerBlocked(fromPeerId)) return;
              if (!_isSearching && _connectedPeerId != fromPeerId) return;

              _enterMatchedRoom(
                roomCode: agreedRoom,
                peerId: fromPeerId,
                peerName: data['username']?.toString() ?? tr('User', 'Смокер'),
                peerDevice: data['device']?.toString() ?? '',
                peerDeviceType: data['deviceType']?.toString() ?? 'vape',
              );
            },
          )
          .subscribe((status, _) async {
            if (!mounted) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              _lobbySubscribed = true;
              await _updateMyLobbyPresence();
              if (_mode == LiveMode.roulette && _isSearching) {
                _broadcastRouletteSeek();
              }
            }
          });

      _lobbyChannel = lobby;
    } catch (_) {}
  }

  Future<void> _updateMyLobbyPresence() async {
    if (_lobbyChannel == null || !_lobbySubscribed) return;
    try {
      final dev = DeviceService.activeDevice.value;
      await _lobbyChannel!.track({
        'peerId': _myPeerId,
        'username': _myUsername,
        'device': dev.name,
        'deviceType': dev.type,
        'roomCode': _myShortCode,
        'searching': _mode == LiveMode.roulette && _isSearching && !_isConnected,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  void _updateLobbyPresenceCount() {
    if (_lobbyChannel == null) return;
    try {
      final states = _lobbyChannel!.presenceState();
      final Set<String> uniquePeers = {_myPeerId};
      for (final s in states) {
        for (final p in s.presences) {
          final pid = p.payload['peerId']?.toString();
          if (pid != null && pid.isNotEmpty && !ComplianceService.isPeerBlocked(pid)) {
            uniquePeers.add(pid);
          }
        }
      }
      if (mounted && _onlineInLiveCount != uniquePeers.length) {
        setState(() {
          _onlineInLiveCount = uniquePeers.length;
        });
      }
    } catch (_) {}
  }

  bool _isPeerOnSkipCooldown(String otherPeerId) {
    if (_lastSkippedPeerId != otherPeerId || _lastSkipTime == null) return false;
    final elapsedMs = DateTime.now().difference(_lastSkipTime!).inMilliseconds;
    return elapsedMs < 3200;
  }

  void _tryMatchFromLobbyPresence() {
    if (_lobbyChannel == null || !_lobbySubscribed || !_isSearching || _isConnected) return;
    try {
      final states = _lobbyChannel!.presenceState();
      for (final s in states) {
        for (final p in s.presences) {
          final data = p.payload;
          final otherPeerId = data['peerId']?.toString();
          final otherRoomCode = data['roomCode']?.toString();
          final isOtherSearching = data['searching'] == true;

          if (otherPeerId != null &&
              otherPeerId != _myPeerId &&
              otherRoomCode != null &&
              isOtherSearching &&
              !ComplianceService.isPeerBlocked(otherPeerId) &&
              !_isPeerOnSkipCooldown(otherPeerId)) {
            _pairWithRealPeer(
              otherPeerId: otherPeerId,
              otherRoomCode: otherRoomCode,
              otherUsername: data['username']?.toString() ?? tr('User', 'Смокер'),
              otherDevice: data['device']?.toString() ?? '',
              otherDeviceType: data['deviceType']?.toString() ?? 'vape',
            );
            return;
          }
        }
      }
    } catch (_) {}
  }

  void _broadcastRouletteSeek() {
    if (_lobbyChannel == null || !_lobbySubscribed || !_isSearching || _isConnected) return;
    try {
      final dev = DeviceService.activeDevice.value;
      _lobbyChannel!.sendBroadcastMessage(
        event: 'roulette_seek',
        payload: {
          'peerId': _myPeerId,
          'username': _myUsername,
          'device': dev.name,
          'deviceType': dev.type,
          'roomCode': _myShortCode,
        },
      );
    } catch (_) {}
  }

  void _pairWithRealPeer({
    required String otherPeerId,
    required String otherRoomCode,
    required String otherUsername,
    required String otherDevice,
    required String otherDeviceType,
  }) {
    if (!_isSearching || _isConnected) return;
    if (ComplianceService.isPeerBlocked(otherPeerId)) return;

    final String agreedRoom =
        (_myPeerId.compareTo(otherPeerId) < 0) ? _myShortCode : otherRoomCode;

    final dev = DeviceService.activeDevice.value;
    try {
      _lobbyChannel?.sendBroadcastMessage(
        event: 'roulette_pair',
        payload: {
          'fromPeerId': _myPeerId,
          'toPeerId': otherPeerId,
          'roomCode': agreedRoom,
          'username': _myUsername,
          'device': dev.name,
          'deviceType': dev.type,
        },
      );
    } catch (_) {}

    _enterMatchedRoom(
      roomCode: agreedRoom,
      peerId: otherPeerId,
      peerName: otherUsername,
      peerDevice: otherDevice,
      peerDeviceType: otherDeviceType,
    );
  }

  Future<void> _enterMatchedRoom({
    required String roomCode,
    required String peerId,
    required String peerName,
    required String peerDevice,
    required String peerDeviceType,
  }) async {
    if (ComplianceService.isPeerBlocked(peerId)) return;
    if (_isConnected && _connectedPeerId == peerId && _activeRoomCode == roomCode) {
      return;
    }

    setState(() {
      _isSearching = false;
      _isConnected = true;
      _connectedPeerId = peerId;
      _activeRoomCode = roomCode;
      _peerName = peerName;
      _peerDevice = peerDevice;
      _peerDeviceType = peerDeviceType;
      _peerSessionPuffs = 0;
      _peerFrameBytes = null;
      _lastPeerHeartbeat = DateTime.now();
    });

    HapticFeedback.mediumImpact();
    unawaited(_updateMyLobbyPresence());
    await _subscribeToRoomChannel(roomCode);
  }

  // ===========================================================================
  // ROULETTE & SHORT LINK ROOM MANAGEMENT
  // ===========================================================================

  Future<void> _startRouletteSearch() async {
    if (_battleActive) _stopBattle();
    await _closeCurrentRoomChannel(notifyLeave: true);

    _myShortCode = (Random().nextInt(900) + 100).toString();
    _activeRoomCode = _myShortCode;

    if (!mounted) return;
    setState(() {
      _mode = LiveMode.roulette;
      _isSearching = true;
      _isConnected = false;
      _connectedPeerId = null;
      _peerFrameBytes = null;
      _peerSessionPuffs = 0;
      _peerIsPuffingNow = false;
      _peerName = tr("Searching...", "Поиск...");
      _peerDevice = "";
      _messages.clear();
    });

    await _updateMyLobbyPresence();
    await _subscribeToRoomChannel(_myShortCode);
    _broadcastRouletteSeek();
    _tryMatchFromLobbyPresence();
  }

  void _nextRoulettePeer() {
    HapticFeedback.lightImpact();
    if (_connectedPeerId != null) {
      _lastSkippedPeerId = _connectedPeerId;
      _lastSkipTime = DateTime.now();
    }
    _startRouletteSearch();
  }

  Future<void> _startLinkRoom(String roomCode) async {
    if (_battleActive) _stopBattle();
    await _closeCurrentRoomChannel(notifyLeave: true);

    final cleanCode = _extractShortCode(roomCode) ?? _myShortCode;

    if (!mounted) return;
    setState(() {
      _mode = LiveMode.link;
      _activeRoomCode = cleanCode;
      _isSearching = true;
      _isConnected = false;
      _connectedPeerId = null;
      _peerFrameBytes = null;
      _peerSessionPuffs = 0;
      _peerName = tr("Waiting for friend...", "Ждём друга...");
      _peerDevice = "puff.gg/$cleanCode";
      _messages.clear();
    });

    await _updateMyLobbyPresence();
    await _subscribeToRoomChannel(cleanCode);
  }

  Future<void> _subscribeToRoomChannel(String roomCode) async {
    final topicName = 'puff_room_live_$roomCode';
    if (_roomChannel != null && _subscribedRoomTopic == topicName) {
      _sendPeerHello();
      return;
    }

    await _closeCurrentRoomChannel(notifyLeave: false);

    try {
      final client = Supabase.instance.client;
      final channel = client.channel(
        topicName,
        opts: const RealtimeChannelConfig(self: false),
      );
      _subscribedRoomTopic = topicName;

      channel
          .onBroadcast(
            event: 'peer_hello',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (ComplianceService.isPeerBlocked(senderId)) return;

              _lastPeerHeartbeat = DateTime.now();
              final wasConnected = _isConnected && _connectedPeerId == senderId;

              setState(() {
                _isSearching = false;
                _isConnected = true;
                _connectedPeerId = senderId;
                _peerName = payload['username']?.toString() ?? tr('User', 'Смокер');
                _peerDevice = payload['device']?.toString() ?? '';
                _peerDeviceType = payload['deviceType']?.toString() ?? 'vape';
                _peerSessionPuffs =
                    int.tryParse(payload['puffs']?.toString() ?? '0') ?? _peerSessionPuffs;
              });

              if (!wasConnected) {
                HapticFeedback.mediumImpact();
                unawaited(_updateMyLobbyPresence());
                _sendPeerHello();
              }
            },
          )
          .onBroadcast(
            event: 'video_frame',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (ComplianceService.isPeerBlocked(senderId)) return;

              final b64 = payload['frame']?.toString();
              if (b64 == null || b64.isEmpty) return;

              try {
                final compressed = base64Decode(b64);
                final bmpBytes = Uint8List.fromList(zlib.decode(compressed));
                _lastPeerHeartbeat = DateTime.now();
                setState(() {
                  _isSearching = false;
                  _isConnected = true;
                  _connectedPeerId = senderId;
                  _peerFrameBytes = bmpBytes;
                });
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'puff_event',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (ComplianceService.isPeerBlocked(senderId)) return;

              _lastPeerHeartbeat = DateTime.now();
              setState(() {
                _peerIsPuffingNow = true;
                _peerSessionPuffs =
                    int.tryParse(payload['puffs']?.toString() ?? '') ?? (_peerSessionPuffs + 1);
                if (_battleActive) _peerBattlePuffs++;
              });
              _spawnFloatingReaction('💨', fromPeer: true);
              Future.delayed(const Duration(milliseconds: 1800), () {
                if (!mounted) return;
                setState(() => _peerIsPuffingNow = false);
              });
            },
          )
          .onBroadcast(
            event: 'chat_msg',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (ComplianceService.isPeerBlocked(senderId)) return;

              final text = payload['text']?.toString() ?? '';
              final sender = payload['username']?.toString() ?? _peerName;
              if (text.isEmpty) return;
              setState(() {
                _messages.add(_ChatMessage(sender: sender, text: text, isMe: false));
              });
            },
          )
          .onBroadcast(
            event: 'reaction',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (ComplianceService.isPeerBlocked(senderId)) return;

              final emoji = payload['emoji']?.toString() ?? '💨';
              _spawnFloatingReaction(emoji, fromPeer: true);
            },
          )
          .onBroadcast(
            event: 'battle_start',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;
              if (!_battleActive) _startBattleLocal(broadcast: false);
            },
          )
          .onBroadcast(
            event: 'peer_leave',
            callback: (rawPayload) {
              if (!mounted) return;
              final payload = _unwrapPayload(rawPayload);
              final senderId = payload['peerId']?.toString();
              if (senderId == null || senderId == _myPeerId) return;

              if (_mode == LiveMode.roulette) {
                _lastSkippedPeerId = senderId;
                _lastSkipTime = DateTime.now();
                _startRouletteSearch();
              } else {
                setState(() {
                  _peerFrameBytes = null;
                  _isConnected = false;
                  _connectedPeerId = null;
                  _isSearching = true;
                  _peerName = tr("Waiting for friend...", "Ждём друга...");
                });
              }
            },
          )
          .subscribe((status, _) {
            if (!mounted) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              _sendPeerHello();
            }
          });

      _roomChannel = channel;
    } catch (_) {}
  }

  void _sendPeerHello() {
    if (_roomChannel == null) return;
    try {
      final dev = DeviceService.activeDevice.value;
      _roomChannel!.sendBroadcastMessage(
        event: 'peer_hello',
        payload: {
          'peerId': _myPeerId,
          'username': _myUsername,
          'device': dev.name,
          'deviceType': dev.type,
          'puffs': _mySessionPuffs,
        },
      );
    } catch (_) {}
  }

  void _sendRoomHeartbeat() {
    if (_roomChannel != null && _isConnected) {
      _sendPeerHello();
    }
    if (_isConnected && _lastPeerHeartbeat != null) {
      final elapsed = DateTime.now().difference(_lastPeerHeartbeat!).inSeconds;
      if (elapsed > 10 && mounted) {
        if (_mode == LiveMode.roulette) {
          _startRouletteSearch();
        } else {
          setState(() {
            _peerFrameBytes = null;
            _isConnected = false;
            _isSearching = true;
            _peerName = tr("Waiting for friend...", "Ждём друга...");
          });
        }
      }
    }
  }

  // ===========================================================================
  // UGC REPORT & BLOCK DIALOG
  // ===========================================================================

  void _openReportBlockSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    final reasons = [
      tr("Inappropriate or explicit content", "Неприемлемый контент (18+)"),
      tr("Harassment or abusive behavior", "Оскорбления или агрессия"),
      tr("Underage user (< 18)", "Несовершеннолетний пользователь"),
      tr("Spam or unwanted behavior", "Спам или реклама"),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr("Report or Block User", "Пожаловаться / Заблокировать"),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  "Reporting or blocking will immediately disconnect this user and prevent future matching.",
                  "Жалоба или блокировка мгновенно отключит собеседника и скроет его из поиска.",
                ),
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
              const SizedBox(height: 12),
              ...reasons.map((reason) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _executeReportAndBlock(reason);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: textSecondary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _executeReportAndBlock("Blocked by user");
                  },
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: Text(
                    tr("Block & Skip Immediately", "Заблокировать и скипнуть"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeReportAndBlock(String reason) async {
    final targetId = _connectedPeerId ?? _peerName;
    await ComplianceService.blockAndReportPeer(targetId, reason);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _showToast(
      icon: Icons.shield_outlined,
      title: tr(
        "User reported & blocked. Skipping...",
        "Жалоба отправлена, пользователь заблокирован.",
      ),
    );
    _nextRoulettePeer();
  }

  // ===========================================================================
  // CAMERA & REAL-TIME FRAME ENCODER (80x100 ZLIB BMP)
  // ===========================================================================

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIdx == -1) _selectedCameraIdx = 0;
      await _startCameraAtIndex(_selectedCameraIdx);
    } catch (_) {}
  }

  Future<void> _startCameraAtIndex(int index) async {
    if (_cameras.isEmpty) return;
    final oldController = _cameraController;
    _cameraController = null;
    if (mounted) setState(() {});
    await oldController?.dispose();

    final cam = _cameras[index];
    final controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      await _detector.startAudioListening();
      _cameraController = controller;

      await controller.startImageStream((CameraImage image) async {
        if (!mounted || !_cameraEnabled) return;

        if (_isConnected && _roomChannel != null && !_isEncodingFrame) {
          final now = DateTime.now();
          if (now.difference(_lastFrameSentAt).inMilliseconds >= 230) {
            _lastFrameSentAt = now;
            _isEncodingFrame = true;
            _broadcastCameraFrame(image, cam);
          }
        }

        final puffDuration = await _detector.processCameraImage(
          image,
          cam,
          controller.value.deviceOrientation,
        );

        if (!mounted) return;
        if (_detector.isPuffing != _myIsPuffingNow) {
          setState(() {
            _myIsPuffingNow = _detector.isPuffing;
          });
        }

        if (puffDuration != null) {
          _registerLocalPuff(durationSeconds: puffDuration);
        }
      });

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.lightImpact();
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _startCameraAtIndex(_selectedCameraIdx);
  }

  void _broadcastCameraFrame(CameraImage image, CameraDescription cam) {
    try {
      final encoded = _encodeCameraImageToZlibBmp(
        image,
        cam.sensorOrientation,
        cam.lensDirection == CameraLensDirection.front,
      );
      if (encoded != null && _roomChannel != null) {
        _roomChannel!.sendBroadcastMessage(
          event: 'video_frame',
          payload: {
            'peerId': _myPeerId,
            'frame': encoded,
          },
        );
      }
    } catch (_) {
    } finally {
      _isEncodingFrame = false;
    }
  }

  String? _encodeCameraImageToZlibBmp(
    CameraImage image,
    int sensorOrientation,
    bool isFront,
  ) {
    if (image.planes.isEmpty) return null;

    const int outW = 80;
    const int outH = 100;
    const int pixelDataSize = outW * outH * 3;
    const int fileSize = 54 + pixelDataSize;

    final Uint8List bmp = Uint8List(fileSize);
    final ByteData bd = ByteData.sublistView(bmp);

    bmp[0] = 0x42;
    bmp[1] = 0x4D;
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint32(10, 54, Endian.little);
    bd.setUint32(14, 40, Endian.little);
    bd.setInt32(18, outW, Endian.little);
    bd.setInt32(22, outH, Endian.little);
    bd.setUint16(26, 1, Endian.little);
    bd.setUint16(28, 24, Endian.little);
    bd.setUint32(30, 0, Endian.little);
    bd.setUint32(34, pixelDataSize, Endian.little);

    final int srcW = image.width;
    final int srcH = image.height;
    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;
    final int yRowStride = yPlane.bytesPerRow;

    final bool has3Planes = image.planes.length >= 3;
    final Uint8List? uBytes = has3Planes ? image.planes[1].bytes : null;
    final Uint8List? vBytes = has3Planes ? image.planes[2].bytes : null;
    final int uvRowStride = has3Planes ? image.planes[1].bytesPerRow : 0;
    final int uvPixelStride = has3Planes ? (image.planes[1].bytesPerPixel ?? 1) : 1;

    int writeIdx = 54;

    for (int outY = outH - 1; outY >= 0; outY--) {
      final double ny = outY / outH;
      for (int outX = 0; outX < outW; outX++) {
        double nx = outX / outW;
        if (isFront) nx = 1.0 - nx;

        int sx;
        int sy;
        if (sensorOrientation == 270) {
          sx = ((1.0 - ny) * (srcW - 1)).toInt();
          sy = ((1.0 - nx) * (srcH - 1)).toInt();
        } else if (sensorOrientation == 90) {
          sx = (ny * (srcW - 1)).toInt();
          sy = (nx * (srcH - 1)).toInt();
        } else {
          sx = (nx * (srcW - 1)).toInt();
          sy = (ny * (srcH - 1)).toInt();
        }

        final int yIdx = sy * yRowStride + sx;
        final int yVal = (yIdx >= 0 && yIdx < yBytes.length) ? yBytes[yIdx] : 128;

        int uVal = 128;
        int vVal = 128;
        if (has3Planes && uBytes != null && vBytes != null) {
          final int uvIdx = (sy >> 1) * uvRowStride + (sx >> 1) * uvPixelStride;
          if (uvIdx >= 0 && uvIdx < uBytes.length && uvIdx < vBytes.length) {
            uVal = uBytes[uvIdx];
            vVal = vBytes[uvIdx];
          }
        } else if (image.planes.length == 1) {
          final int uvBase = srcH * yRowStride;
          final int uvIdx = uvBase + (sy >> 1) * yRowStride + (sx & ~1);
          if (uvIdx >= 0 && uvIdx + 1 < yBytes.length) {
            vVal = yBytes[uvIdx];
            uVal = yBytes[uvIdx + 1];
          }
        }

        final int c = yVal - 16;
        final int d = uVal - 128;
        final int e = vVal - 128;

        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        bmp[writeIdx++] = b & 0xF8;
        bmp[writeIdx++] = g & 0xF8;
        bmp[writeIdx++] = r & 0xF8;
      }
    }

    return base64Encode(zlib.encode(bmp));
  }

  // ===========================================================================
  // SHORT LINKS, PUFFS, BATTLE & CHAT
  // ===========================================================================

  String? _extractShortCode(String raw) {
    return DeepLinkService.extractRoomCode(raw, allowPlainCode: true);
  }

  void _copyMyShortLink() {
    DeepLinkService.markOwnCodeCopied(_activeRoomCode);
    final shareLink = "https://puff.gg/$_activeRoomCode";
    Clipboard.setData(ClipboardData(text: shareLink));
    HapticFeedback.mediumImpact();
    _showToast(
      icon: Icons.link_rounded,
      title: tr(
        "Copied invite link: puff.gg/$_activeRoomCode",
        "Ссылка скопирована: puff.gg/$_activeRoomCode",
      ),
    );
  }

  void _registerLocalPuff({double durationSeconds = 2.6}) {
    SoundService.playPuffSound();
    HapticFeedback.mediumImpact();

    setState(() {
      _mySessionPuffs++;
      _myIsPuffingNow = true;
      _dizzyProgress =
          (_dizzyProgress + ToleranceService.calculateDizzyIncrement(durationSeconds))
              .clamp(0.0, 1.0);
      if (_battleActive) _myBattlePuffs++;
    });

    final currentTotal = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
    AuthService.updatePuffs(currentTotal + 1);
    MascotService.evaluatePuff(
      durationSec: durationSeconds,
      dizzyProgress: _dizzyProgress,
    );

    _spawnFloatingReaction('💨', fromPeer: false);

    if (_roomChannel != null) {
      _roomChannel!.sendBroadcastMessage(
        event: 'puff_event',
        payload: {
          'peerId': _myPeerId,
          'username': _myUsername,
          'puffs': _mySessionPuffs,
        },
      );
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _myIsPuffingNow = false);
    });
  }

  void _startBattleLocal({bool broadcast = true}) {
    if (!_isConnected) return;
    HapticFeedback.mediumImpact();
    _battleTimer?.cancel();

    setState(() {
      _battleActive = true;
      _battleSecondsLeft = 60;
      _myBattlePuffs = 0;
      _peerBattlePuffs = 0;
    });

    if (broadcast && _roomChannel != null) {
      _roomChannel!.sendBroadcastMessage(
        event: 'battle_start',
        payload: {'peerId': _myPeerId},
      );
    }

    _battleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_battleSecondsLeft <= 1) {
        timer.cancel();
        _finishBattle();
      } else {
        setState(() => _battleSecondsLeft--);
      }
    });
  }

  void _stopBattle() {
    _battleTimer?.cancel();
    setState(() => _battleActive = false);
  }

  void _finishBattle() {
    setState(() => _battleActive = false);
    HapticFeedback.heavyImpact();
    if (_myBattlePuffs > _peerBattlePuffs) {
      MascotService.addPoints(150);
      _showToast(
        icon: Icons.emoji_events_rounded,
        title: tr("Battle Won! +150 ⚡", "Победа в баттле! +150 ⚡"),
      );
    } else if (_myBattlePuffs == _peerBattlePuffs) {
      MascotService.addPoints(50);
      _showToast(
        icon: Icons.handshake_rounded,
        title: tr("Draw! +50 ⚡", "Ничья! +50 ⚡"),
      );
    } else {
      _showToast(
        icon: Icons.cloud_queue_rounded,
        title: tr("$_peerName won the battle!", "$_peerName победил в баттле!"),
      );
    }
  }

  void _sendReaction(String emoji) {
    HapticFeedback.selectionClick();
    _spawnFloatingReaction(emoji, fromPeer: false);
    if (_roomChannel != null) {
      _roomChannel!.sendBroadcastMessage(
        event: 'reaction',
        payload: {'peerId': _myPeerId, 'emoji': emoji},
      );
    }
  }

  void _spawnFloatingReaction(String emoji, {required bool fromPeer}) {
    final id = ++_reactionSeq;
    final startX = 0.72 + Random().nextDouble() * 0.2;
    setState(() {
      _reactions.add(_FloatingReaction(id: id, emoji: emoji, startX: startX, fromPeer: fromPeer));
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _reactions.removeWhere((r) => r.id == id));
    });
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() {
      _messages.add(_ChatMessage(sender: _myUsername, text: text, isMe: true));
    });

    if (_roomChannel != null) {
      _roomChannel!.sendBroadcastMessage(
        event: 'chat_msg',
        payload: {'peerId': _myPeerId, 'username': _myUsername, 'text': text},
      );
    }
  }

  void _openLinkSheet() {
    _joinCodeController.clear();
    DeepLinkService.checkClipboardForInvite(currentActiveCode: _activeRoomCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final primaryColor = ThemeService.primaryColor;
    final onPrimary = ThemeService.onPrimaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: DeepLinkService.clipboardRoomInvite,
                  builder: (context, clipCode, _) {
                    if (clipCode == null || clipCode.isEmpty || clipCode == _activeRoomCode) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          DeepLinkService.dismissClipboardInvite(clipCode);
                          Navigator.pop(ctx);
                          _startLinkRoom(clipCode);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: ThemeService.accentLight(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.content_paste_go_rounded, color: primaryColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr(
                                    "Join from clipboard: puff.gg/$clipCode",
                                    "Войти из буфера: puff.gg/$clipCode",
                                  ),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, color: primaryColor, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "puff.gg/$_activeRoomCode",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _copyMyShortLink();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          tr("Copy", "Копировать"),
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _joinCodeController,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: tr("Friend's code or link (e.g. 482)", "Код или ссылка друга (напр. 482)"),
                          hintStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.normal),
                          filled: true,
                          fillColor: cardBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final code = _extractShortCode(_joinCodeController.text);
                        if (code != null) {
                          Navigator.pop(ctx);
                          _startLinkRoom(code);
                        }
                      },
                      child: Text(
                        tr("Join", "Войти"),
                        style: TextStyle(fontWeight: FontWeight.bold, color: onPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToast({required IconData icon, required String title}) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DelightToastBar(
      position: DelightSnackbarPosition.top,
      autoDismiss: true,
      snackbarDuration: const Duration(seconds: 2),
      builder: (context) => ToastCard(
        color: ThemeService.cardColor(isDark),
        leading: Icon(icon, color: ThemeService.primaryColor, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: ThemeService.textPrimary(isDark),
          ),
        ),
      ),
    ).show(context);
  }

  // ===========================================================================
  // PRE-ENTRY COMMUNITY RULES SCREEN (UGC COMPLIANCE)
  // ===========================================================================

  Widget _buildLiveTermsGate(Color primaryColor, Color onPrimary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr("Live Community Rules", "Правила прямого эфира"),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr("Safe 18+ Co-Session Policy", "Безопасный эфир 18+"),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        "Before joining Live Roulette or a Split-Screen room, please review and accept our zero-tolerance community guidelines:\n\n"
                        "• Adults Only (18+): No minors are permitted in Live sessions.\n"
                        "• Respect Others: Zero tolerance for harassment, hate speech, threats, or bullying.\n"
                        "• Appropriate Content: No nudity, sexually explicit content, or illegal acts.\n"
                        "• Instant Moderation: Use the Flag (Report / Block) button at the top of the screen at any time to report and permanently block offending users.",
                        "Перед входом в Рулетку или Сплит-эфир ознакомьтесь с правилами сообщества:\n\n"
                        "• Строго 18+: Несовершеннолетним вход запрещён.\n"
                        "• Уважение: Запрещены оскорбления, агрессия и буллинг.\n"
                        "• Приемлемый контент: Запрещены обнажёнка, насилие и запрещённый контент.\n"
                        "• Модерация в 1 клик: Используйте кнопку Флажка (Пожаловаться / Заблокировать) сверху экрана, чтобы мгновенно заблокировать и скипнуть нарушителя.",
                      ),
                      style: TextStyle(fontSize: 14, color: textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: LegalDocType.terms),
                    ),
                  );
                },
                icon: Icon(Icons.open_in_new_rounded, size: 16, color: primaryColor),
                label: Text(
                  tr("Read full Terms & UGC Policy (puff.gg)", "Читать полные условия (puff.gg)"),
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await ComplianceService.setLiveTermsAccepted();
                    if (!mounted) return;
                    setState(() {
                      _rulesAccepted = true;
                    });
                    _startLiveServices();
                  },
                  child: Text(
                    tr("I Agree & Enter Live", "Согласен, войти в эфир"),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MINIMALIST TIKTOK LIVE FULL-SCREEN UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.primaryColor;
    final onPrimary = ThemeService.onPrimaryColor;

    if (!_rulesAccepted) {
      return _buildLiveTermsGate(primaryColor, onPrimary);
    }

    final int myScore = _battleActive ? _myBattlePuffs : _mySessionPuffs;
    final int peerScore = _battleActive ? _peerBattlePuffs : _peerSessionPuffs;
    final int totalScore = myScore + peerScore;
    final double myRatio = totalScore == 0 ? 0.5 : (myScore / totalScore).clamp(0.15, 0.85);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. EDGE-TO-EDGE 50/50 SPLIT VIDEO CANVAS
          Column(
            children: [
              // TOP 50%: REAL PEER VIDEO
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isSearching || !_isConnected)
                      _buildMinimalSearching(primaryColor)
                    else if (_peerFrameBytes != null)
                      Image.memory(
                        _peerFrameBytes!,
                        gaplessPlayback: true,
                        fit: BoxFit.cover,
                      )
                    else
                      _buildConnectedNoVideoFeed(primaryColor),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 85,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.65),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_peerIsPuffingNow)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        child: _buildGlassPill(
                          color: Colors.greenAccent.withValues(alpha: 0.25),
                          child: Text(
                            tr("💨 Drawing...", "💨 Затягивается..."),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // THIN 3PX TIKTOK PK RATIO BAR BETWEEN CAMERAS
              SizedBox(
                height: 3,
                child: Row(
                  children: [
                    Expanded(
                      flex: (myRatio * 100).round(),
                      child: Container(color: primaryColor),
                    ),
                    Expanded(
                      flex: ((1.0 - myRatio) * 100).round(),
                      child: Container(color: Colors.cyanAccent),
                    ),
                  ],
                ),
              ),

              // BOTTOM 50%: MY CAMERA
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cameraEnabled &&
                        _cameraController != null &&
                        _cameraController!.value.isInitialized)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height,
                            height: _cameraController!.value.previewSize!.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    else
                      const ColoredBox(
                        color: Color(0xFF121212),
                        child: Center(
                          child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 32),
                        ),
                      ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. CENTER SEAM FLOATING CONTROLS (TikTok PK Score + Next button)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_battleActive) {
                        _stopBattle();
                      } else {
                        _startBattleLocal(broadcast: true);
                      }
                    },
                    child: _buildGlassPill(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: _battleActive
                          ? Colors.deepOrange.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.55),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$myScore",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              _battleActive ? "⚔️ ${_battleSecondsLeft}s" : "VS",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          Text(
                            "$peerScore",
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_mode == LiveMode.roulette)
                    GestureDetector(
                      onTap: _nextRoulettePeer,
                      child: _buildGlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr("Next", "Дальше"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _openLinkSheet,
                      child: _buildGlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, color: primaryColor, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              "puff.gg/$_activeRoomCode",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. TOP TIKTOK LIVE HEADER OVERLAY (WITH REPORT / BLOCK BUTTON)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _buildGlassPill(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 105),
                            child: Text(
                              _isConnected
                                  ? _peerName
                                  : tr("Online: $_onlineInLiveCount", "В эфире: $_onlineInLiveCount"),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (_isConnected) ...[
                            const SizedBox(width: 5),
                            Text(
                              "• $_peerSessionPuffs💨",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Report / Block Button directly on the video chat screen
                    GestureDetector(
                      onTap: _openReportBlockSheet,
                      child: _buildGlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        color: Colors.redAccent.withValues(alpha: 0.32),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_outlined, color: Colors.white, size: 15),
                            const SizedBox(width: 3),
                            Text(
                              tr("Report", "Жалоба"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    _buildGlassPill(
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniTab(
                            title: tr("Roulette", "Рулетка"),
                            active: _mode == LiveMode.roulette,
                            primaryColor: primaryColor,
                            onPrimary: onPrimary,
                            onTap: () {
                              if (_mode != LiveMode.roulette) _startRouletteSearch();
                            },
                          ),
                          _buildMiniTab(
                            title: tr("Link", "Ссылка"),
                            active: _mode == LiveMode.link,
                            primaryColor: primaryColor,
                            onPrimary: onPrimary,
                            onTap: () {
                              if (_mode != LiveMode.link) {
                                _startLinkRoom(_myShortCode);
                              } else {
                                _openLinkSheet();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: _buildGlassPill(
                        padding: const EdgeInsets.all(7),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. FLOATING REACTIONS
          ..._reactions.map((r) => _buildFloatingEmojiWidget(r)),

          // 5. BOTTOM TIKTOK LIVE CHAT & ACTION CONTROLS
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_messages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, right: 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _messages
                              .skip(max(0, _messages.length - 3))
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        shadows: [
                                          Shadow(color: Colors.black87, blurRadius: 4),
                                        ],
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "${m.sender}  ",
                                          style: TextStyle(
                                            color: m.isMe ? primaryColor : Colors.white70,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        TextSpan(
                                          text: m.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TextField(
                              controller: _chatController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendChatMessage(),
                              decoration: InputDecoration(
                                hintText: tr("Add comment...", "Комментарий..."),
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        GestureDetector(
                          onTap: () => _registerLocalPuff(durationSeconds: 2.8),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "+💨 $_mySessionPuffs",
                              style: TextStyle(
                                color: onPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        _buildCircleIconButton(
                          child: const Text("🔥", style: TextStyle(fontSize: 16)),
                          onTap: () => _sendReaction('🔥'),
                        ),
                        const SizedBox(width: 6),

                        _buildCircleIconButton(
                          child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 18),
                          onTap: _flipCamera,
                        ),
                        const SizedBox(width: 6),

                        _buildCircleIconButton(
                          child: Icon(
                            _cameraEnabled ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                            color: _cameraEnabled ? Colors.white : Colors.redAccent,
                            size: 18,
                          ),
                          onTap: () => setState(() => _cameraEnabled = !_cameraEnabled),
                        ),
                      ],
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

  Widget _buildGlassPill({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    Color? color,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: child,
    );
  }

  Widget _buildMiniTab({
    required String title,
    required bool active,
    required Color primaryColor,
    required Color onPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? onPrimary : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      ),
    );
  }

  Widget _buildMinimalSearching(Color primaryColor) {
    return ColoredBox(
      color: const Color(0xFF0E0E0E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: primaryColor),
            ),
            const SizedBox(height: 10),
            Text(
              _mode == LiveMode.roulette
                  ? tr("Searching for live partner...", "Ищем кто в эфире...")
                  : "puff.gg/$_activeRoomCode",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_mode == LiveMode.roulette) ...[
              const SizedBox(height: 4),
              Text(
                tr("Currently in Live: $_onlineInLiveCount", "Сейчас в эфире: $_onlineInLiveCount"),
                style: const TextStyle(color: Colors.white38, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedNoVideoFeed(Color primaryColor) {
    return AnimatedBuilder(
      animation: _pulseAnimController,
      builder: (context, _) {
        final t = _pulseAnimController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.75 + t * 0.2,
              colors: [
                primaryColor.withValues(alpha: 0.25),
                const Color(0xFF0E0E0E),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _peerIsPuffingNow ? Colors.greenAccent : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _peerDeviceType == 'hookah' ? Icons.cloud_rounded : Icons.vape_free,
                    size: 32,
                    color: _peerIsPuffingNow ? Colors.greenAccent : Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_peerDevice.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _peerDevice,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingEmojiWidget(_FloatingReaction r) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(r.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1700),
      builder: (context, value, _) {
        final yAlign = r.fromPeer ? (-0.2 - value * 0.5) : (0.75 - value * 0.9);
        final opacity = (1.0 - (value - 0.6).clamp(0.0, 0.4) / 0.4).clamp(0.0, 1.0);
        return Align(
          alignment: Alignment(r.startX * 2 - 1, yAlign),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.8 + sin(value * pi) * 0.35,
              child: Text(r.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        );
      },
    );
  }
}
