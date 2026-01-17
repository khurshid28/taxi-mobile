import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/number_formatter.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sample data for last 12 months with proper dates
  final List<MonthlyActivity> _monthlyData = [
    MonthlyActivity(
      month: 'Yanvar, 2025',
      earnings: 5250000,
      distance: 645,
      clients: 158,
    ),
    MonthlyActivity(
      month: 'Fevral, 2025',
      earnings: 4980000,
      distance: 578,
      clients: 145,
    ),
    MonthlyActivity(
      month: 'Mart, 2025',
      earnings: 6420000,
      distance: 762,
      clients: 191,
    ),
    MonthlyActivity(
      month: 'Aprel, 2025',
      earnings: 5680000,
      distance: 695,
      clients: 168,
    ),
    MonthlyActivity(
      month: 'May, 2025',
      earnings: 7120000,
      distance: 845,
      clients: 212,
    ),
    MonthlyActivity(
      month: 'Iyun, 2025',
      earnings: 6750000,
      distance: 801,
      clients: 198,
    ),
    MonthlyActivity(
      month: 'Iyul, 2025',
      earnings: 7890000,
      distance: 918,
      clients: 236,
    ),
    MonthlyActivity(
      month: 'Avgust, 2025',
      earnings: 7420000,
      distance: 878,
      clients: 221,
    ),
    MonthlyActivity(
      month: 'Sentabr, 2025',
      earnings: 6890000,
      distance: 812,
      clients: 205,
    ),
    MonthlyActivity(
      month: 'Oktabr, 2025',
      earnings: 7250000,
      distance: 856,
      clients: 218,
    ),
    MonthlyActivity(
      month: 'Noyabr, 2025',
      earnings: 6950000,
      distance: 823,
      clients: 209,
    ),
    MonthlyActivity(
      month: 'Dekabr, 2025',
      earnings: 7680000,
      distance: 892,
      clients: 228,
    ),
  ];

  // Last 7 days data
  late List<DailyActivity> _dailyData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateLast7Days();
  }

  void _generateLast7Days() {
    final now = DateTime.now();
    _dailyData = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      final dayNames = ['Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan', 'Yak'];
      return DailyActivity(
        day: index == 6 ? 'Bugun' : '${day.day}',
        date: DateFormat('dd MMM').format(day),
        earnings: (800000 + index * 150000 + (index % 2) * 200000).toDouble(),
        distance: 85 + index * 12 + (index % 3) * 8,
        clients: 18 + index * 3 + (index % 2) * 2,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _selectedIndex = 11; // Current month selected by default
  String? _expandedMonthId;
  int _selectedYear = 2025;

  final List<int> _availableYears = [2023, 2024, 2025, 2026];

  @override
  Widget build(BuildContext context) {
    final selectedMonth = _monthlyData[_selectedIndex];
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        leading: Container(
          margin: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey[200]!, width: 1.w),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
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
          unselectedLabelColor: Colors.grey[600],
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
          // Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.primary),
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oxirgi 7 kun',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 32.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Haftalik statistika',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${NumberFormatter.formatPriceWithCurrency(totalEarnings)} • $totalDistance km • $totalClients safar',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13.sp,
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
          ),

          // Summary Cards
          Transform.translate(
            offset: Offset(0, -15.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.account_balance_wallet,
                      title: 'Daromad',
                      value: '${(totalEarnings / 1000000).toStringAsFixed(1)}',
                      subtitle: 'mln',
                      color: const Color(0xFF4CAF50),
                      bgColor: const Color(0xFFE8F5E9),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.directions_car,
                      title: 'Masofa',
                      value: '$totalDistance',
                      subtitle: 'km',
                      color: const Color(0xFF2196F3),
                      bgColor: const Color(0xFFE3F2FD),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.people_alt,
                      title: 'Safar',
                      value: '$totalClients',
                      subtitle: 'ta',
                      color: const Color(0xFFFF9800),
                      bgColor: const Color(0xFFFFF3E0),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Daily list
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
    final selectedMonth = _monthlyData[_selectedIndex];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.primary),
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Oxirgi 12 oy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Year Dropdown
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.w,
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        dropdownColor: AppColors.primary,
                        underline: SizedBox(),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        items: _availableYears.map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              '$year',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedYear = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 32.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yillik statistika',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${(totalEarnings / 1000000).toStringAsFixed(1)} mln so\'m • $totalDistance km • $totalClients safar',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13.sp,
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
          ),

          // Total Summary Cards
          Transform.translate(
            offset: Offset(0, -15.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.account_balance_wallet,
                      title: 'Daromad',
                      value: '${(totalEarnings / 1000000).toStringAsFixed(1)}',
                      subtitle: 'mln',
                      color: const Color(0xFF4CAF50),
                      bgColor: const Color(0xFFE8F5E9),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.directions_car,
                      title: 'Masofa',
                      value: '$totalDistance',
                      subtitle: 'km',
                      color: const Color(0xFF2196F3),
                      bgColor: const Color(0xFFE3F2FD),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildModernSummaryCard(
                      icon: Icons.people_alt,
                      title: 'Clientlar',
                      value: '$totalClients',
                      subtitle: 'safar',
                      color: const Color(0xFFFF9800),
                      bgColor: const Color(0xFFFFF3E0),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Monthly Chart
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oylik daromad',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Oxirgi 12 oyning tahlili',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1.5.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 30.r,
                  offset: Offset(0, 8.h),
                  spreadRadius: -4.w,
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
                                    'H${value.toInt() + 1}',
                                    style: TextStyle(
                                      color: _selectedIndex == value.toInt()
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontSize: 12,
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
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.primary.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildChartDetailItem(
                        icon: Icons.calendar_today,
                        label: selectedMonth.month,
                        color: AppColors.primary,
                      ),
                      Container(width: 1, height: 35, color: Colors.grey[300]),
                      _buildChartDetailItem(
                        icon: Icons.account_balance_wallet,
                        label:
                            '${(selectedMonth.earnings / 1000000).toStringAsFixed(2)} mln',
                        color: const Color(0xFF4CAF50),
                      ),
                      Container(width: 1, height: 35, color: Colors.grey[300]),
                      _buildChartDetailItem(
                        icon: Icons.people_alt,
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Oylik batafsil',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
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
              ],
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

  Widget _buildModernSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20.r,
            offset: Offset(0, 6.h),
            spreadRadius: -2.w,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.w),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
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
    final completionRate = ((month.clients / 150) * 100).clamp(0, 100).toInt();

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isExpanded ? AppColors.primary : Colors.grey[200]!,
            width: isExpanded ? 2.w : 1.5.w,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
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
                    Icons.calendar_month,
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
                        Row(
                          children: [
                            _buildModernMonthStat(
                              Icons.account_balance_wallet,
                              '${(month.earnings / 1000000).toStringAsFixed(2)} mln',
                              const Color(0xFF4CAF50),
                            ),
                            SizedBox(width: 16.w),
                            _buildModernMonthStat(
                              Icons.directions_car,
                              '${month.distance}km',
                              const Color(0xFF2196F3),
                            ),
                            SizedBox(width: 16.w),
                            _buildModernMonthStat(
                              Icons.people_alt,
                              '${month.clients}',
                              const Color(0xFFFF9800),
                            ),
                          ],
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
                      Icons.arrow_forward_ios,
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.primary.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  children: [
                    // Total Earnings
                    _buildExpandedStat(
                      'Umumiy daromad',
                      NumberFormatter.formatPriceWithCurrency(month.earnings),
                      Icons.account_balance_wallet,
                      const Color(0xFF4CAF50),
                    ),
                    SizedBox(height: 12.h),
                    // Total Distance
                    _buildExpandedStat(
                      'Umumiy masofa',
                      '${month.distance} km',
                      Icons.directions_car,
                      const Color(0xFF2196F3),
                    ),
                    SizedBox(height: 12.h),
                    // Total Clients
                    _buildExpandedStat(
                      'Jami safarlar',
                      '${month.clients} ta',
                      Icons.people_alt,
                      const Color(0xFFFF9800),
                    ),
                    SizedBox(height: 12.h),
                    // Completion Rate
                    _buildExpandedStat(
                      'Bajarish foizi',
                      '$completionRate%',
                      Icons.check_circle,
                      const Color(0xFF9C27B0),
                    ),
                    SizedBox(height: 12.h),
                    // Progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Maqsad: 150 safar',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${month.clients}/150',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: LinearProgressIndicator(
                            value: month.clients / 150,
                            minHeight: 8.h,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
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
                  color: Colors.grey[600],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey[200]!, width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                      Icons.directions_car,
                      '${day.distance}km',
                      const Color(0xFF2196F3),
                    ),
                    SizedBox(width: 16.w),
                    _buildModernMonthStat(
                      Icons.people_alt,
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
