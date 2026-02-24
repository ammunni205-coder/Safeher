import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_screen.dart'; // Import your settings screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // User data
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userPhotoUrl;
  bool _isLoading = true;
  
  // Statistics data
  int _sosCount = 0;
  int _locationShares = 0;
  int _safetyCheckins = 0;
  int _guardianNotifications = 0;
  int _guardianCount = 0;
  
  // Feature settings
  bool _liveLocationSharing = true;
  bool _autoSOSDetection = false;
  bool _nightModeSafety = true;
  bool _backgroundMonitoring = true;
  bool _communityAlerts = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  // ==================== FIREBASE METHODS ====================

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
        _userEmail = user.email;
      });
      
      await _loadUserProfile();
      await _loadUserStatistics();
      await _loadUserSettings();
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    if (_userId == null) return;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();
          
      if (userDoc.exists) {
        setState(() {
          _userName = userDoc['fullName'] ?? userDoc['name'] ?? 'User';
          _userPhone = userDoc['phoneNumber'] ?? '+91 XXXXX XXXXX';
          _userPhotoUrl = userDoc['photoUrl'];
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadUserStatistics() async {
    if (_userId == null) return;
    
    try {
      // Load SOS count
      QuerySnapshot sosSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('alerts')
          .where('type', isEqualTo: 'quick_alert')
          .get();
      setState(() {
        _sosCount = sosSnapshot.docs.length;
      });

      // Load location shares count
      QuerySnapshot locationSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sharing_sessions')
          .get();
      setState(() {
        _locationShares = locationSnapshot.docs.length;
      });

      // Load guardian count
      QuerySnapshot guardianSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .get();
      setState(() {
        _guardianCount = guardianSnapshot.docs.length;
      });

      // Load guardian notifications count
      int notificationCount = 0;
      for (var guardian in guardianSnapshot.docs) {
        QuerySnapshot alertSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('guardians')
            .doc(guardian.id)
            .collection('alerts')
            .get();
        notificationCount += alertSnapshot.docs.length;
      }
      setState(() {
        _guardianNotifications = notificationCount;
        _safetyCheckins = _locationShares;
      });

    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _loadUserSettings() async {
    if (_userId == null) return;
    
    try {
      DocumentSnapshot settingsDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .get();
          
      if (settingsDoc.exists) {
        setState(() {
          _liveLocationSharing = settingsDoc['liveLocationSharing'] ?? true;
          _autoSOSDetection = settingsDoc['autoSOSDetection'] ?? false;
          _nightModeSafety = settingsDoc['nightModeSafety'] ?? true;
          _backgroundMonitoring = settingsDoc['backgroundMonitoring'] ?? true;
          _communityAlerts = settingsDoc['communityAlerts'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveFeatureSetting(String setting, bool value) async {
    if (_userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .set({
        setting: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving setting: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== UI BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B4CE6),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildStatistics(),
                  const SizedBox(height: 24),
                  _buildMenuItems(),
                  const SizedBox(height: 24),
                  _buildFeatureStatus(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Profile Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4CE6).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _userName?[0].toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail ?? 'email@example.com',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userPhone ?? '+91 XXXXX XXXXX',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safety Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('SOS', _sosCount.toString(), const Color(0xFFE53935)),
                _buildStatItem('Shares', _locationShares.toString(), const Color(0xFF6B4CE6)),
                _buildStatItem('Guardians', _guardianCount.toString(), const Color(0xFFFFBE0B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            Icons.security_rounded,
            'Privacy & Security',
            const Color(0xFF6B4CE6),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            Icons.notifications_rounded,
            'Notifications',
            const Color(0xFF2EC4B6),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            Icons.location_on_rounded,
            'Location',
            const Color(0xFFFFBE0B),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            Icons.group_rounded,
            'Guardian Circle',
            const Color(0xFF9B7EE8),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            Icons.emergency_rounded,
            'Emergency Settings',
            const Color(0xFFE53935),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D3142),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF6B4CE6),
          size: 20,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildFeatureStatus() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safety Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              'Live Location Sharing',
              _liveLocationSharing,
              (value) {
                setState(() => _liveLocationSharing = value);
                _saveFeatureSetting('liveLocationSharing', value);
              },
            ),
            _buildFeatureItem(
              'Auto-SOS Detection',
              _autoSOSDetection,
              (value) {
                setState(() => _autoSOSDetection = value);
                _saveFeatureSetting('autoSOSDetection', value);
              },
            ),
            _buildFeatureItem(
              'Night Mode Safety',
              _nightModeSafety,
              (value) {
                setState(() => _nightModeSafety = value);
                _saveFeatureSetting('nightModeSafety', value);
              },
            ),
            _buildFeatureItem(
              'Background Monitoring',
              _backgroundMonitoring,
              (value) {
                setState(() => _backgroundMonitoring = value);
                _saveFeatureSetting('backgroundMonitoring', value);
              },
            ),
            _buildFeatureItem(
              'Community Alerts',
              _communityAlerts,
              (value) {
                setState(() => _communityAlerts = value);
                _saveFeatureSetting('communityAlerts', value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature, bool enabled, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF2D3142),
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: const Color(0xFF6B4CE6),
            activeTrackColor: const Color(0xFF6B4CE6).withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}