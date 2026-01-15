import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  // Sample data for last 7 weeks
  final List<WeeklyActivity> _weeklyData = [
    WeeklyActivity(week: 'Hafta 1', earnings: 1250000, distance: 145, clients: 38),
    WeeklyActivity(week: 'Hafta 2', earnings: 1580000, distance: 178, clients: 45),
    WeeklyActivity(week: 'Hafta 3', earnings: 1420000, distance: 162, clients: 41),
    WeeklyActivity(week: 'Hafta 4', earnings: 1680000, distance: 195, clients: 48),
    WeeklyActivity(week: 'Hafta 5', earnings: 1520000, distance: 172, clients: 43),
    WeeklyActivity(week: 'Hafta 6', earnings: 1750000, distance: 201, clients: 52),
    WeeklyActivity(week: 'Hafta 7', earnings: 1890000, distance: 218, clients: 56),
  ];

  int _selectedIndex = 6; // Current week selected by default

  @override
  Widget build(BuildContext context) {
    final selectedWeek = _weeklyData[_selectedIndex];
    final totalEarnings = _weeklyData.fold<int>(0, (sum, week) => sum + week.earnings);
    final totalDistance = _weeklyData.fold<int>(0, (sum, week) => sum + week.distance);
    final totalClients = _weeklyData.fold<int>(0, (sum, week) => sum + week.clients);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Aktivligim',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.attach_money,
                    title: 'Jami daromad',
                    value: '${(totalEarnings / 1000).toStringAsFixed(0)}K',
                    subtitle: 'so\'m',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.route,
                    title: 'Jami masofa',
                    value: '$totalDistance',
                    subtitle: 'km',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              icon: Icons.people,
              title: 'Jami clientlar',
              value: '$totalClients',
              subtitle: 'ta mijoz',
              color: Colors.orange,
            ),

            const SizedBox(height: 30),

            // Weekly Chart
            const Text(
              'Haftalik statistika',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 2000000,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            if (response != null && response.spot != null) {
                              setState(() {
                                _selectedIndex = response.spot!.touchedBarGroupIndex;
                              });
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _weeklyData.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'H${value.toInt() + 1}',
                                      style: TextStyle(
                                        color: _selectedIndex == value.toInt()
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: _selectedIndex == value.toInt()
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value / 1000000).toStringAsFixed(1)}M',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 500000,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200],
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: _weeklyData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.earnings.toDouble(),
                                color: _selectedIndex == entry.key
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.3),
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Selected week details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailItem(
                        icon: Icons.calendar_today,
                        label: selectedWeek.week,
                        color: AppColors.primary,
                      ),
                      _buildDetailItem(
                        icon: Icons.attach_money,
                        label: '${(selectedWeek.earnings / 1000).toStringAsFixed(0)}K',
                        color: Colors.green,
                      ),
                      _buildDetailItem(
                        icon: Icons.route,
                        label: '${selectedWeek.distance} km',
                        color: Colors.blue,
                      ),
                      _buildDetailItem(
                        icon: Icons.people,
                        label: '${selectedWeek.clients} ta',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Detailed breakdown
            const Text(
              'Batafsil ma\'lumot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            ..._weeklyData.reversed.map((week) => _buildWeekCard(week)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekCard(WeeklyActivity week) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  week.week,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildWeekStat(Icons.attach_money, '${(week.earnings / 1000).toStringAsFixed(0)}K', Colors.green),
                    const SizedBox(width: 16),
                    _buildWeekStat(Icons.route, '${week.distance}km', Colors.blue),
                    const SizedBox(width: 16),
                    _buildWeekStat(Icons.people, '${week.clients}', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class WeeklyActivity {
  final String week;
  final int earnings;
  final int distance;
  final int clients;

  WeeklyActivity({
    required this.week,
    required this.earnings,
    required this.distance,
    required this.clients,
  });
}
