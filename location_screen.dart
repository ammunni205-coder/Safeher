import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  bool _isSharingLocation = false;
  LocationData? _currentLocation;
  Location _locationService = Location();
  bool _isLoading = false;
  String? _locationError;
  bool _locationServiceEnabled = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  // Guardian contacts
  List<Map<String, dynamic>> _guardians = [];

  // Duration options
  final List<String> _durationOptions = ['30 min', '1 hour', 'Until I stop'];
  String _selectedDuration = 'Until I stop';

  // Sharing method
  String _sharingMethod = 'sms'; // 'sms', 'whatsapp', 'email'

  // Variables for adding new guardian
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadGuardiansFromFirebase();
    _initializeLocationService();
  }

  // ==================== FIREBASE METHODS ====================

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  Future<void> _loadGuardiansFromFirebase() async {
    if (_userId == null) return;
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .get();

      if (mounted) {
        setState(() {
          _guardians = snapshot.docs.map((doc) {
            return {
              'name': doc['name'] ?? 'Unknown',
              'phone': doc['phone'] ?? '+91 XXXXX XXXXX',
              'selected': true,
              'docId': doc.id,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading guardians: $e');
    }
  }

  Future<void> _saveGuardianToFirebase(String name, String phone) async {
    if (_userId == null) return;
    
    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .add({
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      if (mounted) {
        setState(() {
          _guardians.add({
            'name': name,
            'phone': phone,
            'selected': true,
            'docId': docRef.id,
          });
        });
      }
    } catch (e) {
      print('Error saving guardian: $e');
      if (mounted) {
        _showSnackBar('Error saving guardian', isError: true);
      }
    }
  }

  Future<void> _removeGuardianFromFirebase(int index, String docId) async {
    if (_userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .doc(docId)
          .delete();
      
      if (mounted) {
        setState(() {
          _guardians.removeAt(index);
        });
      }
    } catch (e) {
      print('Error removing guardian: $e');
    }
  }

  // ==================== FIXED LOCATION PERMISSION ====================
  
  Future<void> _initializeLocationService() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      // Check if location service is enabled
      _locationServiceEnabled = await _locationService.serviceEnabled();
      if (!_locationServiceEnabled) {
        _locationServiceEnabled = await _locationService.requestService();
      }

      // Check permission status
      _permissionStatus = await _locationService.hasPermission();
      if (_permissionStatus == PermissionStatus.denied) {
        _permissionStatus = await _locationService.requestPermission();
      }

      if (_locationServiceEnabled && _permissionStatus == PermissionStatus.granted) {
        // Get current location
        await _getCurrentLocation();
      } else {
        setState(() {
          _isLoading = false;
          _locationError = _getLocationErrorMessage();
        });
      }
    } catch (e) {
      print('Error initializing location: $e');
      setState(() {
        _isLoading = false;
        _locationError = 'Error initializing location service';
      });
    }
  }

  String _getLocationErrorMessage() {
    if (!_locationServiceEnabled) {
      return 'Location service is disabled. Please enable it in settings.';
    }
    if (_permissionStatus == PermissionStatus.denied) {
      return 'Location permission denied. Please grant permission to share location.';
    }
    if (_permissionStatus == PermissionStatus.deniedForever) {
      return 'Location permission permanently denied. Please enable in app settings.';
    }
    return 'Unable to access location. Please check your settings.';
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      // Request location service
      if (!_locationServiceEnabled) {
        _locationServiceEnabled = await _locationService.requestService();
      }

      // Request permission
      if (_permissionStatus == PermissionStatus.denied || 
          _permissionStatus == PermissionStatus.deniedForever) {
        _permissionStatus = await _locationService.requestPermission();
      }

      if (_locationServiceEnabled && _permissionStatus == PermissionStatus.granted) {
        await _getCurrentLocation();
      } else {
        setState(() {
          _isLoading = false;
          _locationError = _getLocationErrorMessage();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationError = 'Error requesting location permission: ${e.toString()}';
      });
      print('Error requesting location: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _locationError = null;
    });

    try {
      final location = await _locationService.getLocation();
      
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _isLoading = false;
          _locationError = null;
        });
        print('✅ Location obtained: ${location.latitude}, ${location.longitude}');
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _locationError = 'Failed to get location. Please try again.';
        });
      }
    }
  }

  // ==================== GUARDIAN METHODS ====================

  void _toggleGuardianSelection(int index) {
    setState(() {
      _guardians[index]['selected'] = !_guardians[index]['selected'];
    });
  }

  void _selectDuration(String duration) {
    setState(() {
      _selectedDuration = duration;
    });
  }

  void _selectSharingMethod(String method) {
    setState(() {
      _sharingMethod = method;
    });
  }

  // ==================== LOCATION SHARING ====================

  Future<void> _startLocationSharing() async {
    // Check if location is available
    if (_currentLocation == null) {
      await _requestLocationPermission();
      if (_currentLocation == null) {
        if (mounted) {
          _showSnackBar('Unable to get location. Please check permissions.', isError: true);
        }
        return;
      }
    }

    // Get selected guardians
    List<String> selectedGuardians = [];
    for (var guardian in _guardians) {
      if (guardian['selected'] == true) {
        selectedGuardians.add(guardian['name']);
      }
    }

    if (selectedGuardians.isEmpty) {
      if (mounted) {
        _showSnackBar('Please select at least one guardian');
      }
      return;
    }

    setState(() {
      _isSharingLocation = true;
    });

    String message = createLocationMessage();
    
    for (var guardian in _guardians) {
      if (guardian['selected'] == true) {
        await _sendLocationToGuardian(guardian['phone'], guardian['name'], message);
      }
    }

    // Save sharing session to Firebase
    await _saveSharingSessionToFirebase(selectedGuardians);

    if (mounted) {
      _showSnackBar(
        'Location shared via ${_getSharingMethodName()} with ${selectedGuardians.length} guardian(s)',
        isSuccess: true,
      );
    }
  }

  Future<void> _saveSharingSessionToFirebase(List<String> guardians) async {
    if (_userId == null || _currentLocation == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sharing_sessions')
          .add({
        'guardians': guardians,
        'location': GeoPoint(_currentLocation!.latitude!, _currentLocation!.longitude!),
        'method': _sharingMethod,
        'duration': _selectedDuration,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      print('✅ Sharing session saved');
    } catch (e) {
      print('Error saving sharing session: $e');
    }
  }

  void _stopLocationSharing() {
    setState(() {
      _isSharingLocation = false;
    });

    if (mounted) {
      _showSnackBar('Location sharing stopped', isError: true);
    }
  }

  String _getSharingMethodName() {
    switch (_sharingMethod) {
      case 'sms':
        return 'SMS';
      case 'whatsapp':
        return 'WhatsApp';
      case 'email':
        return 'Email';
      default:
        return 'SMS';
    }
  }

  String createLocationMessage() {
    if (_currentLocation == null) return '';

    String googleMapsLink = 'https://www.google.com/maps?q=${_currentLocation!.latitude},${_currentLocation!.longitude}';
    String appleMapsLink = 'http://maps.apple.com/?q=${_currentLocation!.latitude},${_currentLocation!.longitude}';
    
    return '''
📍 My Current Location:
• Latitude: ${_currentLocation!.latitude!.toStringAsFixed(6)}
• Longitude: ${_currentLocation!.longitude!.toStringAsFixed(6)}
• Accuracy: ${_currentLocation!.accuracy?.toStringAsFixed(2) ?? 'Unknown'} meters

🗺️ View on Maps:
• Google Maps: $googleMapsLink
• Apple Maps: $appleMapsLink

⏰ Sharing for: $_selectedDuration
🕐 Time: ${DateTime.now().toString().substring(0, 16)}

🔐 Sent from SafeHer Safety App
''';
  }

  Future<void> _sendLocationToGuardian(String contact, String name, String message) async {
    try {
      Uri uri;
      
      if (_sharingMethod == 'sms') {
        uri = Uri(
          scheme: 'sms',
          path: contact.replaceAll(' ', ''),
          queryParameters: {'body': message},
        );
      } else if (_sharingMethod == 'whatsapp') {
        String cleanNumber = contact.replaceAll(' ', '').replaceAll('+', '');
        uri = Uri(
          scheme: 'https',
          host: 'wa.me',
          path: cleanNumber,
          queryParameters: {'text': message},
        );
      } else if (_sharingMethod == 'email') {
        uri = Uri(
          scheme: 'mailto',
          path: contact,
          queryParameters: {
            'subject': 'SafeHer - Live Location Share',
            'body': message,
          },
        );
      } else {
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ $name: ${_sharingMethod.toUpperCase()} opened');
      } else {
        print('❌ Cannot launch ${_sharingMethod.toUpperCase()} for $name');
        if (mounted) {
          _showSnackBar('Cannot open ${_getSharingMethodName()} for $name', isError: true);
        }
      }
    } catch (e) {
      print('Error sending $_sharingMethod: $e');
    }
  }

  void _showMessagePreview() {
    if (_currentLocation == null) {
      _showSnackBar('Please wait for location to load');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              _sharingMethod == 'sms' ? Icons.sms :
              _sharingMethod == 'whatsapp' ? Icons.chat :
              Icons.email,
              color: const Color(0xFF6B4CE6),
            ),
            const SizedBox(width: 12),
            const Text(
              'Message Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sharing via: ${_getSharingMethodName()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B4CE6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  createLocationMessage(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This message will be sent to selected guardians.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startLocationSharing();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Share Now'),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdateTime() {
    if (_currentLocation?.time == null) return 'Never updated';
    
    DateTime updateTime = DateTime.fromMillisecondsSinceEpoch(
      _currentLocation!.time!.toInt()
    );
    Duration difference = DateTime.now().difference(updateTime);
    
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  // ==================== ADD/REMOVE GUARDIAN ====================

  void _addNewGuardian() {
    _nameController.clear();
    _phoneController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF6B4CE6)),
            SizedBox(width: 12),
            Text(
              'Add Guardian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Guardian Name',
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6B4CE6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6B4CE6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                  ),
                  hintText: 'Enter 10-digit mobile number',
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          String name = _nameController.text.trim();
                          String phone = '+91 ${_phoneController.text.trim()}';
                          
                          _saveGuardianToFirebase(name, phone);
                          
                          _nameController.clear();
                          _phoneController.clear();
                          
                          Navigator.pop(context);
                          
                          _showSnackBar('$name added as guardian', isSuccess: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4CE6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeGuardian(int index) {
    String docId = _guardians[index]['docId'];
    String name = _guardians[index]['name'];
    
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
          'Are you sure you want to remove $name from your guardians?',
          style: const TextStyle(
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _removeGuardianFromFirebase(index, docId);
              Navigator.pop(context);
              
              _showSnackBar('$name removed from guardians', isError: true);
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

  // ==================== HELPER METHODS ====================

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

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    // Check if location is ready
    bool isLocationReady = _currentLocation != null && 
                          _locationServiceEnabled && 
                          _permissionStatus == PermissionStatus.granted;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Location Sharing',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
          if (!_isSharingLocation && isLocationReady) ...[
            IconButton(
              icon: const Icon(Icons.preview_outlined),
              onPressed: _showMessagePreview,
              tooltip: 'Preview Message',
            ),
          ],
        ],
      ),

      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF8B6CE8)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isSharingLocation 
                    ? Icons.my_location 
                    : _isLoading 
                      ? Icons.gps_fixed 
                      : isLocationReady
                        ? Icons.location_on
                        : Icons.location_off,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  _isLoading 
                    ? 'Getting Location...' 
                    : _isSharingLocation 
                      ? 'Sharing Location' 
                      : isLocationReady
                        ? 'Location Ready'
                        : 'Location Sharing Off',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isSharingLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Sharing via ${_getSharingMethodName()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (isLocationReady && !_isSharingLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Lat: ${_currentLocation!.latitude!.toStringAsFixed(4)}, Long: ${_currentLocation!.longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Location Permission Error with Action Button
                    if (_locationError != null && !_isSharingLocation) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _locationError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _requestLocationPermission,
                                icon: const Icon(Icons.location_on),
                                label: const Text('Enable Location Access'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (!_isSharingLocation) ...[
                      Row(
                        children: [
                          const Text(
                            'Share your live location with:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addNewGuardian,
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF6B4CE6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      if (_guardians.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.group_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Guardians Added',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add guardians to share your location with',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _addNewGuardian,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add Your First Guardian'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B4CE6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...List.generate(_guardians.length, (index) {
                          return _buildContactTile(
                            _guardians[index]['name'],
                            _guardians[index]['phone'],
                            _guardians[index]['selected'],
                            () => _toggleGuardianSelection(index),
                            () => _removeGuardian(index),
                            _guardians[index]['docId'],
                          );
                        }),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Sharing Method Selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.share_outlined, color: Color(0xFF6B4CE6)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Share Via',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Choose how to share your location',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSharingMethodChip('SMS', Icons.sms, 'sms'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSharingMethodChip('WhatsApp', Icons.chat, 'whatsapp'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSharingMethodChip('Email', Icons.email, 'email'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Duration Selection
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.timer_outlined, color: Color(0xFF6B4CE6)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Sharing Duration',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Choose how long you want to share your location',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: _durationOptions.map((duration) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: _buildDurationChip(
                                        duration, 
                                        duration == _selectedDuration,
                                        () => _selectDuration(duration),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Location Share Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading || _guardians.isEmpty || !isLocationReady
                            ? null
                            : _startLocationSharing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B4CE6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Start Sharing Location',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                        ),
                      ),
                    ] else ...[
                      Card(
                        color: const Color(0xFFF0E6FF),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF6B4CE6)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sharing via ${_getSharingMethodName()} with ${_guardians.where((g) => g['selected'] == true).length} guardian(s)',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Location Information Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLocationInfo('Current Location', 
                                _currentLocation != null 
                                  ? '${_currentLocation!.latitude!.toStringAsFixed(4)}, ${_currentLocation!.longitude!.toStringAsFixed(4)}'
                                  : 'Not available'),
                              _buildLocationInfo('Last Updated', _formatLastUpdateTime()),
                              _buildLocationInfo('Accuracy', 
                                _currentLocation?.accuracy != null
                                  ? '${_currentLocation!.accuracy!.toStringAsFixed(2)} meters'
                                  : 'Unknown'),
                              _buildLocationInfo('Sharing Method', _getSharingMethodName()),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _getCurrentLocation,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Update Location'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B4CE6).withOpacity(0.1),
                                    foregroundColor: const Color(0xFF6B4CE6),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Stop Sharing Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _stopLocationSharing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Stop Sharing Location',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(String name, String phone, bool isSelected, 
                         VoidCallback onChanged, VoidCallback onDelete, String guardianId) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF6B4CE6),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Text(phone),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) => onChanged(),
                activeColor: const Color(0xFF6B4CE6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: onDelete,
              tooltip: 'Remove Guardian',
              iconSize: 20,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDurationChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF6B4CE6) 
              : const Color(0xFF6B4CE6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF6B4CE6) 
                : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B4CE6),
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSharingMethodChip(String label, IconData icon, String value) {
    bool isSelected = _sharingMethod == value;
    return GestureDetector(
      onTap: () => _selectSharingMethod(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B4CE6) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF6B4CE6),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF2D3142),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}