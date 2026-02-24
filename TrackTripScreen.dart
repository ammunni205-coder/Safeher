import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'live_tracking_screen.dart';

class TrackTripScreen extends StatefulWidget {
  final String? userId;
  const TrackTripScreen({super.key, this.userId});

  @override
  State<TrackTripScreen> createState() => _TrackTripScreenState();
}

class _TrackTripScreenState extends State<TrackTripScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  latlong2.LatLng? _currentLocation;
  bool _isLoading = true;
  String? _userName;

  List<Map<String, dynamic>> _contacts = [];
  final Set<Map<String, dynamic>> _selectedContacts = {};
  String _selectedDuration = '1 hour';

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _userId = widget.userId ?? _auth.currentUser?.uid;
    if (_userId == null) {
      Navigator.pop(context);
      return;
    }

    await _getCurrentLocation();
    await _loadUserProfile();
    await _loadContacts();
    setState(() => _isLoading = false);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = latlong2.LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(_userId!).get();
      if (doc.exists) {
        _userName = doc.data()?['name'] ?? 'Someone';
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> _loadContacts() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('trusted_contacts')
          .get();
      setState(() {
        _contacts = snap.docs.map((doc) {
          final data = doc.data();
          return {'id': doc.id, ...data};
        }).toList();
      });
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  // ---------- ADD CONTACT USING EMAIL ----------
  Future<void> _addContact() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final houseController = TextEditingController();
    final relationController = TextEditingController();
    final emailController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Trusted Neighbour'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone *')),
              TextField(controller: houseController, decoration: const InputDecoration(labelText: 'House/Flat No *')),
              TextField(controller: relationController, decoration: const InputDecoration(labelText: 'Relationship *')),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (registered with SafeHer) *',
                  helperText: 'Enter the email they use to log in',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  phoneController.text.isEmpty ||
                  houseController.text.isEmpty ||
                  relationController.text.isEmpty ||
                  emailController.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }

              try {
                final querySnapshot = await _firestore
                    .collection('users')
                    .where('email', isEqualTo: emailController.text.trim())
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No user found with that email. They must register first.')),
                  );
                  return;
                }

                final contactUid = querySnapshot.docs.first.id;
                Navigator.pop(ctx, {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'house': houseController.text,
                  'relationship': relationController.text,
                  'userId': contactUid,
                  'email': emailController.text.trim(),
                });
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && _userId != null) {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('trusted_contacts')
          .add(result);
      setState(() {
        _contacts.add({'id': docRef.id, ...result});
      });
    }
  }

  void _showSelectSheet() {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Share your real‑time location',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Tap to select', style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _contacts.length,
                  itemBuilder: (ctx, index) {
                    final contact = _contacts[index];
                    final isSelected = _selectedContacts.contains(contact);
                    return CheckboxListTile(
                      title: Text(contact['name']),
                      subtitle: Text(contact['phone']),
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected!) {
                            _selectedContacts.add(contact);
                          } else {
                            _selectedContacts.remove(contact);
                          }
                        });
                      },
                      activeColor: const Color(0xFF6B4CE6),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Your message',
                    hintText: 'e.g., Going to a party',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Share your real‑time location for',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildDurationChip('1 hour'),
                    const SizedBox(width: 8),
                    _buildDurationChip('3 hours'),
                    const SizedBox(width: 8),
                    _buildDurationChip('Always'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedContacts.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select at least one contact')),
                        );
                        return;
                      }
                      if (messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a message')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _startTracking(messageController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4CE6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(String label) {
    final isSelected = _selectedDuration == label;
    return Expanded(
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedDuration = label),
        selectedColor: const Color(0xFF6B4CE6).withOpacity(0.2),
        checkmarkColor: const Color(0xFF6B4CE6),
      ),
    );
  }

  Future<void> _startTracking(String message) async {
    if (_currentLocation == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          userId: _userId!,
          userName: _userName ?? 'Someone',
          contacts: _selectedContacts.toList(),
          duration: _selectedDuration,
          message: message,
          initialLocation: _currentLocation!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track My Trip'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentLocation!,
                zoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safeher.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4CE6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6B4CE6).withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            const Center(child: Text('Getting location...')),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your Trusted Contacts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _contacts.length + 1,
                      itemBuilder: (ctx, index) {
                        if (index == _contacts.length) {
                          return _buildAddAvatar();
                        }
                        final contact = _contacts[index];
                        final isSelected = _selectedContacts.contains(contact);
                        return _buildContactAvatar(contact, isSelected);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSelectSheet,
                        icon: const Icon(Icons.location_on, size: 28),
                        label: const Text('Track Me', style: TextStyle(fontSize: 20)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B4CE6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAvatar(Map<String, dynamic> contact, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedContacts.remove(contact);
          } else {
            _selectedContacts.add(contact);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isSelected ? const Color(0xFF6B4CE6) : Colors.grey[300],
              child: Text(
                contact['name'][0].toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contact['name'].split(' ').first,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF6B4CE6) : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAvatar() {
    return GestureDetector(
      onTap: _addContact,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.add, color: Color(0xFF6B4CE6)),
            ),
            const SizedBox(height: 4),
            const Text('Add', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}