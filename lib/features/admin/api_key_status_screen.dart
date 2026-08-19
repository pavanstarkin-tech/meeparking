import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_status_service.dart';

class ApiKeyStatusScreen extends StatefulWidget {
  const ApiKeyStatusScreen({super.key});

  @override
  State<ApiKeyStatusScreen> createState() => _ApiKeyStatusScreenState();
}

class _ApiKeyStatusScreenState extends State<ApiKeyStatusScreen> {
  List<ApiKeyStatus> _keyStatuses = [];
  bool _isInitialLoading = true;
  bool _isVerifyingAll = false;

  @override
  void initState() {
    super.initState();
    _loadAndVerifyKeys();
  }

  Future<void> _loadAndVerifyKeys() async {
    setState(() {
      _isInitialLoading = true;
      _isVerifyingAll = true;
    });

    final list = await ApiStatusService.checkAllApiKeys();
    setState(() {
      _keyStatuses = list;
      _isInitialLoading = false;
    });

    // Run verification concurrently for each key
    await Future.wait(_keyStatuses.map((item) async {
      final updated = await ApiStatusService.verifySingleKey(item);
      if (mounted) {
        setState(() {
          final index = _keyStatuses.indexWhere((element) => element.keyName == item.keyName);
          if (index != -1) {
            _keyStatuses[index] = updated;
          }
        });
      }
    }));

    if (mounted) {
      setState(() {
        _isVerifyingAll = false;
      });
    }
  }

  Future<void> _verifySingle(int index) async {
    setState(() {
      _keyStatuses[index].isLoading = true;
    });
    final updated = await ApiStatusService.verifySingleKey(_keyStatuses[index]);
    if (mounted) {
      setState(() {
        _keyStatuses[index] = updated;
      });
    }
  }

  String _maskKey(String key) {
    if (key.isEmpty) return 'Not set in .env';
    if (key.length <= 8) return '••••${key.substring(key.length ~/ 2)}';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _keyStatuses.where((k) => k.isValid == true).length;
    final invalidCount = _keyStatuses.where((k) => k.isValid == false).length;
    final pendingCount = _keyStatuses.where((k) => k.isValid == null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'API Keys Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Recheck All Keys',
            onPressed: _isVerifyingAll ? null : _loadAndVerifyKeys,
          ),
        ],
      ),
      body: _isInitialLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading Environment Keys...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAndVerifyKeys,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Banner Card
                    _buildSummaryCard(validCount, invalidCount, pendingCount),

                    const SizedBox(height: 20),

                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Environment Keys Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Excludes SMTP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Keys List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _keyStatuses.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _keyStatuses[index];
                        return _buildKeyStatusTile(item, index);
                      },
                    ),

                    const SizedBox(height: 24),

                    // SMTP Excluded Note Card
                    _buildSmtpExcludedNote(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(int valid, int invalid, int pending) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment Diagnostics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time API key verification',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('Working', '$valid', Colors.greenAccent),
              _buildDivider(),
              _buildStatItem('Failed', '$invalid', Colors.redAccent),
              _buildDivider(),
              _buildStatItem('Testing', '$pending', Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildKeyStatusTile(ApiKeyStatus item, int index) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (item.isLoading) {
      statusColor = Colors.orange;
      statusIcon = Icons.sync;
      statusText = 'Verifying...';
    } else if (item.isValid == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Working';
    } else if (item.isValid == false) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Failed';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help;
      statusText = 'Pending';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isValid == false
              ? Colors.red.shade200
              : item.isValid == true
                  ? Colors.green.shade200
                  : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: item.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: statusColor,
                          ),
                        )
                      : Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        item.keyName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.key, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _maskKey(item.keyValue),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Re-test Key',
                  onPressed: item.isLoading ? null : () => _verifySingle(index),
                ),
              ],
            ),
            if (item.message != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.message!,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmtpExcludedNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMTP Config Excluded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SMTP keys (SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD) have been excluded from this automatic checker as requested.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
