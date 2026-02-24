import 'package:flutter/material.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _pages = [
    OnboardingItem(
      icon: Icons.emergency_rounded,
      title: 'Instant Emergency Alert',
      description: 'Long-press the red SOS button to trigger immediate alerts with live location sharing to your trusted contacts',
      color: Color(0xFFE53935),
      gradient: [Color(0xFFE53935), Color(0xFFEF5350)],
    ),
    OnboardingItem(
      icon: Icons.share_location_rounded,
      title: 'Real-time Location Sharing',
      description: 'Share your live location with family and emergency services during critical situations',
      color: Color(0xFF6B4CE6),
      gradient: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
    ),
    OnboardingItem(
      icon: Icons.group_rounded,
      title: 'Guardian Circle',
      description: 'Create a safety network with family and friends who receive automatic alerts when you need help',
      color: Color(0xFFB8A4F5),
      gradient: [Color(0xFF9B7EE8), Color(0xFFB8A4F5)],
    ),
    OnboardingItem(
      icon: Icons.map_rounded,
      title: 'Safe Route Planning',
      description: 'Get AI-powered safest routes based on real-time safety data and community reports',
      color: Color(0xFF2EC4B6),
      gradient: [Color(0xFF2EC4B6), Color(0xFF4ECDC4)],
    ),
    OnboardingItem(
      icon: Icons.shield_rounded,
      title: 'Your Safety Companion',
      description: '24/7 protection with emergency contacts, safety tips, and discreet features for any situation',
      color: Color(0xFFFFBE0B),
      gradient: [Color(0xFFFFBE0B), Color(0xFFFFD166)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button at top right
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            
            // Logo and app name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4CE6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 40,
                      color: Color(0xFF6B4CE6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SafeHer',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Safety, Our Priority',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // PageView with SingleChildScrollView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    child: _buildPage(_pages[index]),
                  );
                },
              ),
            ),
            
            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),
            
            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4CE6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: const Color(0xFF6B4CE6).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage == _pages.length - 1 
                          ? Icons.arrow_forward_rounded 
                          : Icons.arrow_forward_ios_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated gradient circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: item.color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: 70,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
              letterSpacing: 0.3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
          
          // Add some extra space at the bottom
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 7,
      width: _currentPage == index ? 28 : 7,
      decoration: BoxDecoration(
        gradient: _currentPage == index 
          ? const LinearGradient(
              colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
        color: _currentPage == index ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final List<Color> gradient;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.gradient,
  });
}