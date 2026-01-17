import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taxi_mobile/core/theme/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Tez va Qulay',
      description:
          'Mijozlarni tez topib, yo\'lga chiqing. Har bir buyurtma sizning eshigingizgacha keladi.',
      image: '🚖',
      gradient: const [Color(0xFF90EE90), Color(0xFF7FD97F)],
    ),
    OnboardingItem(
      title: 'Ortiq Daromad',
      description:
          'Har bir safar uchun adolatli to\'lov. Qancha ishlasangiz, shuncha topasiz.',
      image: '💰',
      gradient: const [Color(0xFF4CAF50), Color(0xFF45A049)],
    ),
    OnboardingItem(
      title: 'Xavfsiz va Ishonchli',
      description:
          'Har bir safar kuzatiladi. Siz va mijozlaringiz xavfsizligi birinchi o\'rinda.',
      image: '🛡️',
      gradient: const [Color(0xFF2196F3), Color(0xFF1976D2)],
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    context.go('/phone');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _items[_currentPage].gradient[0].withOpacity(0.1),
              _items[_currentPage].gradient[1].withOpacity(0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 100.w),
                    _buildPageIndicator(),
                    SizedBox(
                      width: 100.w,
                      child: _currentPage < _items.length - 1
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    _items[_currentPage].gradient[0]
                                        .withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: _items[_currentPage].gradient[0]
                                      .withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _items[_currentPage].gradient[0]
                                        .withOpacity(0.2),
                                    blurRadius: 12.r,
                                    offset: Offset(0.w, 4.h),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _skipOnboarding,
                                  borderRadius: BorderRadius.circular(20.r),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 10.h,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'O\'tkazish',
                                          style: TextStyle(
                                            color: _items[_currentPage]
                                                .gradient[1],
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color:
                                              _items[_currentPage].gradient[1],
                                          size: 18.w,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _buildPageContent(_items[index]);
                  },
                ),
              ),

              // Next/Get Started button
              Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  children: [
                    _buildNextButton(),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _items.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          height: 8.h,
          width: _currentPage == index ? 32 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: _currentPage == index
                ? _items[_currentPage].gradient[0]
                : Colors.grey[300],
            boxShadow: _currentPage == index
                ? [
                    BoxShadow(
                      color: _items[_currentPage].gradient[0].withOpacity(0.4),
                      blurRadius: 8.r,
                      offset: Offset(0.w, 2.h),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image container with gradient background
          Container(
            width: 280.w,
            height: 280.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item.gradient[0].withOpacity(0.2),
                  item.gradient[1].withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: item.gradient[0].withOpacity(0.3),
                  blurRadius: 60.r,
                  offset: Offset(0.w, 20.h),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 220.w,
                height: 220.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: item.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: item.gradient[1].withOpacity(0.4),
                      blurRadius: 30.r,
                      offset: Offset(0.w, 15.h),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    item.image,
                    style: TextStyle(fontSize: 100.sp, height: 1.h),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 60.h),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.2,
              height: 1.2,
              shadows: [
                Shadow(
                  color: item.gradient[0].withOpacity(0.3),
                  blurRadius: 20.r,
                  offset: Offset(0.w, 4.h),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final isLastPage = _currentPage == _items.length - 1;
    return Container(
      width: double.infinity,
      height: 60.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _items[_currentPage].gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: _items[_currentPage].gradient[0].withOpacity(0.4),
            blurRadius: 20.r,
            offset: Offset(0.w, 8.h),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _nextPage,
          borderRadius: BorderRadius.circular(20.r),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLastPage ? 'Boshlash' : 'Keyingisi',
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
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String image;
  final List<Color> gradient;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
    required this.gradient,
  });
}
