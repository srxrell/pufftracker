import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.pufftrack.app/deeplink');

  /// Fires when the OS opens the app via a deep link (`puff://room/482` or `https://puff.gg/482`).
  static final ValueNotifier<String?> pendingRoomCode = ValueNotifier<String?>(null);

  /// Fires when a friend's invite link (`puff.gg/482` or `puff://room/482`) is detected in the clipboard.
  static final ValueNotifier<String?> clipboardRoomInvite = ValueNotifier<String?>(null);

  static String? _lastCopiedOwnCode;
  static String? _lastDismissedClipboardCode;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final rawLink = call.arguments?.toString();
        _handleIncomingLink(rawLink);
      }
    });

    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        _handleIncomingLink(initialLink);
      }
    } catch (_) {}

    await checkClipboardForInvite();
  }

  static void _handleIncomingLink(String? rawLink) {
    if (rawLink == null || rawLink.isEmpty) return;
    final code = extractRoomCode(rawLink, allowPlainCode: false);
    if (code != null) {
      pendingRoomCode.value = code;
    }
  }

  /// Extracts a room code (e.g. `482` or `482-910`) from a link or text.
  /// When [allowPlainCode] is false, requires a prefix like `puff.gg/`, `puff://`, `room=`, or `room/`.
  static String? extractRoomCode(String? raw, {bool allowPlainCode = true}) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final linkRegex = RegExp(
      r'(?:puff\.gg/|pufftrack://(?:room/)?|puff://(?:room/)?|room[=/]|#)([a-zA-Z0-9]{3,6})\b',
      caseSensitive: false,
    );
    final linkMatch = linkRegex.firstMatch(trimmed);
    if (linkMatch != null) {
      return linkMatch.group(1)!.toUpperCase();
    }

    if (allowPlainCode) {
      final plainRegex = RegExp(r'^[a-zA-Z0-9]{3,6}$');
      if (plainRegex.hasMatch(trimmed)) {
        return trimmed.toUpperCase();
      }
    }
    return null;
  }

  static void markOwnCodeCopied(String code) {
    _lastCopiedOwnCode = code.toUpperCase();
    if (clipboardRoomInvite.value == _lastCopiedOwnCode) {
      clipboardRoomInvite.value = null;
    }
  }

  static void dismissClipboardInvite(String code) {
    _lastDismissedClipboardCode = code.toUpperCase();
    if (clipboardRoomInvite.value == _lastDismissedClipboardCode) {
      clipboardRoomInvite.value = null;
    }
  }

  static String? consumePendingRoomCode() {
    final code = pendingRoomCode.value;
    pendingRoomCode.value = null;
    return code;
  }

  static Future<void> checkClipboardForInvite({String? currentActiveCode}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;

      final code = extractRoomCode(text, allowPlainCode: false);
      if (code == null) return;

      if (code == _lastCopiedOwnCode ||
          code == _lastDismissedClipboardCode ||
          (currentActiveCode != null && code == currentActiveCode.toUpperCase())) {
        return;
      }

      clipboardRoomInvite.value = code;
    } catch (_) {}
  }
}
