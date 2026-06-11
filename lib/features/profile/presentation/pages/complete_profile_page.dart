import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
  final _carColorController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _passportImage;
  File? _carImage;
  String? _selectedCarType;
  String? _selectedCarColor;

  final _carNumberMask = MaskTextInputFormatter(
    mask: '## A ### AA',
    filter: {'#': RegExp(r'[0-9]'), 'A': RegExp(r'[A-Z]')},
  );

  @override
  void dispose() {
    _nameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _carNumberController.dispose();
    _carTypeController.dispose();
    _carColorController.dispose();
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
      backgroundColor: AppColors.surfaceVariant,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32.h),
                  // Passport Image
                  Text(
                    'Passport rasmi',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
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
                              : AppColors.divider,
                          width: _passportImage != null ? 3.w : 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _passportImage != null
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.shadow,
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
                                    color: AppColors.surface,
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
                                    child: Icon(
                                      Iconsax.document,
                                      size: 40.w,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Passport rasmini yuklang',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Rasmni tanlash uchun bosing',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
                              : AppColors.divider,
                          width: _carImage != null ? 3.w : 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _carImage != null
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.shadow,
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
                                    color: AppColors.surface,
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
                                    child: Icon(
                                      Iconsax.car,
                                      size: 40.w,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Mashina rasmini yuklang',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Rasmni tanlash uchun bosing',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
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
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF9C27B0).withOpacity(0.2),
                                const Color(0xFF9C27B0).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Icon(
                              Iconsax.user,
                              size: 20.w,
                              color: const Color(0xFF9C27B0),
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
                          horizontal: 16.w,
                          vertical: 14.h,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
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
                        labelText: 'Familiya',
                        hintText: 'Masalan: Azizov',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF9C27B0).withOpacity(0.2),
                                const Color(0xFF9C27B0).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Icon(
                              Iconsax.user,
                              size: 20.w,
                              color: const Color(0xFF9C27B0),
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
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Familiyangizni kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Email (optional)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
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
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Icon(
                              Iconsax.sms,
                              size: 20.w,
                              color: const Color(0xFF00BCD4),
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
                          horizontal: 16.w,
                          vertical: 14.h,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 15.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _carNumberController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [_carNumberMask],
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mashina raqami',
                        hintText: '01 A 123 BC',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Iconsax.hashtag,
                            color: const Color(0xFF00BCD4),
                            size: 20.w,
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
                          horizontal: 16.w,
                          vertical: 14.h,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 15.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCarType,
                      decoration: InputDecoration(
                        labelText: 'Mashina turi',
                        hintText: 'Mashina turini tanlang',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Iconsax.car,
                            color: const Color(0xFF00BCD4),
                            size: 20.w,
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
                          horizontal: 16.w,
                          vertical: 14.h,
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
                        Iconsax.arrow_down_1,
                        color: AppColors.primary,
                        size: 28.sp,
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Car Color
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 15.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCarColor,
                      decoration: InputDecoration(
                        labelText: 'Mashina rangi',
                        hintText: 'Mashina rangini tanlang',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        labelStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Container(
                          width: 40.w,
                          margin: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.2),
                                const Color(0xFF00BCD4).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Iconsax.color_swatch,
                            color: const Color(0xFF00BCD4),
                            size: 20.w,
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
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
                      items:
                          [
                            'Oq',
                            'Qora',
                            'Kulrang',
                            'Kumush',
                            'Qizil',
                            'Ko\'k',
                            'Moviy',
                            'Yashil',
                            'Sariq',
                            'Jigarrang',
                            'Pushti',
                            'Boshqa',
                          ].map((String color) {
                            return DropdownMenuItem<String>(
                              value: color,
                              child: Text(
                                color,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCarColor = newValue;
                          _carColorController.text = newValue ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mashina rangini tanlang';
                        }
                        return null;
                      },
                      icon: Icon(
                        Iconsax.arrow_down_1,
                        color: AppColors.primary,
                        size: 28.sp,
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
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
