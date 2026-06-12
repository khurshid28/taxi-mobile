import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/storage_helper.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Real ma'lumot: qurilmada saqlangan tugatilgan safarlardan
  // (completed_orders) hisoblanadi. Hech qanday namuna/sun'iy data yo'q.
  List<MonthlyActivity> _monthlyData = [];
  List<DailyActivity> _dailyData = [];
  bool _loading = true;
  bool _hasTrips = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivity();
  }

  /// Tugatilgan safarlarni (completed_orders) o'qib, kunlik (oxirgi 7 kun)
  /// va oylik (joriy yil) statistikani hisoblaydi.
  Future<void> _loadActivity() async {
    final raw = await StorageHelper.getString('completed_orders') ?? '[]';
    final trips = <_Trip>[];
    try {
      final List<dynamic> list = jsonDecode(raw);
      for (final e in list) {
        final date = DateTime.tryParse(e['createdAt']?.toString() ?? '');
        if (date == null) continue;
        trips.add(_Trip(
          date: date,
          earnings: (e['price'] as num?)?.toDouble() ?? 0,
          distance: (e['distance'] as num?)?.toDouble() ?? 0,
        ));
      }
    } catch (_) {}

    // Oxirgi 7 kun (safar bo'lmagan kun 0 bilan ko'rinadi).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daily = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final dayTrips = trips.where((t) =>
          t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day);
      return DailyActivity(
        day: i == 6 ? 'Bugun' : '${day.day}',
        date: DateFormat('dd MMM').format(day),
        earnings: dayTrips.fold<double>(0, (s, t) => s + t.earnings),
        distance: dayTrips.fold<double>(0, (s, t) => s + t.distance).round(),
        clients: dayTrips.length,
      );
    });

    // Joriy yilda safar bo'lgan oylar.
    const monthNames = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
    ];
    final monthly = <MonthlyActivity>[];
    for (int m = 1; m <= 12; m++) {
      final monthTrips =
          trips.where((t) => t.date.year == now.year && t.date.month == m);
      if (monthTrips.isEmpty) continue;
      monthly.add(MonthlyActivity(
        month: '${monthNames[m - 1]}, ${now.year}',
        earnings: monthTrips.fold<double>(0, (s, t) => s + t.earnings).round(),
        distance: monthTrips.fold<double>(0, (s, t) => s + t.distance).round(),
        clients: monthTrips.length,
      ));
    }

    if (!mounted) return;
    setState(() {
      _dailyData = daily;
      _monthlyData = monthly;
      _selectedIndex = monthly.isEmpty ? 0 : monthly.length - 1;
      _hasTrips = trips.isNotEmpty;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;
  String? _expandedMonthId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.divider, width: 1.w),
          ),
          child: IconButton(
            icon: Icon(
              Iconsax.arrow_left_2,
              color: AppColors.textPrimary,
              size: 18.sp,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'Aktivligim',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Haftalik'),
            Tab(text: 'Oylik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWeeklyView(), _buildMonthlyView()],
      ),
    );
  }

  Widget _buildWeeklyView() {
    if (_loading) return _buildLoading();
    if (!_hasTrips) {
      return _buildEmpty(
        'Haftalik ma\'lumot yo\'q',
        'Safar yakunlaganingizda kunlik statistikangiz shu yerda ko\'rinadi',
      );
    }
    final totalEarnings = _dailyData.fold<double>(
      0,
      (sum, day) => sum + day.earnings,
    );
    final totalDistance = _dailyData.fold<int>(
      0,
      (sum, day) => sum + day.distance,
    );
    final totalClients = _dailyData.fold<int>(
      0,
      (sum, day) => sum + day.clients,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            label: 'Oxirgi 7 kun',
            title: 'Haftalik statistika',
            subtitle:
                '${NumberFormatter.formatPriceWithCurrency(totalEarnings)} • $totalDistance km • $totalClients safar',
          ),

          // Summary Cards
          Transform.translate(
            offset: Offset(0, -22.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.wallet,
                      title: 'Daromad',
                      value: (totalEarnings / 1000000).toStringAsFixed(1),
                      subtitle: 'mln',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.car,
                      title: 'Masofa',
                      value: '$totalDistance',
                      subtitle: 'km',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.people,
                      title: 'Safar',
                      value: '$totalClients',
                      subtitle: 'ta',
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Weekly chart
          _buildSectionTitle('Kunlik daromad', 'Oxirgi 7 kun tahlili'),
          SizedBox(height: 16.h),
          _buildWeeklyChart(),
          SizedBox(height: 28.h),

          // Daily list
          _buildSectionTitle('Kunlar bo\'yicha', null),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: _dailyData.reversed
                  .map((day) => _buildDailyCard(day))
                  .toList(),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildMonthlyView() {
    if (_loading) return _buildLoading();
    if (_monthlyData.isEmpty) {
      return _buildEmpty(
        'Oylik ma\'lumot yo\'q',
        'Safar yakunlaganingizda oylik statistikangiz shu yerda ko\'rinadi',
      );
    }
    final totalEarnings = _monthlyData.fold<int>(
      0,
      (sum, month) => sum + month.earnings,
    );
    final totalDistance = _monthlyData.fold<int>(
      0,
      (sum, month) => sum + month.distance,
    );
    final totalClients = _monthlyData.fold<int>(
      0,
      (sum, month) => sum + month.clients,
    );
    final selectedMonth =
        _monthlyData[_selectedIndex.clamp(0, _monthlyData.length - 1)];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            label: 'Oxirgi 12 oy',
            title: 'Yillik statistika',
            subtitle:
                '${(totalEarnings / 1000000).toStringAsFixed(1)} mln so\'m • $totalDistance km • $totalClients safar',
          ),

          // Total Summary Cards
          Transform.translate(
            offset: Offset(0, -22.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.wallet,
                      title: 'Daromad',
                      value: (totalEarnings / 1000000).toStringAsFixed(1),
                      subtitle: 'mln',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.car,
                      title: 'Masofa',
                      value: '$totalDistance',
                      subtitle: 'km',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Iconsax.people,
                      title: 'Clientlar',
                      value: '$totalClients',
                      subtitle: 'safar',
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Monthly Chart
          _buildSectionTitle('Oylik daromad', 'Oxirgi 12 oyning tahlili'),
          SizedBox(height: 16.h),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.divider, width: 1.w),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _monthlyMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (response != null && response.spot != null) {
                            setState(() {
                              _selectedIndex =
                                  response.spot!.touchedBarGroupIndex;
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
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _monthlyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _shortMonth(value.toInt()),
                                    style: TextStyle(
                                      color: _selectedIndex == value.toInt()
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight:
                                          _selectedIndex == value.toInt()
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
                            interval: _monthlyMaxY / 4,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${(value / 1000000).toStringAsFixed(0)}M',
                                style: TextStyle(
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
                        horizontalInterval: _monthlyMaxY / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppColors.divider,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      barGroups: _monthlyData.asMap().entries.map((entry) {
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildChartDetailItem(
                        icon: Iconsax.calendar,
                        label: selectedMonth.month,
                        color: AppColors.primary,
                      ),
                      Container(width: 1, height: 35, color: AppColors.divider),
                      _buildChartDetailItem(
                        icon: Iconsax.wallet,
                        label:
                            '${(selectedMonth.earnings / 1000000).toStringAsFixed(2)} mln',
                        color: const Color(0xFF4CAF50),
                      ),
                      Container(width: 1, height: 35, color: AppColors.divider),
                      _buildChartDetailItem(
                        icon: Iconsax.people,
                        label: '${selectedMonth.clients} ta',
                        color: const Color(0xFFFF9800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 30.h),

          // Detailed breakdown
          _buildSectionTitle(
            'Oylik batafsil',
            null,
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '${_monthlyData.length} oy',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: _monthlyData.reversed
                  .map((month) => _buildModernMonthCard(month))
                  .toList(),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required String label,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24.r,
            offset: Offset(0, 10.h),
            spreadRadius: -6.w,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 36.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Iconsax.trend_up, color: Colors.white, size: 28.w),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Iconsax.chart_21,
                  size: 52.w,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String? subtitle, {Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  String _shortMonth(int index) {
    if (index < 0 || index >= _monthlyData.length) return '';
    final full = _monthlyData[index].month.split(',').first.trim();
    return full.length >= 3 ? full.substring(0, 3) : full;
  }

  /// Eng yuqori oylik daromaddan kelib chiqib grafik shkalasini hisoblaydi
  /// (2 mln'gacha yaxlitlab, ustunlar to'g'ri ko'rinishi uchun).
  double get _monthlyMaxY {
    if (_monthlyData.isEmpty) return 2000000;
    final maxE = _monthlyData
        .map((m) => m.earnings)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    final rounded = ((maxE / 2000000).ceil() * 2000000).toDouble();
    return rounded <= 0 ? 2000000 : rounded;
  }

  Widget _buildWeeklyChart() {
    final maxEarning = _dailyData
        .map((d) => d.earnings)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.fromLTRB(12.w, 18.h, 12.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider, width: 1.w),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _dailyData.map((day) {
          final ratio = maxEarning == 0 ? 0.0 : day.earnings / maxEarning;
          final isToday = day.day == 'Bugun';
          final barColor = isToday
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.28);
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(day.earnings / 1000000).toStringAsFixed(1)}M',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 6.h),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) {
                    return Container(
                      height: (110.h * v).clamp(4.h, 110.h),
                      margin: EdgeInsets.symmetric(horizontal: 5.w),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8.r),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 8.h),
                Text(
                  day.day,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModernSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider, width: 1.w),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(AppColors.isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.w),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 6.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                SizedBox(width: 3.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 2.h),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartDetailItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20.w),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildModernMonthCard(MonthlyActivity month) {
    final isExpanded = _expandedMonthId == month.month;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedMonthId = isExpanded ? null : month.month;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isExpanded ? AppColors.primary : AppColors.divider,
            width: isExpanded ? 2.w : 1.5.w,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.shadow,
              blurRadius: isExpanded ? 25.r : 20.r,
              offset: Offset(0, 4.h),
              spreadRadius: isExpanded ? 0 : -2.w,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(
                      isExpanded ? 0.15 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Iconsax.calendar,
                    color: AppColors.primary,
                    size: 28.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month.month,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17.sp,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ),
                      if (!isExpanded) ...[
                        SizedBox(height: 8.h),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              _buildModernMonthStat(
                                Iconsax.wallet,
                                '${(month.earnings / 1000000).toStringAsFixed(2)} mln',
                                const Color(0xFF4CAF50),
                              ),
                              SizedBox(width: 14.w),
                              _buildModernMonthStat(
                                Iconsax.car,
                                '${month.distance}km',
                                const Color(0xFF2196F3),
                              ),
                              SizedBox(width: 14.w),
                              _buildModernMonthStat(
                                Iconsax.people,
                                '${month.clients}',
                                const Color(0xFFFF9800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Iconsax.arrow_right_3,
                      size: 14.w,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  children: [
                    // Total Earnings
                    _buildExpandedStat(
                      'Umumiy daromad',
                      NumberFormatter.formatPriceWithCurrency(month.earnings),
                      Iconsax.wallet,
                      const Color(0xFF4CAF50),
                    ),
                    SizedBox(height: 12.h),
                    // Total Distance
                    _buildExpandedStat(
                      'Umumiy masofa',
                      '${month.distance} km',
                      Iconsax.car,
                      const Color(0xFF2196F3),
                    ),
                    SizedBox(height: 12.h),
                    // Total Clients
                    _buildExpandedStat(
                      'Jami safarlar',
                      '${month.clients} ta',
                      Iconsax.people,
                      const Color(0xFFFF9800),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.w, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernMonthStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Icon(icon, size: 14.w, color: color),
        ),
        SizedBox(width: 6.w),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyCard(DailyActivity day) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.divider, width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20.r,
            offset: Offset(0, 4.h),
            spreadRadius: -2.w,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.day,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  day.date,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NumberFormatter.formatPriceWithCurrency(day.earnings),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17.sp,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    _buildModernMonthStat(
                      Iconsax.car,
                      '${day.distance}km',
                      const Color(0xFF2196F3),
                    ),
                    SizedBox(width: 16.w),
                    _buildModernMonthStat(
                      Iconsax.people,
                      '${day.clients}',
                      const Color(0xFFFF9800),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MonthlyActivity {
  final String month;
  final int earnings;
  final int distance;
  final int clients;

  MonthlyActivity({
    required this.month,
    required this.earnings,
    required this.distance,
    required this.clients,
  });
}

class DailyActivity {
  final String day;
  final String date;
  final double earnings;
  final int distance;
  final int clients;

  DailyActivity({
    required this.day,
    required this.date,
    required this.earnings,
    required this.distance,
    required this.clients,
  });
}

/// Tugatilgan safar (completed_orders) yozuvining soddalashtirilgan ko'rinishi.
class _Trip {
  final DateTime date;
  final double earnings;
  final double distance;

  _Trip({required this.date, required this.earnings, required this.distance});
}
