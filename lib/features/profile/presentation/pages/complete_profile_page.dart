import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../cubit/profile_cubit.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carTypeController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _passportImage;
  File? _carImage;
  String? _selectedCarType;

  final _carNumberMask = MaskTextInputFormatter(
    mask: '## A ### AA',
    filter: {'#': RegExp(r'[0-9]'), 'A': RegExp(r'[A-Za-z]')},
  );

  @override
  void dispose() {
    _nameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _carNumberController.dispose();
    _carTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _passportImage = File(pickedFile.path);
      });
      context.read<ProfileCubit>().updatePassportImage(_passportImage!);
    }
  }

  Future<void> _pickCarImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _carImage = File(pickedFile.path);
      });
    }
  }

  void _completeProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<ProfileCubit>().completeProfile(
        name: _nameController.text,
        fullname: _fullnameController.text,
        email: _emailController.text,
      );
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
        title: Text(
          'Profilni to\'ldirish',
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
      body: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileCompleted) {
            context.go('/home');
          } else if (state is ProfileError) {
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
                  SizedBox(height: 20.h),
                  Text(
                    'Ma\'lumotlaringizni kiriting',
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
                    'Iltimos, haqiqiy ma\'lumotlaringizni kiriting.\nBu sizning xavfsizligingiz uchun muhim.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32.h),
                  // Passport Image
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 180.w,
                        height: 180.h,
                        decoration: BoxDecoration(
                          gradient: _passportImage != null
                              ? null
                              : LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                ),
                          color: _passportImage != null ? null : null,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: _passportImage != null
                                ? AppColors.primary
                                : Colors.grey[300]!,
                            width: _passportImage != null ? 3.w : 2.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _passportImage != null
                                  ? AppColors.primary.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 20.r,
                              offset: Offset(0, 8.h),
                            ),
                          ],
                        ),
                        child: _passportImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22.r),
                                child: Image.file(
                                  _passportImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 70.w,
                                    height: 70.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
                                          blurRadius: 10.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/icons/document_duotone.svg',
                                        width: 40.w,
                                        height: 40.h,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    'Passport rasmini yuklang',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Rasmni tanlash uchun bosing',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Car Photo
                  Text(
                    'Mashina rasmi',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: _pickCarImage,
                    child: Container(
                      width: double.infinity,
                      height: 180.h,
                      decoration: BoxDecoration(
                        gradient: _carImage == null
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.08),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                              )
                            : null,
                        color: _carImage != null ? null : null,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: _carImage != null
                              ? AppColors.primary
                              : Colors.grey[300]!,
                          width: _carImage != null ? 3.w : 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _carImage != null
                                ? AppColors.primary.withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 20.r,
                            offset: Offset(0, 8.h),
                          ),
                        ],
                      ),
                      child: _carImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22.r),
                              child: Image.file(_carImage!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 70.w,
                                  height: 70.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        blurRadius: 10.r,
                                        offset: Offset(0, 4.h),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/icons/car_duotone.svg',
                                      width: 40.w,
                                      height: 40.h,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Mashina rasmini yuklang',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Rasmni tanlash uchun bosing',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 40.h),
                  // Name
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
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Ism',
                        hintText: 'Masalan: Aziz',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 48.w,
                          margin: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF9C27B0).withOpacity(0.2),
                                const Color(0xFF9C27B0).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/user_duotone.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ismingizni kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Full Name
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
                      controller: _fullnameController,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'To\'liq ism',
                        hintText: 'Masalan: Aziz Azizov',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 48.w,
                          margin: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF9C27B0).withOpacity(0.2),
                                const Color(0xFF9C27B0).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/user_duotone.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'To\'liq ismingizni kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Email (optional)
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email (ixtiyoriy)',
                        hintText: 'example@mail.com',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 48.w,
                          margin: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/email_duotone.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('@')) {
                            return 'To\'g\'ri email kiriting';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Car Number
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
                      controller: _carNumberController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [_carNumberMask],
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mashina raqami',
                        hintText: '01 A 123 BC',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 48.w,
                          margin: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/car_duotone.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mashina raqamini kiriting';
                        }
                        if (value.length < 10) {
                          return 'To\'liq raqam kiriting (01 A 123 BC)';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Car Type
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
                    child: DropdownButtonFormField<String>(
                      value: _selectedCarType,
                      decoration: InputDecoration(
                        labelText: 'Mashina turi',
                        hintText: 'Mashina turini tanlang',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 48.w,
                          margin: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/car_duotone.svg',
                              width: 24.w,
                              height: 24.h,
                            ),
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 20.h,
                        ),
                      ),
                      items:
                          [
                            'Chevrolet Cobalt',
                            'Chevrolet Gentra',
                            'Chevrolet Nexia',
                            'Chevrolet Spark',
                            'Daewoo Nexia',
                            'Daewoo Matiz',
                            'Kia Rio',
                            'Hyundai Accent',
                            'Toyota Camry',
                            'Toyota Corolla',
                            'BYD',
                            'Boshqa',
                          ].map((String carType) {
                            return DropdownMenuItem<String>(
                              value: carType,
                              child: Text(
                                carType,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCarType = newValue;
                          _carTypeController.text = newValue ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mashina turini tanlang';
                        }
                        return null;
                      },
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 28.sp,
                      ),
                      isExpanded: true,
                      dropdownColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  BlocBuilder<ProfileCubit, ProfileState>(
                    builder: (context, state) {
                      if (state is ProfileLoading) {
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
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _completeProfile,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Center(
                              child: Text(
                                'Davom etish',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
