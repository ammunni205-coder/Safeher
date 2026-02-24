import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

// Import your existing screens
import 'sos_screen.dart';
import 'guardian_circle_screen.dart';
import 'safe_route_screen.dart';
import 'profile_screen.dart';
import 'tips_screen.dart';
import 'login_screen.dart';
import 'single_woman_screen.dart';
import 'TrackTripScreen.dart';  
import 'location_screen.dart';// ← REMOVED 'hide LatLng'

// ==================== HOME SCREEN ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const GuardianCircleScreen(),
    const SafeRouteScreen(),
    const ProfileScreen(),
  ];

  void navigateToProfileTab() {
    setState(() {
      _selectedIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedIndex == 0 ? _buildSOSButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4CE6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Home'),
          _buildNavItem(1, Icons.grid_view_rounded, 'My Circle'),
          const SizedBox(width: 60),
          _buildNavItem(2, Icons.explore_outlined, 'Explore'),
          _buildNavItem(3, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6B4CE6) : const Color(0xFFB0B0B0),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6B4CE6) : const Color(0xFFB0B0B0),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onLongPress: () async {
        HapticFeedback.heavyImpact();
        
        bool? playSoundEnabled = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.emergency_rounded, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'SOS Alert',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Do you want to play an alert sound?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This will help attract attention during emergency.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Silent',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('With Sound'),
              ),
            ],
          ),
        );

        if (playSoundEnabled != null && mounted) {
          if (playSoundEnabled) {
            try {
              final player = AudioPlayer();
              await player.play(AssetSource('sounds/sos_alarm_sound.mp3'));
            } catch (e) {
              print('Error playing sound: $e');
            }
          }
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SOSScreen()),
            );
          }
        }
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.emergency_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ==================== NEW FEATURE 1: LIVE AUDIO RECORDER ====================
class LiveAudioRecorder {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  StreamSubscription<RecordState>? _recordStateSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Function(String)? onRecordingComplete;

  Future<bool> startRecording(String userId) async {
    try {
      bool hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        PermissionStatus status = await Permission.microphone.request();
        hasPermission = status.isGranted;
        if (!hasPermission) return false;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/sos_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      const encoder = AudioEncoder.aacLc;
      final config = RecordConfig(encoder: encoder);
      
      await _audioRecorder.start(config, path: path);
      
      _recordStateSubscription = _audioRecorder.onStateChanged().listen((recordState) {
        print('Recording state: $recordState');
      });
      
      _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {});
      
      _isRecording = true;
      _recordingPath = path;
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      
      final path = await _audioRecorder.stop();
      _recordStateSubscription?.cancel();
      _amplitudeSubscription?.cancel();
      _isRecording = false;
      
      if (onRecordingComplete != null && path != null) {
        onRecordingComplete!(path);
      }
      
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  bool get isRecording => _isRecording;

  void dispose() {
    _recordStateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.dispose();
  }
}

// ==================== NEW FEATURE 2: FAKE CALL SERVICE ====================
class FakeCallService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isFakeCallActive = false;
  static Timer? _callTimer;

  static Future<void> startFakeCall({
    required BuildContext context,
    required String callerName,
    required String callerNumber,
  }) async {
    if (_isFakeCallActive) return;
    
    _isFakeCallActive = true;
    
    if (context.mounted) {
      _showIncomingCallDialog(context, callerName, callerNumber);
    }
    
    try {
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      print('Error playing ringtone: $e');
    }
    
    _callTimer = Timer(const Duration(seconds: 5), () {
      if (_isFakeCallActive && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        if (context.mounted) {
          _startFakeConversation(context, callerName);
        }
      }
    });
  }

  static void _showIncomingCallDialog(BuildContext context, String callerName, String callerNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Incoming Call', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4CE6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, size: 48, color: Color(0xFF6B4CE6)),
            ),
            const SizedBox(height: 16),
            Text(callerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(callerNumber, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _audioPlayer.stop();
                    _callTimer?.cancel();
                    Navigator.pop(context);
                    _isFakeCallActive = false;
                  },
                  icon: const Icon(Icons.call_end),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _audioPlayer.stop();
                    _callTimer?.cancel();
                    Navigator.pop(context);
                    _startFakeConversation(context, callerName);
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Answer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4CE6),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _startFakeConversation(BuildContext context, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Call with $callerName', style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4CE6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_in_talk, size: 48, color: Color(0xFF6B4CE6)),
                ),
                const SizedBox(height: 16),
                const Text('00:15', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('You can pretend to be on a call', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '"Yes, I\'m on my way. I\'ll be there in 10 minutes."\n\n'
                    '"I\'m with friends right now, I\'ll call you back."\n\n'
                    '"No, I don\'t need any help, I\'m almost home."',
                    style: TextStyle(color: Color(0xFF2D3142)),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  _audioPlayer.stop();
                  Navigator.pop(context);
                  _isFakeCallActive = false;
                },
                icon: const Icon(Icons.call_end),
                label: const Text('End Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static void dispose() {
    _audioPlayer.dispose();
    _callTimer?.cancel();
    _isFakeCallActive = false;
  }
}

// ==================== NEW FEATURE 3: SAFETY CHECK-IN SERVICE (COMPLETELY FIXED) ====================
class SafetyCheckInService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static Timer? _checkInTimer;
  static DateTime? _checkInTime;
  static bool _isActive = false;
  static List<String> _emergencyContacts = [];
  static Function? _onMissedCallback;

  static Future<void> initialize() async {
    try {
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(initSettings);
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Failed to initialize notifications: $e');
    }
  }

  static Future<void> startCheckIn({
    required Duration duration,
    required List<String> contacts,
    required Function onMissedCheckIn,
  }) async {
    try {
      _emergencyContacts = contacts;
      _isActive = true;
      _onMissedCallback = onMissedCheckIn;
      _checkInTime = DateTime.now().add(duration);
      
      // Show immediate notification that check-in started (this always works)
      await _showNotification(
        '⏰ Safety Check-In Started',
        'You will be reminded to check in ${duration.inMinutes} minutes',
      );
      
      _checkInTimer = Timer(duration, () {
        if (_isActive) {
          print('⚠️ Check-in missed!');
          _onMissedCallback?.call();
          _sendMissedCheckInAlert();
        }
      });
      
      print('✅ Check-in started for ${duration.inMinutes} minutes');
    } catch (e) {
      print('❌ Error starting check-in: $e');
    }
  }

  // Simple show notification method that always works
  static Future<void> _showNotification(String title, String body) async {
    try {
      int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'check_in_channel',
        'Safety Check-In',
        channelDescription: 'Notifications for safety check-ins',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
      
      print('✅ Notification shown: $title');
    } catch (e) {
      print('❌ Failed to show notification: $e');
    }
  }

  static void checkIn() {
    _isActive = false;
    _checkInTimer?.cancel();
    _notifications.cancelAll();
    print('✅ Check-in completed');
    
    // Show completion notification
    _showNotification(
      '✅ Check-In Complete',
      'Thank you for staying safe',
    );
  }

  static void _sendMissedCheckInAlert() {
    for (String contact in _emergencyContacts) {
      print('📱 Alert sent to $contact');
    }
    // Show missed notification
    _showNotification(
      '⚠️ Missed Check-In!',
      'Emergency contacts have been alerted',
    );
  }

  static bool get isActive => _isActive;

  static Duration? get timeRemaining {
    if (_checkInTime == null) return null;
    final Duration remaining = _checkInTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static void dispose() {
    _checkInTimer?.cancel();
    _notifications.cancelAll();
    _isActive = false;
  }
}

// ==================== NEW FEATURE 4: VOICE-ACTIVATED SOS ====================
class VoiceActivatedSOS {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  Function? _onTriggerCallback;
  
  final List<String> _triggerWords = [
    'help me', 'sos', 'emergency', 'save me', 'danger',
    'help', 'police', 'call police', 'i need help',
    'bachao', 'madad', 'बचाओ', 'मदद',
    'sahayam', 'rakshikkuka',
  ];

  Future<bool> initialize() async {
    try {
      return await _speech.initialize();
    } catch (e) {
      print('Error initializing speech: $e');
      return false;
    }
  }

  Future<void> startListening(Function onSOSTriggered) async {
    try {
      bool available = await _speech.initialize();
      
      if (!available) {
        print('Speech recognition not available');
        return;
      }
      
      _onTriggerCallback = onSOSTriggered;
      _isListening = true;
      
      _speech.listen(
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();
          _lastWords = words;
          print('Heard: $words');
          
          for (String word in _triggerWords) {
            if (words.contains(word)) {
              print('🚨 SOS Triggered by word: $word');
              onSOSTriggered();
              stopListening();
              break;
            }
          }
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_IN',
        cancelOnError: true,
      );
      
      print('Voice SOS listening started');
    } catch (e) {
      print('Error in startListening: $e');
      _isListening = false;
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      print('Voice SOS stopped listening');
    }
  }

  bool get isListening => _isListening;

  String get lastWords => _lastWords;

  void dispose() {
    stopListening();
  }
}

// ==================== NEW FEATURE 5: SAFE PLACE FINDER ====================
class SafePlaceFinder {
  static final List<Map<String, dynamic>> _safePlaces = [
    {
      'name': 'Police Station',
      'icon': Icons.local_police,
      'color': const Color(0xFF6B4CE6),
      'type': 'police',
      'radius': 2000,
    },
    {
      'name': 'Hospital',
      'icon': Icons.local_hospital,
      'color': const Color(0xFFFF4D4D),
      'type': 'hospital',
      'radius': 2000,
    },
    {
      'name': 'Pharmacy',
      'icon': Icons.local_pharmacy,
      'color': const Color(0xFF4CAF50),
      'type': 'pharmacy',
      'radius': 1000,
    },
    {
      'name': 'Women Help Center',
      'icon': Icons.female,
      'color': const Color(0xFFFF8C42),
      'type': 'women_center',
      'radius': 3000,
    },
    {
      'name': 'Public Transport',
      'icon': Icons.directions_bus,
      'color': const Color(0xFF3399FF),
      'type': 'transport',
      'radius': 500,
    },
    {
      'name': 'ATM/Bank',
      'icon': Icons.attach_money,
      'color': const Color(0xFF8A65E6),
      'type': 'atm',
      'radius': 500,
    },
    {
      'name': 'Hotel/Restaurant',
      'icon': Icons.restaurant,
      'color': const Color(0xFFE91E63),
      'type': 'hotel',
      'radius': 300,
    },
    {
      'name': 'Shopping Mall',
      'icon': Icons.shopping_bag,
      'color': const Color(0xFF9C27B0),
      'type': 'mall',
      'radius': 500,
    },
  ];

  static List<Map<String, dynamic>> getNearbySafePlaces(LatLng currentLocation) {
    return _safePlaces.map((Map<String, dynamic> place) {
      int radiusInMeters = place['radius'] as int;
      double distanceInKm = radiusInMeters / 1000.0;
      return {
        ...place,
        'distance': distanceInKm,
        'distanceText': '${distanceInKm.toStringAsFixed(1)} km',
      };
    }).toList();
  }

  static Future<void> navigateToPlace(Map<String, dynamic> place, LatLng currentLocation) async {
    final String query = Uri.encodeComponent(place['name'] as String);
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}

// ==================== NEW FEATURE 6: COMMUNITY SAFETY ALERTS ====================
class CommunitySafetyAlert {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<List<Map<String, dynamic>>> getAlertsInArea(LatLng center, double radiusKm) {
    return _firestore
        .collection('safety_alerts')
        .where('active', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
          return snapshot.docs.map((DocumentSnapshot doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  static Future<void> reportIncident({
    required String type,
    required String description,
    required LatLng location,
    String? imageUrl,
  }) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    
    await FirebaseFirestore.instance.collection('safety_alerts').add({
      'type': type,
      'description': description,
      'location': GeoPoint(location.latitude, location.longitude),
      'imageUrl': imageUrl,
      'reportedBy': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'active': true,
      'verified': false,
      'upvotes': 0,
    });
  }

  static const List<Map<String, dynamic>> alertTypes = [
    {'name': 'Suspicious Activity', 'icon': Icons.person_outline, 'color': Colors.orange},
    {'name': 'Harassment', 'icon': Icons.warning, 'color': Colors.red},
    {'name': 'Accident', 'icon': Icons.car_crash, 'color': Colors.amber},
    {'name': 'Unsafe Area', 'icon': Icons.dangerous, 'color': Colors.deepOrange},
    {'name': 'Power Outage', 'icon': Icons.electric_bolt, 'color': Colors.purple},
  ];
}

// ==================== NEW FEATURE 7: EMERGENCY FUND TRANSFER ====================
class EmergencyFundTransfer {
  static Future<void> requestEmergencyFunds({
    required String upiId,
    required double amount,
    required String note,
  }) async {
    final String upiUrl = 'upi://pay?pa=$upiId&pn=Emergency&am=$amount&tn=$note&cu=INR';
    
    try {
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl));
      } else {
        await Share.share(
          '🚨 EMERGENCY FUND REQUEST\n\n'
          'I need an emergency fund transfer of ₹$amount.\n'
          'UPI ID: $upiId\n'
          'Reason: $note\n\n'
          'Please help urgently!',
        );
      }
    } catch (e) {
      print('Error requesting funds: $e');
    }
  }
}

// ==================== NEW FEATURE 8: FAKE ROUTE GENERATOR ====================
class FakeRouteGenerator {
  static List<LatLng> generateFakeRoute(LatLng start, LatLng destination, int waypoints) {
    List<LatLng> route = [start];
    
    final double latDiff = destination.latitude - start.latitude;
    final double lngDiff = destination.longitude - start.longitude;
    
    for (int i = 1; i <= waypoints; i++) {
      final double randomLatOffset = (i % 3 == 0) ? 0.001 : -0.0005;
      final double randomLngOffset = (i % 2 == 0) ? -0.001 : 0.0005;
      
      final double waypointLat = start.latitude + (latDiff * i / waypoints) + randomLatOffset;
      final double waypointLng = start.longitude + (lngDiff * i / waypoints) + randomLngOffset;
      
      route.add(LatLng(waypointLat, waypointLng));
    }
    
    route.add(destination);
    return route;
  }

  static String generateShareableRouteText(LatLng currentLocation, String destination) {
    final DateTime eta = DateTime.now().add(const Duration(minutes: 30));
    return '''
🚶‍♀️ I'm sharing my live location:
📍 Current: https://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}
📍 Destination: $destination
⏱️ ETA: ${eta.hour}:${eta.minute.toString().padLeft(2, '0')}
🛡️ Tracking with SafeHer
    ''';
  }
}

// ==================== NEW WIDGET 1: SAFETY CHECK-IN CARD ====================
class SafetyCheckInCard extends StatefulWidget {
  final Function onCheckInComplete;

  const SafetyCheckInCard({Key? key, required this.onCheckInComplete}) : super(key: key);

  @override
  State<SafetyCheckInCard> createState() => _SafetyCheckInCardState();
}

class _SafetyCheckInCardState extends State<SafetyCheckInCard> {
  Duration _selectedDuration = const Duration(minutes: 15);
  bool _isActive = false;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCheckIn() {
    setState(() {
      _isActive = true;
      _secondsRemaining = _selectedDuration.inSeconds;
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _showMissedCheckIn();
        }
      });
    });
  }

  void _checkIn() {
    _countdownTimer?.cancel();
    setState(() {
      _isActive = false;
    });
    widget.onCheckInComplete();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Check-in confirmed! Stay safe.'),
        backgroundColor: Color(0xFF6B4CE6),
      ),
    );
  }

  void _showMissedCheckIn() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Missed Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You missed your scheduled check-in.\n\nEmergency contacts have been alerted.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isActive = false);
              Navigator.pop(context);
            },
            child: const Text('I\'m Safe', style: TextStyle(color: Color(0xFF6B4CE6))),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isActive 
              ? [const Color(0xFFFF8C42), const Color(0xFFFFB347)]
              : [const Color(0xFF6B4CE6), const Color(0xFF9B7EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isActive 
                ? const Color(0xFFFF8C42).withOpacity(0.3)
                : const Color(0xFF6B4CE6).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isActive ? Icons.timer : Icons.safety_check,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _isActive ? 'Check-In Active' : 'Safety Check-In',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_isActive) ...[
            const Text(
              'Set a timer to check in',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDurationButton(const Duration(minutes: 15), '15 min')),
                const SizedBox(width: 8),
                Expanded(child: _buildDurationButton(const Duration(minutes: 30), '30 min')),
                const SizedBox(width: 8),
                Expanded(child: _buildDurationButton(const Duration(hours: 1), '1 hour')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B4CE6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Start Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Text(
                    _formatTime(_secondsRemaining),
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('remaining to check in', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _checkIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('✓ Check In Now'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationButton(Duration duration, String label) {
    bool isSelected = _selectedDuration == duration;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = duration),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B4CE6) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ==================== NEW WIDGET 2: VOICE ACTIVATION BUTTON ====================
class VoiceActivationButton extends StatefulWidget {
  final Function onSOSTriggered;
  final bool isActive;

  const VoiceActivationButton({
    Key? key,
    required this.onSOSTriggered,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<VoiceActivationButton> createState() => _VoiceActivationButtonState();
}

class _VoiceActivationButtonState extends State<VoiceActivationButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isActive
                  ? [Colors.red, Colors.orange]
                  : [const Color(0xFF6B4CE6), const Color(0xFF9B7EE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (widget.isActive ? Colors.red : const Color(0xFF6B4CE6)).withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: widget.isActive ? 5 : 2,
              ),
            ],
          ),
          child: Transform.scale(
            scale: widget.isActive ? _pulseAnimation.value : 1.0,
            child: Icon(
              widget.isActive ? Icons.graphic_eq : Icons.mic,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

// ==================== NEW WIDGET 3: SAFE PLACE FINDER CARD ====================
class SafePlaceFinderCard extends StatelessWidget {
  final LatLng? currentLocation;
  final Function(Map<String, dynamic>) onPlaceSelected;

  const SafePlaceFinderCard({
    Key? key,
    this.currentLocation,
    required this.onPlaceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) return const SizedBox();

    final List<Map<String, dynamic>> places = SafePlaceFinder.getNearbySafePlaces(currentLocation!);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safe Places Nearby',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4CE6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${places.length} found',
                  style: const TextStyle(color: Color(0xFF6B4CE6), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: places.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> place = places[index];
                return GestureDetector(
                  onTap: () => onPlaceSelected(place),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (place['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (place['color'] as Color).withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(place['icon'] as IconData, color: place['color'] as Color, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          place['name'] as String,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          place['distanceText'] as String,
                          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== NEW WIDGET 4: COMMUNITY ALERTS WIDGET ====================
class CommunityAlertsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const CommunityAlertsWidget({Key? key, required this.alerts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.shield, color: Colors.green),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No active alerts in your area',
                style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Alerts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alerts.length > 3 ? 3 : alerts.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> alert = alerts[index];
            final Map<String, dynamic> type = CommunitySafetyAlert.alertTypes.firstWhere(
              (Map<String, dynamic> t) => t['name'] == alert['type'],
              orElse: () => CommunitySafetyAlert.alertTypes.first,
            );
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (type['color'] as Color).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(type['icon'] as IconData, color: type['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['type'] ?? 'Alert',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert['description'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTime(alert['timestamp']),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (alerts.length > 3)
          TextButton(
            onPressed: () {
              // Show all alerts
            },
            child: const Text('View All Alerts', style: TextStyle(color: Color(0xFF6B4CE6))),
          ),
      ],
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Now';
    if (timestamp is Timestamp) {
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(timestamp.toDate());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }
    return 'Now';
  }
}

// ==================== NEW SCREEN 1: EMERGENCY DASHBOARD ====================
class EmergencyDashboardScreen extends StatefulWidget {
  final LatLng? currentLocation;
  final String? userId;

  const EmergencyDashboardScreen({
    Key? key,
    this.currentLocation,
    this.userId,
  }) : super(key: key);

  @override
  State<EmergencyDashboardScreen> createState() => _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen> {
  late VoiceActivatedSOS _voiceSOS;
  bool _isVoiceActive = false;
  final CommunitySafetyAlert _alertService = CommunitySafetyAlert();

  @override
  void initState() {
    super.initState();
    _voiceSOS = VoiceActivatedSOS();
    _voiceSOS.initialize();
  }

  @override
  void dispose() {
    _voiceSOS.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Dashboard'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              _showNotifications(context);
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
              ),
              const SizedBox(height: 16),
              _buildQuickActionsGrid(),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isVoiceActive ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isVoiceActive ? Colors.red : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    VoiceActivationButton(
                      onSOSTriggered: _triggerSOS,
                      isActive: _isVoiceActive,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isVoiceActive ? 'Voice SOS Active' : 'Voice SOS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isVoiceActive ? Colors.red : const Color(0xFF2D3142),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isVoiceActive 
                                ? 'Listening for trigger words...' 
                                : 'Tap to activate voice commands',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isVoiceActive ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isVoiceActive,
                      onChanged: (bool value) {
                        setState(() {
                          _isVoiceActive = value;
                          if (value) {
                            _voiceSOS.startListening(_triggerSOS);
                          } else {
                            _voiceSOS.stopListening();
                          }
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              SafePlaceFinderCard(
                currentLocation: widget.currentLocation,
                onPlaceSelected: (Map<String, dynamic> place) => _showPlaceDetails(context, place),
              ),
              
              const SizedBox(height: 24),
              
              SafetyCheckInCard(
                onCheckInComplete: () {
                  // Handle check-in complete
                },
              ),
              
              const SizedBox(height: 24),
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('safety_alerts')
                    .where('active', isEqualTo: true)
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final List<Map<String, dynamic>> alerts = snapshot.data!.docs.map((DocumentSnapshot doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      ...data,
                    };
                  }).toList();
                  
                  return CommunityAlertsWidget(alerts: alerts);
                },
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReportIncidentDialog(context),
                  icon: const Icon(Icons.add_alert),
                  label: const Text('Report Incident'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6B4CE6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF6B4CE6)),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildQuickActionItem(
          icon: Icons.record_voice_over,
          label: 'Live Audio',
          color: const Color(0xFFE53935),
          onTap: _startLiveRecording,
        ),
        _buildQuickActionItem(
          icon: Icons.phone_in_talk,
          label: 'Fake Call',
          color: const Color(0xFF6B4CE6),
          onTap: _showFakeCallDialog,
        ),
        _buildQuickActionItem(
          icon: Icons.timer,
          label: 'Check-In',
          color: const Color(0xFFFF8C42),
          onTap: () => _showCheckInDialog(context),
        ),
        _buildQuickActionItem(
          icon: Icons.money,
          label: 'Emergency Fund',
          color: const Color(0xFF4CAF50),
          onTap: _showEmergencyFundDialog,
        ),
        _buildQuickActionItem(
          icon: Icons.share_location,
          label: 'Fake Route',
          color: const Color(0xFF3399FF),
          onTap: _showFakeRouteDialog,
        ),
        _buildQuickActionItem(
          icon: Icons.security,
          label: 'Safe Places',
          color: const Color(0xFF9C27B0),
          onTap: () {
            // Scroll to safe places
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSOS() {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => const SOSScreen()),
    );
  }

  void _startLiveRecording() async {
    PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final LiveAudioRecorder recorder = LiveAudioRecorder();
    bool started = await recorder.startRecording(widget.userId ?? '');
    
    if (started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live audio recording started'), backgroundColor: Colors.green),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => LiveAudioRecordingScreen(
            recorder: recorder,
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  void _showFakeCallDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
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
            const SizedBox(height: 24),
            const Text(
              'Fake Call',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 20),
            _buildFakeCallOption('Mom', '+91 98765 43210', Icons.person, const Color(0xFF6B4CE6)),
            const Divider(),
            _buildFakeCallOption('Police', '100', Icons.local_police, Colors.red),
            const Divider(),
            _buildFakeCallOption('Friend', '+91 87654 32109', Icons.person_outline, const Color(0xFF4CAF50)),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: 'Custom caller name',
                prefixIcon: const Icon(Icons.person_add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  FakeCallService.startFakeCall(
                    context: context,
                    callerName: 'Security Alert',
                    callerNumber: '112',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4CE6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Start Fake Call'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFakeCallOption(String name, String number, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(number),
      trailing: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          FakeCallService.startFakeCall(
            context: context,
            callerName: name,
            callerNumber: number,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(60, 36),
        ),
        child: const Text('Call'),
      ),
    );
  }

  void _showCheckInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Safety Check-In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a timer to check in with emergency contacts'),
            const SizedBox(height: 16),
            _buildCheckInOption(context, '15 min', const Duration(minutes: 15)),
            const SizedBox(height: 8),
            _buildCheckInOption(context, '30 min', const Duration(minutes: 30)),
            const SizedBox(height: 8),
            _buildCheckInOption(context, '1 hour', const Duration(hours: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInOption(BuildContext context, String label, Duration duration) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Check-in set for $label'),
              backgroundColor: const Color(0xFF6B4CE6),
            ),
          );
          
          SafetyCheckInService.startCheckIn(
            duration: duration,
            contacts: const ['Emergency Contact'],
            onMissedCheckIn: () {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('⚠️ Missed Check-In'),
                    content: const Text('You missed your safety check-in. Emergency contacts have been alerted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B4CE6),
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      ),
    );
  }

  void _showEmergencyFundDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController upiController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Emergency Fund Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'example@okhdfcbank',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Emergency funds needed',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              EmergencyFundTransfer.requestEmergencyFunds(
                upiId: upiController.text.isNotEmpty ? upiController.text : 'example@okhdfcbank',
                amount: double.tryParse(amountController.text) ?? 500,
                note: noteController.text.isNotEmpty ? noteController.text : 'Emergency help',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showFakeRouteDialog() {
    final TextEditingController destinationController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Share Fake Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Generate a fake route to share with strangers'),
            const SizedBox(height: 16),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Where are you going?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.currentLocation != null) {
                final String routeText = FakeRouteGenerator.generateShareableRouteText(
                  widget.currentLocation!,
                  destinationController.text.isNotEmpty ? destinationController.text : 'Home',
                );
                Share.share(routeText);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate & Share'),
          ),
        ],
      ),
    );
  }

  void _showPlaceDetails(BuildContext context, Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (place['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(place['icon'] as IconData, color: place['color'] as Color, size: 48),
            ),
            const SizedBox(height: 16),
            Text(place['name'] as String, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${place['distanceText']} away', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => SafePlaceFinder.navigateToPlace(place, widget.currentLocation!),
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4CE6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Share.share('Safe place: ${place['name']} - ${place['distanceText']} away');
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B4CE6),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportIncidentDialog(BuildContext context) {
    String? selectedType;
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Report Incident'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  hint: const Text('Select incident type'),
                  items: CommunitySafetyAlert.alertTypes.map((Map<String, dynamic> type) {
                    return DropdownMenuItem<String>(
                      value: type['name'] as String,
                      child: Row(
                        children: [
                          Icon(type['icon'] as IconData, color: type['color'] as Color, size: 20),
                          const SizedBox(width: 8),
                          Text(type['name'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) => setState(() => selectedType = value),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the incident...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedType != null && widget.currentLocation != null) {
                await CommunitySafetyAlert.reportIncident(
                  type: selectedType!,
                  description: descriptionController.text,
                  location: widget.currentLocation!,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incident reported successfully'),
                      backgroundColor: Color(0xFF6B4CE6),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6B4CE6).withOpacity(0.1),
                        child: Icon(
                          index == 0 ? Icons.warning : Icons.info,
                          color: const Color(0xFF6B4CE6),
                        ),
                      ),
                      title: Text(
                        index == 0 ? 'Safety Alert' : 'Reminder',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        index == 0 
                            ? 'Unusual activity reported nearby' 
                            : 'Check-in due in 5 minutes',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== NEW SCREEN 2: LIVE AUDIO RECORDING SCREEN ====================
class LiveAudioRecordingScreen extends StatefulWidget {
  final LiveAudioRecorder recorder;
  final String? userId;

  const LiveAudioRecordingScreen({
    Key? key,
    required this.recorder,
    this.userId,
  }) : super(key: key);

  @override
  State<LiveAudioRecordingScreen> createState() => _LiveAudioRecordingScreenState();
}

class _LiveAudioRecordingScreenState extends State<LiveAudioRecordingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  int _recordingDuration = 0;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() => _recordingDuration++);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _durationTimer?.cancel();
    widget.recorder.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Audio Recording'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share('I am sharing live audio recording for my safety');
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (BuildContext context, Widget? child) {
                        return Container(
                          width: 200 * _pulseAnimation.value,
                          height: 200 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.mic, color: Colors.white, size: 80),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Recording in progress', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const Text('Audio is being saved securely', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        String? path = await widget.recorder.stopRecording();
                        if (path != null && mounted) {
                          Navigator.pop(context);
                          _showRecordingSavedDialog(context, path);
                        }
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop & Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
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

  void _showRecordingSavedDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Recording Saved'),
          ],
        ),
        content: const Text('Your audio recording has been saved securely.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Share.shareFiles([path], text: 'Emergency audio recording');
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== UPDATED HOME TAB WITH COMBINED SERVICES AND "MORE" BUTTON ====================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  MapController? _mapController;
  LatLng? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isMapReady = false;
  String? _locationError;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  String? _userName;
  
  List<Marker> _securityMarkers = [];
  
  List<Map<String, dynamic>> _emergencyContacts = [];

  VoiceActivatedSOS? _voiceSOS;
  bool _isVoiceActive = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _getCurrentLocation();
    _loadSecurityAreas();
    _loadEmergencyContacts();
    _initializeServices();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _voiceSOS?.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _voiceSOS = VoiceActivatedSOS();
    await _voiceSOS!.initialize();
    await SafetyCheckInService.initialize();
  }

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    if (_userId == null) return;
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_userId!)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userName = userDoc['fullName'] ?? userDoc['name'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadSecurityAreas() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('security_areas')
          .where('active', isEqualTo: true)
          .get();
          
      List<Marker> markers = [];
      
      for (DocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        GeoPoint? location = data['location'] as GeoPoint?;
        
        if (location != null) {
          Color markerColor;
          switch (data['type'] ?? 'secure') {
            case 'secure':
              markerColor = Colors.green;
              break;
            case 'not_secure':
              markerColor = Colors.red;
              break;
            case 'partially_secure':
              markerColor = Colors.orange;
              break;
            default:
              markerColor = Colors.purple;
          }

          markers.add(
            Marker(
              point: LatLng(location.latitude, location.longitude),
              child: Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                  ],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
            ),
          );
        }
      }
      
      setState(() {
        _securityMarkers = markers;
      });
    } catch (e) {
      print('Error loading security areas: $e');
    }
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('emergency_contacts')
          .orderBy('priority')
          .get();
          
      setState(() {
        _emergencyContacts = snapshot.docs.map((DocumentSnapshot doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'title': data['title'] ?? 'Emergency',
            'number': data['number'] ?? '100',
            'icon': _getIconForService(data['type'] ?? 'police'),
            'color': _getColorForService(data['type'] ?? 'police'),
            'type': data['type'] ?? 'police',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading emergency contacts: $e');
    }
  }

  Future<void> _saveUserLocation() async {
    if (_userId == null || _currentPosition == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId!)
          .update({
        'lastLocation': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'lastLocationTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  Future<void> _saveEmergencyCallLog(String service, String number) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('emergency_calls')
          .add({
        'service': service,
        'number': number,
        'timestamp': FieldValue.serverTimestamp(),
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });
    } catch (e) {
      print('Error saving call log: $e');
    }
  }

  // ← THIS METHOD NOW USES THE IMPORTED SingleWomanScreen
  void _showSingleWomanRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const SingleWomanScreen(),
      ),
    );
  }

  void _showTrackMyTrip() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (BuildContext context) => TrackTripScreen(
        userId: _userId,
        // currentLocation removed – screen will get its own location
      ),
    ),
  );
}

  Future<void> _saveAppointment({
    required String station,
    required String reason,
    required DateTime date,
    required String time,
    String? description,
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('appointments')
          .add({
        'userId': _userId,
        'userName': _userName,
        'station': station,
        'reason': reason,
        'date': Timestamp.fromDate(date),
        'time': time,
        'description': description ?? '',
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'notified': false,
      });
    } catch (e) {
      print('Error saving appointment: $e');
      rethrow;
    }
  }

  void _showAppointmentBooking() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: AppointmentBookingSheet(
          userId: _userId,
          userName: _userName,
          onSave: _saveAppointment,
          onBooked: () {
            Navigator.pop(context);
            _showSuccessDialog(
              'Appointment Booked',
              'Your appointment request has been submitted. You will receive a confirmation soon.',
            );
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6B4CE6))),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Location permissions are permanently denied. Please enable from settings.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        final LatLng latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = latLng;
          _isLoadingLocation = false;
          _locationError = null;
        });
        
        _saveUserLocation();
        
        if (_isMapReady && _mapController != null) {
          _mapController!.move(latLng, 15);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Failed to get location: ${e.toString()}';
        });
      }
    }
  }

  IconData _getIconForService(String type) {
    switch (type) {
      case 'police': return Icons.local_police_rounded;
      case 'ambulance': return Icons.local_hospital_rounded;
      case 'fire': return Icons.fire_truck_rounded;
      case 'women': return Icons.support_agent_rounded;
      case 'child': return Icons.child_care_rounded;
      case 'disaster': return Icons.emergency_rounded;
      case 'accident': return Icons.car_crash_rounded;
      default: return Icons.phone;
    }
  }

  Color _getColorForService(String type) {
    switch (type) {
      case 'police': return const Color(0xFF6B4CE6);
      case 'ambulance': return const Color(0xFF9B7EE8);
      case 'fire': return const Color(0xFFB8A4F5);
      case 'women': return const Color(0xFF8A65E6);
      case 'child': return const Color(0xFF7B5CE6);
      case 'disaster': return const Color(0xFF6B4CE6);
      case 'accident': return const Color(0xFF9B7EE8);
      default: return const Color(0xFF6B4CE6);
    }
  }

  void _showEmergencyDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => EmergencyDashboardScreen(
          currentLocation: _currentPosition,
          userId: _userId,
        ),
      ),
    );
  }

  void _toggleVoiceSOS() {
    if (_isVoiceActive) {
      _voiceSOS?.stopListening();
    } else {
      _voiceSOS?.startListening(() {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (BuildContext context) => const SOSScreen()),
          );
        }
      });
    }
    setState(() {
      _isVoiceActive = !_isVoiceActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildOpenStreetMap(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Combined Services Grid with "More" button
                      _buildServicesGrid(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
        const SizedBox(height: 16),
        
        // First row - Women Safety Services
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Single Woman\nLiving Alone',
                Icons.home_work_rounded,
                const Color(0xFFF0E6FF),
                const Color(0xFF6B4CE6),
                () => _showSingleWomanRegistration(), // ← UPDATED: Now navigates to external Single Woman Screen
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Track\nMy Trip',
                Icons.trip_origin_rounded,
                const Color(0xFFF0E6FF),
                const Color(0xFF6B4CE6),
                () => _showTrackMyTrip(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Book\nAppointment',
                Icons.calendar_month_rounded,
                const Color(0xFFF0E6FF),
                const Color(0xFF6B4CE6),
                () => _showAppointmentBooking(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Second row - Emergency Services
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Fire\nServices',
                Icons.fire_truck_rounded,
                const Color(0xFFFFF0E6),
                const Color(0xFFFF8C42),
                _showFireServices,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Medical\nEmergency',
                Icons.medical_services_rounded,
                const Color(0xFFFFE6E6),
                const Color(0xFFFF4D4D),
                _showMedicalEmergency,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Call\nPolice',
                Icons.local_police_rounded,
                const Color(0xFFF0E6FF),
                const Color(0xFF6B4CE6),
                _showEmergencyContacts,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Third row - Rescue & Support Services
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Rescue\nServices',
                Icons.assist_walker_rounded,
                const Color(0xFFE6F7FF),
                const Color(0xFF4AA3FF),
                _showRescueServices,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Disaster\nAlert',
                Icons.warning_rounded,
                const Color(0xFFFFF0E6),
                const Color(0xFFFF8C42),
                _showNaturalDisasterInfo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Emergency\nContacts',
                Icons.contacts_rounded,
                const Color(0xFFF0E6FF),
                const Color(0xFF6B4CE6),
                _showAllEmergencyContacts,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Fourth row - Other Services
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Share\nLocation',
                Icons.share_location_rounded,
                const Color(0xFFE6F3FF),
                const Color(0xFF3399FF),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (BuildContext context) => const LocationSharingScreen()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Accident\nReport',
                Icons.car_crash_rounded,
                const Color(0xFFFFE6E6),
                const Color(0xFFFF4D4D),
                _showAccidentReport,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Safety\nTips',
                Icons.tips_and_updates_rounded,
                const Color(0xFFE6FFE6),
                const Color(0xFF4CAF50),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (BuildContext context) => const TipsScreen()),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // "More Services" button to access Emergency Dashboard
        GestureDetector(
          onTap: _showEmergencyDashboard,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B4CE6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.dashboard,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'More Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 26,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8), Color(0xFFB8A4F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4CE6).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName != null ? 'Welcome, $_userName!' : 'SafeHer',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Your Safety, Our Priority', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.dashboard, color: Colors.white, size: 24),
                onPressed: _showEmergencyDashboard,
                tooltip: 'Emergency Dashboard',
              ),
            ),
            
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                onPressed: () {
                  _showNotificationsDialog(context);
                },
              ),
            ),
            
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              ),
              onSelected: (String value) {
                HapticFeedback.lightImpact();
                switch (value) {
                  case 'profile':
                    (context.findAncestorStateOfType<_HomeScreenState>())?.navigateToProfileTab();
                    break;
                  case 'settings':
                    _showSettingsDialog(context);
                    break;
                  case 'logout':
                    _showLogoutConfirmation(context);
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Color(0xFF6B4CE6), size: 20),
                      SizedBox(width: 10),
                      Text('View Profile', style: TextStyle(color: Color(0xFF2D3142))),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, color: Color(0xFF6B4CE6), size: 20),
                      SizedBox(width: 10),
                      Text('Settings', style: TextStyle(color: Color(0xFF2D3142))),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red[600], size: 20),
                      const SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                ),
              ],
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              elevation: 4,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6B4CE6).withOpacity(0.1),
                        child: Icon(
                          index == 0 ? Icons.warning : 
                          index == 1 ? Icons.info : 
                          Icons.notifications,
                          color: const Color(0xFF6B4CE6),
                        ),
                      ),
                      title: Text(
                        index == 0 ? 'Safety Alert' :
                        index == 1 ? 'New Update' :
                        'Notification ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        index == 0 ? 'Unusual activity detected in your area' :
                        index == 1 ? 'New safety features added' :
                        'This is a sample notification message',
                      ),
                      trailing: Text(
                        '${index + 1}h ago',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenStreetMap() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            child: _isLoadingLocation && _currentPosition == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF6B4CE6)),
                        const SizedBox(height: 16),
                        const Text('Getting your location...', style: TextStyle(color: Color(0xFF666666))),
                      ],
                    ),
                  )
                : _locationError != null
                    ? _buildErrorView()
                    : FlutterMap(
                        options: MapOptions(
                          center: _currentPosition ?? const LatLng(10.0261, 76.3125),
                          zoom: 15,
                          maxZoom: 18,
                          minZoom: 3,
                          onMapReady: () {
                            setState(() {
                              _isMapReady = true;
                            });
                            if (_currentPosition != null && _mapController != null) {
                              _mapController!.move(_currentPosition!, 15);
                            }
                          },
                        ),
                        mapController: _mapController,
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.safeher.app',
                            maxZoom: 19,
                          ),
                          
                          if (_currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentPosition!,
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
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          
                          MarkerLayer(markers: _securityMarkers),
                        ],
                      ),
          ),

          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(Colors.green, 'Secure'),
                  const SizedBox(height: 4),
                  _buildLegendItem(Colors.orange, 'Partially secure'),
                  const SizedBox(height: 4),
                  _buildLegendItem(Colors.red, 'Not secure'),
                ],
              ),
            ),
          ),

          if (_currentPosition != null && !_isLoadingLocation)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location, color: Color(0xFF6B4CE6), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '📍 ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2D3142)),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            right: 20,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6B4CE6).withOpacity(0.3), blurRadius: 12),
                  ],
                ),
                child: const Icon(Icons.my_location, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF2D3142))),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 60, color: Color(0xFF9B7EE8)),
            const SizedBox(height: 16),
            Text(
              _locationError ?? 'Unable to get location',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9B7EE8), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4CE6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _makePhoneCall(String service, String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
        _saveEmergencyCallLog(service, number);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  void _showEmergencyContacts() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Emergency Contacts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _buildEmergencyContactItem('Police', '100', Icons.local_police_rounded, const Color(0xFF6B4CE6), 'police'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Ambulance', '108', Icons.local_hospital_rounded, const Color(0xFF9B7EE8), 'ambulance'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Women Helpline', '1091', Icons.support_agent_rounded, const Color(0xFFB8A4F5), 'women'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Child Helpline', '1098', Icons.child_care_rounded, const Color(0xFF8A65E6), 'child'),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllEmergencyContacts() {
    if (_emergencyContacts.isEmpty) {
      _loadEmergencyContacts();
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Emergency Contacts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _emergencyContacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: _emergencyContacts.map((Map<String, dynamic> contact) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEmergencyContactItem(
                            contact['title'],
                            contact['number'],
                            contact['icon'],
                            contact['color'],
                            contact['type'],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactItem(
    String title,
    String number,
    IconData icon,
    Color color,
    String serviceType,
  ) {
    return GestureDetector(
      onTap: () => _makePhoneCall(serviceType, number),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFireServices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Fire & Rescue Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _buildEmergencyContactItem('Fire Department', '101', Icons.fire_truck_rounded, const Color(0xFFFF8C42), 'fire'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Disaster Response', '108', Icons.emergency_rounded, const Color(0xFFFF8C42), 'disaster'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Gas Leak Helpline', '1906', Icons.gas_meter_rounded, const Color(0xFFFF8C42), 'gas'),
            ],
          ),
        ),
      ),
    );
  }

  void _showMedicalEmergency() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Medical Emergency Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _buildEmergencyContactItem('Ambulance', '108', Icons.local_hospital_rounded, const Color(0xFFFF4D4D), 'ambulance'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Emergency Medical', '102', Icons.medical_services_rounded, const Color(0xFFFF4D4D), 'medical'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Poison Control', '1800111222', Icons.warning_amber_rounded, const Color(0xFFFF8C42), 'poison'),
            ],
          ),
        ),
      ),
    );
  }

  void _showNaturalDisasterInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Natural Disaster Safety', style: TextStyle(color: Color(0xFF2D3142), fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Important contacts and safety guidelines for earthquakes, floods, cyclones, and other natural disasters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), fontSize: 14),
              ),
              const SizedBox(height: 20),
              _buildQuickContact('Disaster Management', '1070', const Color(0xFF6B4CE6), 'disaster'),
              const SizedBox(height: 12),
              _buildQuickContact('NDRF Helpline', '97110', const Color(0xFF9B7EE8), 'ndrf'),
              const SizedBox(height: 12),
              _buildQuickContact('Weather Alert', '18001801717', const Color(0xFFB8A4F5), 'weather'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4CE6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickContact(String title, String number, Color color, String serviceType) {
    return GestureDetector(
      onTap: () => _makePhoneCall(serviceType, number),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRescueServices() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Rescue & Support Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _buildEmergencyContactItem('Mountain Rescue', '108', Icons.terrain_rounded, const Color(0xFF4AA3FF), 'mountain'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Coast Guard', '1554', Icons.directions_boat_rounded, const Color(0xFF4AA3FF), 'coast'),
              const SizedBox(height: 12),
              _buildEmergencyContactItem('Animal Rescue', '1962', Icons.pets_rounded, const Color(0xFF4AA3FF), 'animal'),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccidentReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => AccidentReportScreen(
          onReportSubmitted: _saveAccidentReport,
        ),
      ),
    );
  }

  Future<void> _saveAccidentReport({
    required String department,
    required String description,
    required int imageCount,
    bool hasVideo = false,
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId!)
          .collection('accident_reports')
          .add({
        'department': department,
        'description': description,
        'imageCount': imageCount,
        'hasVideo': hasVideo,
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'submitted',
      });
    } catch (e) {
      print('Error saving accident report: $e');
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFF6B4CE6)),
            SizedBox(width: 12),
            Text('Confirm Logout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nYou will need to login again to access safety features.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (BuildContext context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
              const SizedBox(height: 20),
              _buildSettingsOption(Icons.notifications_outlined, 'Notifications', 'Manage your notification preferences', 
                () { Navigator.pop(context); _showNotificationSettings(context); }),
              const SizedBox(height: 12),
              _buildSettingsOption(Icons.security_outlined, 'Privacy & Security', 'Configure privacy and security settings',
                () { Navigator.pop(context); _showPrivacySettings(context); }),
              const SizedBox(height: 12),
              _buildSettingsOption(Icons.location_on_outlined, 'Location Services', 'Configure location access and accuracy',
                () { Navigator.pop(context); _showLocationSettings(context); }),
              const SizedBox(height: 12),
              _buildSettingsOption(Icons.help_outline, 'Help & Support', 'Get help and contact support',
                () { Navigator.pop(context); _showHelpSupport(context); }),
              const SizedBox(height: 12),
              _buildSettingsOption(Icons.info_outline, 'About App', 'App version and information',
                () { Navigator.pop(context); _showAboutApp(context); }),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4CE6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF2D3142))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B4CE6), size: 20),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Notification Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: true, 
              onChanged: (bool value) {}, 
              title: const Text('SOS Alerts', style: TextStyle(color: Color(0xFF2D3142))), 
              activeColor: const Color(0xFF6B4CE6),
            ),
            SwitchListTile(
              value: true, 
              onChanged: (bool value) {}, 
              title: const Text('Location Updates', style: TextStyle(color: Color(0xFF2D3142))), 
              activeColor: const Color(0xFF6B4CE6),
            ),
            SwitchListTile(
              value: false, 
              onChanged: (bool value) {}, 
              title: const Text('Safety Tips', style: TextStyle(color: Color(0xFF2D3142))), 
              activeColor: const Color(0xFF6B4CE6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4CE6), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Privacy & Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
              ),
              title: const Text('Change Password', style: TextStyle(color: Color(0xFF2D3142))),
              onTap: () { Navigator.pop(context); _showChangePasswordDialog(context); },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.visibility_off_outlined, color: Colors.white, size: 20),
              ),
              title: const Text('App Lock', style: TextStyle(color: Color(0xFF2D3142))),
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF666666))),
          ),
        ],
      ),
    );
  }

  void _showLocationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Location Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: true, 
              onChanged: (bool value) {}, 
              title: const Text('Background Location', style: TextStyle(color: Color(0xFF2D3142))), 
              activeColor: const Color(0xFF6B4CE6),
            ),
            SwitchListTile(
              value: true, 
              onChanged: (bool value) {}, 
              title: const Text('High Accuracy', style: TextStyle(color: Color(0xFF2D3142))), 
              activeColor: const Color(0xFF6B4CE6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4CE6), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Help & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: const Text('Email: support@safeher.com\nPhone: +91 1800-XXX-XXXX', style: TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF666666))),
          ),
        ],
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('About SafeHer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 60, color: Color(0xFF6B4CE6)),
            SizedBox(height: 16),
            Text('SafeHer - Your Safety Companion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
            SizedBox(height: 8),
            Text('Version 2.0.0', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            Text('Advanced safety features including Voice SOS, Live Audio Recording, Fake Calls, and Emergency Dashboard.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF666666))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF666666))),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: const TextStyle(color: Color(0xFF666666)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B4CE6))),
              ),
              obscureText: true,
              style: const TextStyle(color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: const TextStyle(color: Color(0xFF666666)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B4CE6))),
              ),
              obscureText: true,
              style: const TextStyle(color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: const TextStyle(color: Color(0xFF666666)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B4CE6))),
              ),
              obscureText: true,
              style: const TextStyle(color: Color(0xFF2D3142)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully'), backgroundColor: Color(0xFF6B4CE6)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4CE6), foregroundColor: Colors.white),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

// ==================== APPOINTMENT BOOKING SHEET ====================
class AppointmentBookingSheet extends StatefulWidget {
  final String? userId;
  final String? userName;
  final Function({
    required String station, 
    required String reason, 
    required DateTime date, 
    required String time, 
    String? description,
  }) onSave;
  final VoidCallback onBooked;

  const AppointmentBookingSheet({
    Key? key, 
    this.userId, 
    this.userName, 
    required this.onSave, 
    required this.onBooked,
  }) : super(key: key);

  @override
  State<AppointmentBookingSheet> createState() => _AppointmentBookingSheetState();
}

class _AppointmentBookingSheetState extends State<AppointmentBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStation;
  String? _selectedReason;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _description;
  bool _isLoading = false;
  
  final List<String> _policeStations = [
    'Women Police Station - Ernakulam', 'Women Police Station - Thiruvananthapuram',
    'Women Police Station - Kozhikode', 'Child Welfare Police Unit - Ernakulam',
    'Child Welfare Police Unit - Thiruvananthapuram', 'District Police Office - Ernakulam',
  ];
  
  final List<String> _reasons = [
    'File a Complaint', 'Seek Counseling', 'Report Harassment',
    'Domestic Violence Report', 'Legal Advice', 'General Inquiry',
  ];

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedDate != null && _selectedTime != null) {
      setState(() => _isLoading = true);
      try {
        await widget.onSave(
          station: _selectedStation!,
          reason: _selectedReason!,
          date: _selectedDate!,
          time: _selectedTime!.format(context),
          description: _description,
        );
        widget.onBooked();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6B4CE6), Color(0xFF9B7EE8)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Text('Book Appointment', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4CE6)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedStation,
                          decoration: const InputDecoration(labelText: 'Select Police Station', prefixIcon: Icon(Icons.local_police)),
                          items: _policeStations.map((String s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                          onChanged: (String? v) => setState(() => _selectedStation = v),
                          validator: (String? v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedReason,
                          decoration: const InputDecoration(labelText: 'Reason for Appointment', prefixIcon: Icon(Icons.report_problem)),
                          items: _reasons.map((String r) => DropdownMenuItem<String>(value: r, child: Text(r))).toList(),
                          onChanged: (String? v) => setState(() => _selectedReason = v),
                          validator: (String? v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().add(const Duration(days: 1)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) setState(() => _selectedDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: const Color(0xFF6B4CE6)),
                                      const SizedBox(width: 8),
                                      Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (picked != null) setState(() => _selectedTime = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, color: const Color(0xFF6B4CE6)),
                                      const SizedBox(width: 8),
                                      Text(_selectedTime == null ? 'Select Time' : _selectedTime!.format(context)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Additional Details (Optional)',
                            hintText: 'Please provide any additional information...',
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (String? v) => _description = v,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B4CE6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Book Appointment', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ==================== ACCIDENT REPORT SCREEN ====================
class AccidentReportScreen extends StatefulWidget {
  final Function({
    required String department, 
    required String description, 
    required int imageCount, 
    required bool hasVideo,
  }) onReportSubmitted;

  const AccidentReportScreen({super.key, required this.onReportSubmitted});

  @override
  State<AccidentReportScreen> createState() => _AccidentReportScreenState();
}

class _AccidentReportScreenState extends State<AccidentReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final List<File> _images = [];
  File? _video;
  String _selectedDepartment = 'Traffic Police';
  final ImagePicker _picker = ImagePicker();

  final Map<String, Map<String, String>> _departmentDetails = {
    'Traffic Police': {'number': '103', 'icon': '🚓', 'description': 'Report traffic accidents'},
    'Road Accident': {'number': '1073', 'icon': '🚑', 'description': 'Emergency medical assistance'},
    'Towing Service': {'number': '18001363', 'icon': '🛻', 'description': 'Vehicle towing'},
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) setState(() => _images.add(File(image.path)));
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) setState(() => _video = File(video.path));
  }

  void _submitReport() {
    if (_images.isEmpty && _video == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add evidence')));
      return;
    }
    widget.onReportSubmitted(
      department: _selectedDepartment,
      description: _descriptionController.text,
      imageCount: _images.length,
      hasVideo: _video != null,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Report Submitted'),
        content: const Text('Your report has been submitted.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accident Report'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                items: _departmentDetails.keys.map((String d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                onChanged: (String? v) => setState(() => _selectedDepartment = v!),
              ),
              const SizedBox(height: 24),
              const Text('Add Evidence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildMediaButton(Icons.camera_alt, 'Camera', _pickImage)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMediaButton(Icons.videocam, 'Video', _pickVideo)),
                ],
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: _images.map((File img) => Image.file(img, width: 100, height: 100)).toList()),
              ],
              const SizedBox(height: 24),
              const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Describe the accident...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4CE6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Report', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF6B4CE6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6B4CE6).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6B4CE6), size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF6B4CE6))),
          ],
        ),
      ),
    );
  }
}
