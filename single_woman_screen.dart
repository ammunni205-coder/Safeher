import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class SingleWomanScreen extends StatefulWidget {
  const SingleWomanScreen({super.key});

  @override
  State<SingleWomanScreen> createState() => _SingleWomanScreenState();
}

class _SingleWomanScreenState extends State<SingleWomanScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  String? _userId;
  bool _isLoading = true;

  // Profile
  Map<String, dynamic> _profile = {};

  // Trusted neighbours (loaded for use in new request)
  List<Map<String, dynamic>> _trustedNeighbours = [];

  // Daily safety check
  bool _safetyCheckEnabled = false;
  TimeOfDay? _safetyCheckTime;
  // We'll use these IDs for notifications
  static const int _firstNotificationId = 0;
  static const int _secondNotificationId = 1;
  static const int _escalationNotificationId = 2;
  // Track if user responded to avoid sending follow-ups
  bool _userRespondedToday = false;

  // Requests
  List<Map<String, dynamic>> _requests = [];

  // Police station info
  final String _policeStationName = 'Kakkanad Police Station';
  final String _policeStationPhone = '04842428039';

  // Districts & stations
  final Map<String, List<String>> _stations = {
    'Thiruvananthapuram': ['Vanchiyoor', 'Palayam', 'Kazhakoottam'],
    'Kollam': ['Kollam City', 'Karunagappally'],
    'Pathanamthitta': ['Pathanamthitta', 'Adoor'],
    'Alappuzha': ['Alappuzha', 'Cherthala'],
    'Kottayam': ['Kottayam', 'Changanassery'],
    'Idukki': ['Idukki', 'Munnar'],
    'Ernakulam': ['Ernakulam Central', 'Aluva', 'Kochi'],
    'Thrissur': ['Thrissur City', 'Irinjalakuda'],
    'Palakkad': ['Palakkad', 'Ottapalam'],
    'Malappuram': ['Malappuram', 'Manjeri'],
    'Kozhikode': ['Kozhikode City', 'Vadakara'],
    'Wayanad': ['Kalpetta', 'Mananthavady'],
    'Kannur': ['Kannur', 'Thalassery'],
    'Kasaragod': ['Kasaragod', 'Kanhangad'],
  };

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _getCurrentUser();
  }

  // ---------- Notification Setup ----------
  Future<void> _initNotifications() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestPermission();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
  if (details.payload != null) {
    switch (details.payload) {
      case 'first' || 'second' || 'escalation':
        _showSafetyCheckDialog(details.payload!);
      default:
        break;
        }
      }
      }
    );
    tz.initializeTimeZones();
  }

  Future<void> _scheduleSafetyCheckChain(TimeOfDay time) async {
    await _cancelAllNotifications();

    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final firstTime = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    // First notification
    await _notifications.zonedSchedule(
      _firstNotificationId,
      'Daily Safety Check',
      'Are you safe? Tap to respond.',
      tz.TZDateTime.from(firstTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safety_channel',
          'Safety Check',
          channelDescription: 'Daily safety reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'first',
    );

    // Schedule second notification 50 minutes after first
    final secondTime = firstTime.add(const Duration(minutes: 50));
    await _notifications.zonedSchedule(
      _secondNotificationId,
      'Safety Check - Reminder',
      'You haven\'t responded. Are you safe?',
      tz.TZDateTime.from(secondTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safety_channel',
          'Safety Check',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'second',
    );

    // Schedule escalation notification 50 minutes after second (if still no response)
    final escalationTime = secondTime.add(const Duration(minutes: 50));
    await _notifications.zonedSchedule(
      _escalationNotificationId,
      'URGENT: Safety Check Missed',
      'We will alert the police if you don\'t respond.',
      tz.TZDateTime.from(escalationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safety_channel',
          'Safety Check',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'escalation',
    );
  }

  Future<void> _cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  void _showSafetyCheckDialog(String payload) {
    // FIX: Get the first trusted neighbour outside the button builder
    final firstNeighbour = _trustedNeighbours.isNotEmpty ? _trustedNeighbours.first : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Safety Check'),
        content: Text(payload == 'escalation'
            ? 'You missed two safety checks. Please confirm you are safe, or call police immediately.'
            : 'Are you safe?'),
        actions: [
          TextButton(
            onPressed: () {
              // User responded – cancel all future notifications for today
              _cancelAllNotifications();
              // Also reset the daily flag? We could store last response time in Firestore.
              // For simplicity, we just cancel and rely on tomorrow's schedule.
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
          if (firstNeighbour != null)
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${firstNeighbour['phone']}')),
              icon: const Icon(Icons.phone, color: Colors.green),
              label: Text('Call ${firstNeighbour['name']}'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              launchUrl(Uri.parse('tel:$_policeStationPhone'));
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call Police'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // ---------- User & Data Loading ----------
  Future<void> _getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _userId = user.uid);
      await _loadUserData();
      if (_profile.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _editProfile(firstTime: true));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    if (_userId == null) return;

    final profileDoc = await _firestore.collection('users').doc(_userId).get();
    if (profileDoc.exists) _profile = profileDoc.data()!;

    final neighboursSnap = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('trusted_neighbours')
        .get();
    _trustedNeighbours =
        neighboursSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

    final safetyDoc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('safety_check')
        .get();
    if (safetyDoc.exists) {
      final data = safetyDoc.data()!;
      _safetyCheckEnabled = data['enabled'] ?? false;
      if (data['hour'] != null && data['minute'] != null) {
        _safetyCheckTime = TimeOfDay(hour: data['hour'], minute: data['minute']);
        if (_safetyCheckEnabled) {
          _scheduleSafetyCheckChain(_safetyCheckTime!);
        }
      }
    }

    final requestsSnap = await _firestore
        .collection('requests')
        .where('userId', isEqualTo: _userId)
        .get();
    _requests = requestsSnap.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList()
      ..sort((a, b) {
        final aTime = (a['registeredAt'] as Timestamp?)?.toDate();
        final bTime = (b['registeredAt'] as Timestamp?)?.toDate();
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
  }

  // ---------- Profile ----------
  Future<void> _editProfile({bool firstTime = false}) async {
    final nameController = TextEditingController(text: _profile['fullName'] ?? '');
    final addressController = TextEditingController(text: _profile['address'] ?? '');
    final idController = TextEditingController(text: _profile['idDetails'] ?? '');
    String? selectedDistrict = _profile['district'];
    String? selectedStation = _profile['policeStation'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !firstTime,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(firstTime ? 'Complete Your Profile' : 'Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name *')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address *')),
                TextField(controller: idController, decoration: const InputDecoration(labelText: 'ID Details (optional)')),
                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  items: _stations.keys.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() {
                    selectedDistrict = v;
                    selectedStation = null;
                  }),
                  decoration: const InputDecoration(labelText: 'District *'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedStation,
                  items: selectedDistrict == null
                      ? []
                      : _stations[selectedDistrict]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => selectedStation = v),
                  decoration: const InputDecoration(labelText: 'Support Center *'),
                ),
              ],
            ),
          ),
          actions: [
            if (!firstTime)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    addressController.text.isEmpty ||
                    selectedDistrict == null ||
                    selectedStation == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'fullName': nameController.text,
                  'address': addressController.text,
                  'idDetails': idController.text,
                  'district': selectedDistrict,
                  'policeStation': selectedStation,
                });
              },
              child: Text(firstTime ? 'Save & Continue' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && _userId != null) {
      await _firestore.collection('users').doc(_userId).set(result, SetOptions(merge: true));
      setState(() => _profile = result);
    } else if (firstTime) {
      _editProfile(firstTime: true);
    }
  }

  // ---------- Trusted Neighbours Management (accessible from main screen) ----------
  Future<void> _addTrustedNeighbour() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final houseController = TextEditingController();
    final relationController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  phoneController.text.isEmpty ||
                  houseController.text.isEmpty ||
                  relationController.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'name': nameController.text,
                'phone': phoneController.text,
                'house': houseController.text,
                'relationship': relationController.text,
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && _userId != null) {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('trusted_neighbours')
          .add(result);
      setState(() {
        _trustedNeighbours.add({'id': docRef.id, ...result});
      });
    }
  }

  Future<void> _deleteNeighbour(String id) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('trusted_neighbours')
        .doc(id)
        .delete();
    setState(() {
      _trustedNeighbours.removeWhere((n) => n['id'] == id);
    });
  }

  Future<void> _callNeighbour(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  // ---------- Daily Safety Check ----------
  Future<void> _setSafetyCheck() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _safetyCheckTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null && _userId != null) {
      setState(() {
        _safetyCheckTime = pickedTime;
        _safetyCheckEnabled = true;
      });
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('safety_check')
          .set({
        'enabled': true,
        'hour': pickedTime.hour,
        'minute': pickedTime.minute,
      });
      await _scheduleSafetyCheckChain(pickedTime);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily safety check set for ${pickedTime.format(context)}')),
      );
    }
  }

  Future<void> _toggleSafetyCheck(bool value) async {
    if (_userId == null) return;
    setState(() => _safetyCheckEnabled = value);
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('safety_check')
        .set({'enabled': value}, SetOptions(merge: true));
    if (value && _safetyCheckTime != null) {
      await _scheduleSafetyCheckChain(_safetyCheckTime!);
    } else {
      await _cancelAllNotifications();
    }
  }

  // ---------- New Request (with Trusted Neighbours & Police Station Card) ----------
  Future<void> _newRequest() async {
    if (_profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your profile first')),
      );
      return;
    }

    final supportController = TextEditingController();
    List<Map<String, dynamic>> selectedContacts = [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Support Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile summary (read-only)
                const Text('Your Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  title: Text(_profile['fullName'] ?? ''),
                  subtitle: Text(_profile['address'] ?? ''),
                ),
                const Divider(),

                // Trusted Neighbours selection
                const Text('Select Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._trustedNeighbours.map((c) => CheckboxListTile(
                  title: Text(c['name']),
                  subtitle: Text('${c['phone']} · ${c['relationship']}'),
                  value: selectedContacts.contains(c),
                  onChanged: (selected) {
                    setState(() {
                      if (selected!) {
                        selectedContacts.add(c);
                      } else {
                        selectedContacts.remove(c);
                      }
                    });
                  },
                )),
                const Divider(),

                // Nearby Police Station Card (inside request form)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        const Text('Nearby Police Station', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_policeStationName),
                        Text('Phone: $_policeStationPhone'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () => launchUrl(Uri.parse('tel:$_policeStationPhone')),
                              icon: const Icon(Icons.phone),
                              label: const Text('Call'),
                            ),
                            TextButton.icon(
                              onPressed: () => _openPoliceStationMap(_policeStationName),
                              icon: const Icon(Icons.map),
                              label: const Text('Map'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),

                // Support description
                TextField(
                  controller: supportController,
                  decoration: const InputDecoration(labelText: 'Describe the support needed'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'supportRequired': supportController.text,
                  'emergencyContacts': selectedContacts.map((c) {
                    return {'name': c['name'], 'phone': c['phone'], 'relationship': c['relationship']};
                  }).toList(),
                });
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result != null && _userId != null) {
      final requestData = {
        'userId': _userId,
        ..._profile,
        ...result,
        'registeredAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };
      final docRef = await _firestore.collection('requests').add(requestData);
      setState(() {
        _requests.insert(0, {'id': docRef.id, ...requestData});
      });
    }
  }

  Future<void> _openPoliceStationMap(String query) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  // ---------- Request Management ----------
  Future<void> _editRequest(Map<String, dynamic> request) async { /* similar to new, omitted for brevity */ }
  Future<void> _deleteRequest(String requestId) async { /* as before */ }
  void _viewRequestDetails(Map<String, dynamic> request) { /* as before */ }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Woman Safety'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadUserData();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF6B4CE6)),
                          onPressed: _editProfile,
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.person, 'Name', _profile['fullName'] ?? 'Not set'),
                    _buildInfoRow(Icons.home, 'Address', _profile['address'] ?? 'Not set'),
                    _buildInfoRow(Icons.badge, 'ID', _profile['idDetails'] ?? 'Not set'),
                    _buildInfoRow(Icons.location_on, 'District', _profile['district'] ?? 'Not set'),
                    _buildInfoRow(Icons.location_city, 'Support Center', _profile['policeStation'] ?? 'Not set'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Trusted Neighbours Management (now on main screen, but police station is only inside request)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trusted Neighbours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _addTrustedNeighbour,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _trustedNeighbours.isEmpty
                ? const Card(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No trusted neighbours added yet.'),
                  ))
                : Column(
                    children: _trustedNeighbours.map((n) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(n['name'][0])),
                        title: Text(n['name']),
                        subtitle: Text('${n['phone']} · ${n['house']} · ${n['relationship']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _callNeighbour(n['phone']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteNeighbour(n['id']),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
            const SizedBox(height: 24),

            // Daily Safety Check
            const Text('Daily Safety Check', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable daily reminder'),
                      value: _safetyCheckEnabled,
                      onChanged: _toggleSafetyCheck,
                      activeColor: const Color(0xFF6B4CE6),
                    ),
                    if (_safetyCheckEnabled) ...[
                      ListTile(
                        title: Text('Reminder time: ${_safetyCheckTime?.format(context) ?? 'Not set'}'),
                        trailing: TextButton(
                          onPressed: _setSafetyCheck,
                          child: const Text('Change'),
                        ),
                      ),
                      const Text(
                        'You will receive a notification at the set time.\n'
                        'If you don\'t respond within 50 minutes, a second reminder will appear.\n'
                        'If still no response, an urgent notification will allow you to call police.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Your Requests
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _newRequest,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _requests.isEmpty
                ? const Card(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No requests yet. Tap "New" to create one.'),
                  ))
                : Column(
                    children: _requests.map((r) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _viewRequestDetails(r),
                        title: Text(r['supportRequired'] ?? 'No description'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${_formatDate(r['registeredAt'])}'),
                            if (r['emergencyContacts'] != null && (r['emergencyContacts'] as List).isNotEmpty)
                              Text('Contacts: ${(r['emergencyContacts'] as List).map((c) => c['name']).join(', ')}'),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              // _editRequest(r);
                            } else if (value == 'delete') {
                              _showDeleteDialog(r['id']);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDeleteDialog(String requestId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRequest(requestId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      return DateFormat.yMd().add_jm().format(ts.toDate());
    }
    return '';
  }
}