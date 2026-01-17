import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../cubit/auth_cubit.dart';

class VerifyOtpPage extends StatefulWidget {
  final String phoneNumber;

  const VerifyOtpPage({super.key, required this.phoneNumber});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();

  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _resendOtp() {
    if (_resendTimer == 0) {
      context.read<AuthCubit>().resendOtp();
      setState(() {
        _resendTimer = 60;
      });
      _startTimer();
    }
  }

  void _verifyOtp() {
    final otp = _pinController.text;
    if (otp.length == 6) {
      context.read<AuthCubit>().verifyOtp(otp);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Tasdiqlash',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            context.go('/complete-profile');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AppColors.primary.withOpacity(0.05)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24.w,
              right: 24.w,
              top: 24.h,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40.h),
                Container(
                  width: 100.w,
                  height: 100.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.2),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 30.r,
                        offset: Offset(0, 10.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/message_duotone.svg',
                      width: 50.w,
                      height: 50.h,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                Text(
                  'Tasdiqlash kodini kiriting',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.2,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  '${widget.phoneNumber} raqamiga yuborildi',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 50.h),
                Center(
                  child: Pinput(
                    controller: _pinController,
                    focusNode: _focusNode,
                    length: 6,
                    autofocus: true,
                    onCompleted: (pin) => _verifyOtp(),
                    defaultPinTheme: PinTheme(
                      width: 56.w,
                      height: 64.h,
                      textStyle: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8.r,
                            offset: Offset(0, 2.h),
                          ),
                        ],
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 56.w,
                      height: 64.h,
                      textStyle: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.5.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 16.r,
                            offset: Offset(0, 4.h),
                          ),
                        ],
                      ),
                    ),
                    submittedPinTheme: PinTheme(
                      width: 56.w,
                      height: 64.h,
                      textStyle: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.5.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 20.r,
                            offset: Offset(0, 6.h),
                          ),
                        ],
                      ),
                    ),
                    errorPinTheme: PinTheme(
                      width: 56.w,
                      height: 64.h,
                      textStyle: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.red, width: 2.w),
                      ),
                    ),
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                    cursor: Container(
                      width: 2.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return Container(
                        height: 60.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.7),
                              AppColors.primary.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }
                    return Container(
                      height: 60.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF90EE90), Color(0xFF7FD97F)],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 20.r,
                            offset: Offset(0, 8.h),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _verifyOtp,
                          borderRadius: BorderRadius.circular(20.r),
                          child: Center(
                            child: Text(
                              'Tasdiqlash',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: _resendTimer == 0 ? _resendOtp : null,
                  child: Text(
                    _resendTimer > 0
                        ? 'Qayta yuborish ($_resendTimer s)'
                        : 'Qayta yuborish',
                    style: TextStyle(
                      color: _resendTimer > 0
                          ? AppColors.textSecondary
                          : AppColors.primary,
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
