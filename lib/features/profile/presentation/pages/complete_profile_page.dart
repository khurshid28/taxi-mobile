import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
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
  final _imagePicker = ImagePicker();
  File? _passportImage;

  @override
  void dispose() {
    _nameController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
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
      appBar: AppBar(
        title: const Text('Profilni to\'ldirish'),
      ),
      body: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileCompleted) {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Ma\'lumotlaringizni kiriting',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Passport Image
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: _passportImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _passportImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 50,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Passport rasmini yuklang',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ism',
                    hintText: 'Masalan: Aziz',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ismingizni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Full Name
                TextFormField(
                  controller: _fullnameController,
                  decoration: const InputDecoration(
                    labelText: 'To\'liq ism',
                    hintText: 'Masalan: Aziz Azizov',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'To\'liq ismingizni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Email (optional)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (ixtiyoriy)',
                    hintText: 'example@mail.com',
                    prefixIcon: Icon(Icons.email_outlined),
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
                const SizedBox(height: 32),
                BlocBuilder<ProfileCubit, ProfileState>(
                  builder: (context, state) {
                    if (state is ProfileLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return ElevatedButton(
                      onPressed: _completeProfile,
                      child: const Text('Davom etish'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
