import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/agora_service.dart';
import '../../core/services/firebase_rtdb_service.dart';

class CallScreen extends StatefulWidget {
  final String? partnerId;
  final String partnerName;
  final String partnerPhotoUrl;
  final String partnerRole; // 'Space Owner' | 'Customer (Seeker)'
  final String subtitle; // e.g. Space name or Vehicle details
  final String phone;
  final bool isIncoming;

  const CallScreen({
    super.key,
    this.partnerId,
    required this.partnerName,
    this.partnerPhotoUrl = '',
    this.partnerRole = 'Space Owner',
    this.subtitle = '',
    this.phone = '',
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  int _callSeconds = 0;
  Timer? _timer;
  late String _resolvedName;
  late String _resolvedPhoto;

  @override
  void initState() {
    super.initState();
    _resolvedName = widget.partnerName;
    _resolvedPhoto = widget.partnerPhotoUrl;

    _initAgoraAudioCall();
    _fetchProfileIfAvailable();
  }

  Future<void> _fetchProfileIfAvailable() async {
    final id = widget.partnerId;
    if (id == null || id.isEmpty) return;

    try {
      final profile = await FirebaseRtdbService.getUserProfile(id);
      if (profile != null && mounted) {
        setState(() {
          final pName = (profile['name'] ?? '').toString().trim();
          if (pName.isNotEmpty && (_resolvedName.isEmpty || _resolvedName.startsWith('Customer (') || _resolvedName.startsWith('Driver (') || _resolvedName.startsWith('Space Owner ('))) {
            _resolvedName = pName;
          }
          final pPhoto = (profile['photoUrl'] ?? '').toString().trim();
          if (pPhoto.isNotEmpty) {
            _resolvedPhoto = pPhoto;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initAgoraAudioCall() async {
    await AgoraService.joinChannel(
      channelId: 'meeparking_voice_channel',
      uid: 1001,
      onUserJoined: (remoteUid) {
        if (mounted) {
          _acceptAndConnectCall();
        }
      },
      onUserOffline: (remoteUid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call ended.')),
          );
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _acceptAndConnectCall() {
    if (_isCallConnected) return;
    setState(() {
      _isCallConnected = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    AgoraService.leaveChannel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get _vehicleInfo {
    if (widget.subtitle.isEmpty) return '';
    final parts = widget.subtitle.split('•').map((s) => s.trim()).toList();
    // Filter out pass / subscription / order tokens
    final cleanParts = parts.where((p) {
      final lower = p.toLowerCase();
      return !lower.contains('pass') &&
          !lower.contains('order') &&
          !lower.contains('booking') &&
          !lower.contains('days');
    }).toList();
    if (cleanParts.isNotEmpty) {
      return cleanParts.join(' • ');
    }
    return widget.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _resolvedName.isNotEmpty
        ? _resolvedName.trim().substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.splashGradient,
            ),
          ),

          // Main Center Content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 70, bottom: 120),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Fixed Static Profile Avatar (No animations/pulsing)
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: _isCallConnected ? AppColors.greenSuccess : Colors.white24,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _resolvedPhoto.isNotEmpty
                                ? Image.network(
                                    _resolvedPhoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
                                  )
                                : _buildInitialAvatar(initial),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _resolvedName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Vehicle Info
                        if (_vehicleInfo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Text(
                              _vehicleInfo,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Time / Duration Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isCallConnected ? AppColors.greenSuccess : const Color(0xFFFBBF24),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isCallConnected
                                    ? _formatDuration(_callSeconds)
                                    : (widget.isIncoming ? 'Incoming...' : 'Calling...'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
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
            ),
          ),

          // Top Header Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Text(
                      widget.isIncoming ? 'Incoming Call' : 'Voice Call',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Call Controls Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B132C).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: widget.isIncoming && !_isCallConnected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline Call Button
                          _buildCallControlButton(
                            icon: Icons.call_end,
                            color: AppColors.redError,
                            iconColor: Colors.white,
                            label: 'Decline',
                            size: 60,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          // Accept Call Button
                          _buildCallControlButton(
                            icon: Icons.call,
                            color: AppColors.greenSuccess,
                            iconColor: Colors.white,
                            label: 'Accept & Join',
                            size: 60,
                            onTap: _acceptAndConnectCall,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute Mic Button
                          _buildCallControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            color: _isMuted
                                ? AppColors.redError
                                : Colors.white.withOpacity(0.15),
                            iconColor: Colors.white,
                            label: _isMuted ? 'Muted' : 'Mute',
                            onTap: () => setState(() => _isMuted = !_isMuted),
                          ),

                          // End Call Button
                          _buildCallControlButton(
                            icon: Icons.call_end,
                            color: AppColors.redError,
                            iconColor: Colors.white,
                            label: 'End',
                            size: 60,
                            onTap: () => Navigator.of(context).pop(),
                          ),

                          // Speaker Button
                          _buildCallControlButton(
                            icon: _isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                            color: _isSpeakerOn
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.15),
                            iconColor: Colors.white,
                            label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                            onTap: () =>
                                setState(() => _isSpeakerOn = !_isSpeakerOn),
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

  Widget _buildInitialAvatar(String initial) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildCallControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.46),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
