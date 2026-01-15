import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

class OrderInProgressWidget extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onOpenMaps;
  final VoidCallback onCancel;
  final String? clientPhone;
  final int currentPrice;
  final double traveledDistance;
  final int waitingSeconds;
  final bool isWaitingForClient;

  const OrderInProgressWidget({
    super.key,
    required this.onComplete,
    required this.onOpenMaps,
    required this.onCancel,
    this.clientPhone,
    this.currentPrice = 0,
    this.traveledDistance = 0,
    this.waitingSeconds = 0,
    this.isWaitingForClient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Status header
          Row(
            children: [
              Icon(
                isWaitingForClient ? Icons.hourglass_empty : Icons.directions_car,
                color: AppColors.orderActive,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isWaitingForClient ? 'Kutilmoqda' : 'Yo\'lda',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Price and distance info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.attach_money,
                  label: 'Narx',
                  value: '$currentPrice so\'m',
                  color: AppColors.orderActive,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.divider,
                ),
                _buildInfoItem(
                  icon: Icons.route,
                  label: 'Masofa',
                  value: '${traveledDistance.toStringAsFixed(2)} km',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          
          // Waiting time (if waiting for client)
          if (isWaitingForClient) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: waitingSeconds > 120 
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: waitingSeconds > 120 
                      ? Colors.orange
                      : Colors.green,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: waitingSeconds > 120 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kutish vaqti: ${_formatWaitingTime(waitingSeconds)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: waitingSeconds > 120 
                                ? Colors.orange[900]
                                : Colors.green[900],
                          ),
                        ),
                        if (waitingSeconds <= 120)
                          Text(
                            '${120 - waitingSeconds}s bepul qoldi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          )
                        else
                          Text(
                            'Hisoblanyapti: 1500 so\'m/daqiqa',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              // Call button
              if (clientPhone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(clientPhone!),
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('Qo\'ng\'iroq'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (clientPhone != null) const SizedBox(width: 12),
              
              // Maps button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMaps,
                  icon: const Icon(Icons.map, size: 20),
                  label: const Text('Xarita'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Cancel button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Bekor'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Complete button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Tugatish'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatWaitingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
