import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_messenger.dart';
import '../cubit/auth_cubit.dart';

class CarNumberPage extends StatefulWidget {
  const CarNumberPage({super.key});

  @override
  State<CarNumberPage> createState() => _CarNumberPageState();
}

class _CarNumberPageState extends State<CarNumberPage> {
  final _carNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _carNumberController.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().enterCarNumber(_carNumberController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Mashina raqami',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is CarNumberEntered) {
            context.push('/password', extra: state.carNumber);
          } else if (state is AuthError) {
            AppMessenger.error(context, state.message);
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 24.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40.h),
                // Logo
                Center(
                  child: Container(
                    width: 120.w,
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    padding: EdgeInsets.all(22.w),
                    child: Image.asset(
                      'assets/images/taxi_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
                // Title
                Text(
                  'Mashina raqamingizni kiriting',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                // Subtitle
                Text(
                  'Tizimga kirish uchun mashina raqami kerak',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50.h),
                // Car number input
                TextFormField(
                  controller: _carNumberController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UzPlateInputFormatter()],
                  scrollPadding: EdgeInsets.only(bottom: 200.h),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Mashina raqami',
                    hintText: '01 A 777 AA',
                    prefixIcon: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 14.h,
                      ),
                      child: Icon(
                        Iconsax.car,
                        color: AppColors.primary,
                        size: 22.w,
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 48.w,
                      minHeight: 48.h,
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) {
                      return 'Mashina raqamini kiriting';
                    }
                    if (!RegExp(r'^\d{2} [A-Z] \d{3} [A-Z]{2}$')
                        .hasMatch(v)) {
                      return 'Format: 01 A 777 AA';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40.h),
                // Continue button
                SizedBox(
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Davom etish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Iconsax.arrow_right_3,
                          color: Colors.white,
                          size: 20.w,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O'zbekiston davlat raqami formatlovchisi: `01 A 777 AA`
/// (2 raqam, 1 harf, 3 raqam, 2 harf). Yozilayotganda avtomatik
/// bo'sh joy qo'yadi, harflarni katta qiladi va slot turini tekshiradi.
class UzPlateInputFormatter extends TextInputFormatter {
  static const int _maxChars = 8; // bo'shliqsiz belgilar soni

  bool _wantDigit(int slot) => slot < 2 || (slot >= 3 && slot < 6);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final input =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final out = StringBuffer();
    var slot = 0;
    for (var i = 0; i < input.length && slot < _maxChars; i++) {
      final ch = input[i];
      final isDigit = RegExp(r'[0-9]').hasMatch(ch);
      if (_wantDigit(slot) != isDigit) continue; // noto'g'ri tur - tashlab ketamiz
      if (slot == 2 || slot == 3 || slot == 6) out.write(' ');
      out.write(ch);
      slot++;
    }
    final formatted = out.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
