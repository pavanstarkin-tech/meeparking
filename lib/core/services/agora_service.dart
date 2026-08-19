import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/env_config.dart';

class AgoraService {
  static RtcEngine? _engine;
  static bool _isInitialized = false;
  static Function(int remoteUid)? onUserJoinedCallback;
  static Function(int remoteUid)? onUserOfflineCallback;

  /// Initialize real Agora RTC Audio Engine (strictly Audio-only, NO Camera)
  static Future<RtcEngine?> initEngine({
    Function(int remoteUid)? onUserJoined,
    Function(int remoteUid)? onUserOffline,
  }) async {
    onUserJoinedCallback = onUserJoined;
    onUserOfflineCallback = onUserOffline;

    if (_isInitialized && _engine != null) {
      _registerEventHandlers();
      return _engine;
    }

    try {
      if (!kIsWeb) {
        // Only request microphone permission for audio voice calling — NEVER camera
        await Permission.microphone.request();
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: EnvConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _registerEventHandlers();

      // Audio only setup
      await _engine!.disableVideo();
      await _engine!.enableAudio();
      _isInitialized = true;
      return _engine;
    } catch (e) {
      debugPrint('Agora init engine error: $e');
    }
    return _engine;
  }

  static void _registerEventHandlers() {
    if (_engine == null) return;
    try {
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('Agora remote user joined: $remoteUid');
            onUserJoinedCallback?.call(remoteUid);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('Agora remote user offline: $remoteUid');
            onUserOfflineCallback?.call(remoteUid);
          },
        ),
      );
    } catch (_) {}
  }

  /// Join audio voice call channel (Camera strictly disabled)
  static Future<void> joinChannel({
    required String channelId,
    required int uid,
    String? token,
    Function(int remoteUid)? onUserJoined,
    Function(int remoteUid)? onUserOffline,
  }) async {
    final engine = await initEngine(
      onUserJoined: onUserJoined,
      onUserOffline: onUserOffline,
    );
    if (engine == null) return;
    try {
      await engine.joinChannel(
        token: token ?? '',
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
          autoSubscribeVideo: false,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint('Agora join channel error: $e');
    }
  }

  /// Leave call channel
  static Future<void> leaveChannel() async {
    onUserJoinedCallback = null;
    onUserOfflineCallback = null;
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
    }
  }
}
