import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/auth_cubit.dart';

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '+998 ## ### ## ##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().sendOtp(_phoneController.text);
    }
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
        shadowColor: Colors.black.withOpacity(0.05),
        title: Text(
          'Telefon raqamingiz',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is OtpSent) {
            context.go('/verify-otp', extra: state.phoneNumber);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
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
                  // Logo Container
                  Center(
                    child: Container(
                      width: 140.w,
                      height: 140.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32.r),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.15),
                            blurRadius: 30.r,
                            offset: Offset(0, 10.h),
                            spreadRadius: -5.r,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(24.w),
                      child: Image.asset(
                        'assets/images/taxi_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 40.h),
                  // Title
                  Text(
                    'Telefon raqamingizni kiriting',
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
                  // Subtitle
                  Text(
                    'Biz sizga tasdiqlash kodini yuboramiz',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 50.h),
                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneMaskFormatter],
                      scrollPadding: EdgeInsets.only(bottom: 200.h),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '+998 90 123 45 67',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          height: 40.h,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.2),
                                AppColors.primary.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/phone_duotone.svg',
                              width: 20.w,
                              height: 20.h,
                            ),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 48.w,
                          minHeight: 48.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 2.w,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide(
                            color: Colors.red[300]!,
                            width: 1.5.w,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: BorderSide(color: Colors.red, width: 2.w),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Telefon raqamni kiriting';
                        }
                        if (value.length < 9) {
                          return 'To\'liq raqamni kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 40.h),
                  // Continue Button
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                              spreadRadius: -2.r,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sendOtp,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Davom etish',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 24.w,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
