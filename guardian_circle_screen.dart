import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianCircleScreen extends StatefulWidget {
  const GuardianCircleScreen({super.key});

  @override
  State<GuardianCircleScreen> createState() => _GuardianCircleScreenState();
}

class _GuardianCircleScreenState extends State<GuardianCircleScreen> {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  
  // Guardians list
  List<Guardian> _guardians = [];
  bool _isLoading = true;

  // Controllers for add guardian form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  // ==================== FIREBASE METHODS ====================

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _loadGuardiansFromFirebase();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGuardiansFromFirebase() async {
    if (_userId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _guardians = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return Guardian(
            id: doc.id,
            name: data['name'] ?? 'Unknown',
            phone: data['phone'] ?? '+91 XXXXX XXXXX',
            relationship: data['relationship'] ?? 'Guardian',
            avatar: Icons.person,
            isActive: data['isActive'] ?? true,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading guardians: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading guardians', isError: true);
    }
  }

  Future<void> _saveGuardianToFirebase(Guardian guardian) async {
    if (_userId == null) return;
    
    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .add({
        'name': guardian.name,
        'phone': guardian.phone,
        'relationship': guardian.relationship,
        'isActive': guardian.isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update guardian with ID
      setState(() {
        _guardians.add(Guardian(
          id: docRef.id,
          name: guardian.name,
          phone: guardian.phone,
          relationship: guardian.relationship,
          avatar: Icons.person,
          isActive: guardian.isActive,
          createdAt: DateTime.now(),
        ));
      });

      print('✅ Guardian saved with ID: ${docRef.id}');
      
    } catch (e) {
      print('❌ Error saving guardian: $e');
      _showSnackBar('Error saving guardian', isError: true);
    }
  }

  Future<void> _updateGuardianInFirebase(Guardian guardian) async {
    if (_userId == null || guardian.id == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .doc(guardian.id)
          .update({
        'name': guardian.name,
        'phone': guardian.phone,
        'relationship': guardian.relationship,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Guardian updated: ${guardian.id}');
      
    } catch (e) {
      print('❌ Error updating guardian: $e');
      _showSnackBar('Error updating guardian', isError: true);
    }
  }

  Future<void> _removeGuardianFromFirebase(Guardian guardian) async {
    if (_userId == null || guardian.id == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .doc(guardian.id)
          .delete();

      setState(() {
        _guardians.remove(guardian);
      });

      print('✅ Guardian removed: ${guardian.id}');
      _showSnackBar('${guardian.name} removed from guardian circle', isError: true);
      
    } catch (e) {
      print('❌ Error removing guardian: $e');
      _showSnackBar('Error removing guardian', isError: true);
    }
  }

  Future<void> _saveAlertToGuardian(Guardian guardian, String alertType) async {
    if (_userId == null || guardian.id == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .doc(guardian.id)
          .collection('alerts')
          .add({
        'type': alertType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'method': 'sms',
      });

      print('✅ Alert saved for guardian: ${guardian.name}');
      
    } catch (e) {
      print('❌ Error saving alert: $e');
    }
  }

  // ==================== ACTIONS ====================

  Future<void> _makePhoneCall(Guardian guardian) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: guardian.phone.replaceAll(' ', ''),
    );
    
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
        await _saveAlertToGuardian(guardian, 'call');
      } else {
        _showSnackBar('Cannot make call to ${guardian.name}');
      }
    } catch (e) {
      _showSnackBar('Error making call');
    }
  }

  Future<void> _sendWhatsApp(Guardian guardian) async {
    String cleanNumber = guardian.phone.replaceAll(' ', '').replaceAll('+', '');
    final Uri whatsappUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanNumber,
      queryParameters: {
        'text': 'Hello! I need your help. This is an emergency alert from SafeHer.',
      },
    );
    
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
        await _saveAlertToGuardian(guardian, 'whatsapp');
      } else {
        _showSnackBar('WhatsApp is not installed');
      }
    } catch (e) {
      _showSnackBar('Error opening WhatsApp');
    }
  }

  Future<void> _sendAlert(Guardian guardian) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: guardian.phone.replaceAll(' ', ''),
      queryParameters: {
        'body': '''
🚨 URGENT ALERT from SafeHer 🚨

I need your immediate help! This is an emergency.

📍 I'm sharing my live location with you.
⚠️ Please check on me as soon as possible.

- Sent from SafeHer Safety App
''',
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        await _saveAlertToGuardian(guardian, 'emergency_alert');
        _showSnackBar('Alert sent to ${guardian.name}');
      } else {
        _showSnackBar('Cannot send alert');
      }
    } catch (e) {
      _showSnackBar('Error sending alert');
    }
  }

  // ==================== ADD GUARDIAN ====================

  void _addGuardian() {
    _nameController.clear();
    _phoneController.clear();
    _relationshipController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Guardian',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 20),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter guardian\'s name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF6B4CE6)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  if (value.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter 10-digit mobile number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF6B4CE6)),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Relationship Field
              TextFormField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g., Mother, Father, Friend',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF6B4CE6)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter relationship';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveGuardian,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4CE6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Guardian'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveGuardian() {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text.trim();
      String phone = '+91 ${_phoneController.text.trim()}';
      String relationship = _relationshipController.text.trim();

      Guardian newGuardian = Guardian(
        name: name,
        phone: phone,
        relationship: relationship,
        avatar: Icons.person,
        isActive: true,
      );

      _saveGuardianToFirebase(newGuardian);
      Navigator.pop(context);
      _showSnackBar('$name added as guardian', isSuccess: true);

      // Clear controllers
      _nameController.clear();
      _phoneController.clear();
      _relationshipController.clear();
    }
  }

  // ==================== EDIT GUARDIAN ====================

  void _editGuardian(Guardian guardian) {
    _nameController.text = guardian.name;
    _phoneController.text = guardian.phone.replaceAll('+91 ', '');
    _relationshipController.text = guardian.relationship;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Guardian',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 20),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF6B4CE6)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF6B4CE6)),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Relationship Field
              TextFormField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF6B4CE6)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter relationship';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateGuardian(guardian),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4CE6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _updateGuardian(Guardian oldGuardian) {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text.trim();
      String phone = '+91 ${_phoneController.text.trim()}';
      String relationship = _relationshipController.text.trim();

      Guardian updatedGuardian = Guardian(
        id: oldGuardian.id,
        name: name,
        phone: phone,
        relationship: relationship,
        avatar: Icons.person,
        isActive: oldGuardian.isActive,
        createdAt: oldGuardian.createdAt,
      );

      setState(() {
        int index = _guardians.indexOf(oldGuardian);
        _guardians[index] = updatedGuardian;
      });

      _updateGuardianInFirebase(updatedGuardian);
      Navigator.pop(context);
      _showSnackBar('$name updated successfully', isSuccess: true);

      // Clear controllers
      _nameController.clear();
      _phoneController.clear();
      _relationshipController.clear();
    }
  }

  // ==================== REMOVE GUARDIAN ====================

  void _removeGuardian(Guardian guardian) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text(
              'Remove Guardian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${guardian.name} from your guardian circle?\n\nThey will no longer receive your SOS alerts or location updates.',
          style: const TextStyle(
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _removeGuardianFromFirebase(guardian);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ==================== INFO DIALOG ====================

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF6B4CE6)),
            SizedBox(width: 12),
            Text(
              'Guardian Circle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4CE6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your guardians will receive:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  SizedBox(height: 12),
                  _InfoItem(text: '• Instant SOS alerts'),
                  _InfoItem(text: '• Your live location'),
                  _InfoItem(text: '• Audio/video recordings'),
                  _InfoItem(text: '• Journey tracking updates'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap on a guardian to call, WhatsApp, or send an alert.\n\nYou can add up to 5 trusted contacts.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFF6B4CE6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess 
            ? Colors.green 
            : isError 
                ? Colors.red 
                : const Color(0xFF6B4CE6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guardian Circle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF6B4CE6),
                Color(0xFF8B6CE8),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B4CE6),
              ),
            )
          : Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4CE6), Color(0xFF8B6CE8)],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_guardians.length} Guardians',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'protecting you 24/7',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Guardians List
                Expanded(
                  child: _guardians.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadGuardiansFromFirebase,
                          color: const Color(0xFF6B4CE6),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _guardians.length,
                            itemBuilder: (context, index) {
                              return _buildGuardianCard(_guardians[index], index);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGuardian,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Guardian'),
        backgroundColor: const Color(0xFF6B4CE6),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4CE6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 80,
                color: Color(0xFF6B4CE6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Guardians Added',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your first guardian to start your safety circle',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addGuardian,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Your First Guardian'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4CE6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardianCard(Guardian guardian, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showGuardianActions(guardian),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6B4CE6), const Color(0xFF8B6CE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    guardian.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          guardian.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (guardian.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guardian.relationship,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guardian.phone,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quick Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Call Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call, color: Colors.green, size: 22),
                      onPressed: () => _makePhoneCall(guardian),
                      tooltip: 'Call ${guardian.name}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  // WhatsApp Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                      onPressed: () => _sendWhatsApp(guardian),
                      tooltip: 'WhatsApp ${guardian.name}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  // Alert Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                      onPressed: () => _sendAlert(guardian),
                      tooltip: 'Send Alert to ${guardian.name}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  // More Options
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: Color(0xFF6B4CE6)),
                            SizedBox(width: 8),
                            Text('Edit Guardian'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editGuardian(guardian);
                      } else if (value == 'remove') {
                        _removeGuardian(guardian);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuardianActions(Guardian guardian) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Guardian Info
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4CE6), Color(0xFF8B6CE8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      guardian.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guardian.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        guardian.relationship,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        guardian.phone,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons Grid
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _makePhoneCall(guardian);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.pop(context);
                      _sendWhatsApp(guardian);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'Send Alert',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _sendAlert(guardian);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit',
                    color: const Color(0xFF6B4CE6),
                    onTap: () {
                      Navigator.pop(context);
                      _editGuardian(guardian);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== INFO ITEM WIDGET ====================
class _InfoItem extends StatelessWidget {
  final String text;

  const _InfoItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF6B4CE6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.replaceFirst('• ', ''),
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== GUARDIAN MODEL ====================
class Guardian {
  final String? id;
  final String name;
  final String phone;
  final String relationship;
  final IconData avatar;
  final bool isActive;
  final DateTime? createdAt;

  Guardian({
    this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.avatar,
    required this.isActive,
    this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Guardian &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}