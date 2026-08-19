import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/agora_service.dart';

class CallScreen extends StatefulWidget {
  final String partnerName;
  final String partnerPhotoUrl;
  final String partnerRole; // 'Space Owner' | 'Customer (Seeker)'
  final String subtitle; // e.g. Space name or Vehicle details
  final String phone;
  final bool isIncoming;

  const CallScreen({
    super.key,
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

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  int _callSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAgoraAudioCall();
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
    _pulseController.dispose();
    _timer?.cancel();
    AgoraService.leaveChannel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.partnerName.isNotEmpty
        ? widget.partnerName.trim().substring(0, 1).toUpperCase()
        : 'P';

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
                        // Avatar with animated pulse rings
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Pulse Ring
                                Container(
                                  width: 170 + (_pulseController.value * 22),
                                  height: 170 + (_pulseController.value * 22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_isCallConnected ? AppColors.greenSuccess : AppColors.primary)
                                        .withOpacity(0.18 - (_pulseController.value * 0.12)),
                                  ),
                                ),
                                // Mid Pulse Ring
                                Container(
                                  width: 150 + (_pulseController.value * 12),
                                  height: 150 + (_pulseController.value * 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (_isCallConnected ? AppColors.greenSuccess : AppColors.primary)
                                        .withOpacity(0.30 - (_pulseController.value * 0.15)),
                                  ),
                                ),
                                // Avatar Circle (Real Initial / Custom Photo)
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _isCallConnected ? AppColors.greenSuccess : Colors.white,
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
                                    child: widget.partnerPhotoUrl.isNotEmpty
                                        ? Image.network(
                                            widget.partnerPhotoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
                                          )
                                        : _buildInitialAvatar(initial),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Partner Name (Real Space Owner / Real Seeker Driver)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            widget.partnerName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Role Badge (e.g. Space Owner / Customer Seeker)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.partnerRole.contains('Owner') ? Icons.verified_user : Icons.directions_car,
                                color: const Color(0xFFA78BFA),
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.partnerRole,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subtitle Details (e.g. Space Address / Vehicle Model)
                        if (widget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Status Subtitle (Calling / Ringing vs Connected)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCallConnected ? Icons.lock_outline : Icons.ring_volume,
                              size: 14,
                              color: _isCallConnected ? Colors.white70 : const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isCallConnected
                                  ? 'End-to-End Encrypted HD Call'
                                  : (widget.isIncoming ? 'Incoming Voice Call...' : 'Ringing...'),
                              style: TextStyle(
                                color: _isCallConnected ? Colors.white70 : const Color(0xFFFBBF24),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Timer Badge: Displayed ONLY when other person has joined and call is connected
                        if (_isCallConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.greenSuccess,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_callSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Waiting state badge (No Timer)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Waiting for person to answer...',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
