import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/data/mock_data.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/utils/storage_helper.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> with SingleTickerProviderStateMixin {
  List<PaymentModel> _payments = [];
  double _balance = 295000;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _payments = MockData.getPayments();
    _loadBalance();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await StorageHelper.getDouble('driver_balance') ?? 295000;
    setState(() {
      _balance = balance;
    });
  }

  Future<void> _refreshPayments() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _payments = MockData.getPayments();
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Balansni to\'ldirish',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Quyidagi miqdorlardan birini tanlang yoki o\'zingizni kiriting',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAmountChip('50,000', amountController),
                  _buildAmountChip('100,000', amountController),
                  _buildAmountChip('200,000', amountController),
                  _buildAmountChip('500,000', amountController),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Miqdor (so\'m)',
                  hintText: 'Miqdorni kiriting',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(
                    amountController.text.replaceAll(',', ''),
                  );
                  if (amount != null && amount > 0) {
                    final newBalance = _balance + amount;
                    await StorageHelper.setDouble('driver_balance', newBalance);
                    setState(() {
                      _balance = newBalance;
                      _payments.insert(
                        0,
                        PaymentModel(
                          id: 'PAY${DateTime.now().millisecondsSinceEpoch}',
                          title: 'Balans to\'ldirish',
                          amount: amount,
                          type: PaymentType.topUp,
                          createdAt: DateTime.now(),
                        ),
                      );
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Balans muvaffaqiyatli to\'ldirildi!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'To\'ldirish',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountChip(String amount, TextEditingController controller) {
    return InkWell(
      onTap: () {
        controller.text = amount.replaceAll(',', '');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Color _getPaymentColor(PaymentType type) {
    switch (type) {
      case PaymentType.topUp:
        return Colors.blue;
      case PaymentType.earning:
        return Colors.green;
      case PaymentType.withdrawal:
        return Colors.orange;
      case PaymentType.bonus:
        return Colors.purple;
    }
  }

  IconData _getPaymentIcon(PaymentType type) {
    switch (type) {
      case PaymentType.topUp:
        return Icons.add_circle_outline;
      case PaymentType.earning:
        return Icons.attach_money;
      case PaymentType.withdrawal:
        return Icons.arrow_circle_down;
      case PaymentType.bonus:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshPayments,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'To\'lovlar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Balans',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: _balance),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOut,
                            builder: (context, double value, child) {
                              return Text(
                                '${value.toStringAsFixed(0)} so\'m',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _showTopUpDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Balansni to\'ldirish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildPaymentCard(_payments[index]),
                    );
                  },
                  childCount: _payments.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final color = _getPaymentColor(payment.type);
    final isNegative = payment.amount < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPaymentIcon(payment.type),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(payment.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isNegative ? '' : '+'}${payment.amount.toStringAsFixed(0)} so\'m',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isNegative ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
