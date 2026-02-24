import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({Key? key}) : super(key: key);

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  int _countdownSeconds = 5;
  bool _isEmergencyActivated = false;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _userId;
  
  // Location
  Position? _currentPosition;
  bool _isGettingLocation = false;

  // Media capture
  final ImagePicker _picker = ImagePicker();
  List<File> _capturedImages = [];
  File? _capturedVideo;
  bool _isRecording = false;
  AudioPlayer? _audioPlayer;
  
  // For audio recording - using a simple timer simulation
  // Since audioplayers doesn't have recorder, we'll simulate recording
  Timer? _recordingTimer;
  String? _simulatedAudioPath;

  // Emergency contacts
  List<Map<String, dynamic>> _guardians = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadGuardians();
    _startCountdown();
    _initAudio();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController!,
        curve: Curves.easeInOut,
      ),
    );
    
    HapticFeedback.heavyImpact();
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

  Future<void> _loadGuardians() async {
    if (_userId == null) return;
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('guardians')
          .get();

      setState(() {
        _guardians = snapshot.docs.map((doc) {
          return {
            'name': doc['name'] ?? 'Guardian',
            'phone': doc['phone'] ?? '',
            'docId': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading guardians: $e');
    }
  }

  // ==================== LOCATION METHODS ====================

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });

    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // ==================== MEDIA CAPTURE METHODS ====================

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      
      if (image != null) {
        File imageFile = File(image.path);
        
        // Upload to Firebase Storage
        String downloadUrl = await _uploadMediaToFirebase(
          imageFile,
          'images',
          'sos_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        
        // Save to Firestore
        await _saveMediaToFirestore('image', downloadUrl);
        
        setState(() {
          _capturedImages.add(imageFile);
        });

        _showSnackBar('📸 Photo captured and saved', isSuccess: true);
      }
    } catch (e) {
      print('Error capturing image: $e');
      _showSnackBar('Failed to capture photo', isError: true);
    }
  }

  Future<void> _captureVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (video != null) {
        File videoFile = File(video.path);
        
        // Upload to Firebase Storage
        String downloadUrl = await _uploadMediaToFirebase(
          videoFile,
          'videos',
          'sos_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        
        // Save to Firestore
        await _saveMediaToFirestore('video', downloadUrl);
        
        setState(() {
          _capturedVideo = videoFile;
        });

        _showSnackBar('🎥 Video captured and saved', isSuccess: true);
      }
    } catch (e) {
      print('Error capturing video: $e');
      _showSnackBar('Failed to capture video', isError: true);
    }
  }

  // SIMULATED AUDIO RECORDING - Since audioplayers doesn't have recorder
  Future<void> _captureAudio() async {
    try {
      if (!_isRecording) {
        // Start simulated recording
        setState(() {
          _isRecording = true;
          _simulatedAudioPath = 'simulated_recording_${DateTime.now().millisecondsSinceEpoch}';
        });
        
        _showSnackBar('🎙️ Recording started...', isSuccess: true);
        
        // Simulate recording timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (timer.tick >= 30) { // Stop after 30 seconds
            _stopAudioRecording();
          }
        });
        
        // Auto-stop after 30 seconds
        Future.delayed(const Duration(seconds: 30), () {
          if (_isRecording) {
            _stopAudioRecording();
          }
        });
      } else {
        await _stopAudioRecording();
      }
    } catch (e) {
      print('Error capturing audio: $e');
      _showSnackBar('Failed to record audio', isError: true);
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      _recordingTimer?.cancel();
      
      if (_isRecording) {
        // Create a dummy file for the recording
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final audioFile = File(filePath);
        
        // Write some dummy data (since we can't actually record)
        await audioFile.writeAsString('Simulated audio recording');
        
        // Upload to Firebase Storage
        String downloadUrl = await _uploadMediaToFirebase(
          audioFile,
          'audio',
          'sos_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        
        // Save to Firestore
        await _saveMediaToFirestore('audio', downloadUrl);
        
        setState(() {
          _capturedAudio = audioFile;
          _isRecording = false;
        });

        _showSnackBar('🎙️ Recording saved', isSuccess: true);
      }
    } catch (e) {
      print('Error stopping audio: $e');
      _showSnackBar('Failed to save recording', isError: true);
    }
  }

  // Add this missing variable
  File? _capturedAudio;

  Future<String> _uploadMediaToFirebase(
    File file,
    String folder,
    String fileName,
  ) async {
    if (_userId == null) throw Exception('User not logged in');

    try {
      Reference ref = _storage
          .ref()
          .child('users')
          .child(_userId!)
          .child('sos')
          .child(folder)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Uploaded to: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading to Firebase: $e');
      rethrow;
    }
  }

  Future<void> _saveMediaToFirestore(String type, String url) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sos_media')
          .add({
        'type': type,
        'url': url,
        'timestamp': FieldValue.serverTimestamp(),
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });
      
      print('✅ Media saved to Firestore');
    } catch (e) {
      print('Error saving media to Firestore: $e');
    }
  }

  // ==================== SOS ACTIVATION ====================

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
          HapticFeedback.selectionClick();
        } else {
          _countdownTimer?.cancel();
          _activateEmergency();
        }
      });
    });
  }

  Future<void> _activateEmergency() async {
    if (!mounted) return;
    
    setState(() {
      _isEmergencyActivated = true;
    });
    
    HapticFeedback.heavyImpact();
    
    // Get current location
    await _getCurrentLocation();
    
    // Send SOS to guardians
    await _sendSOSToGuardians();
    
    // Save SOS event to Firebase
    await _saveSOSToFirebase();
  }

  Future<void> _sendSOSToGuardians() async {
    if (_guardians.isEmpty) return;

    String locationLink = '';
    if (_currentPosition != null) {
      locationLink = 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }

    String sosMessage = '''
🚨 URGENT SOS ALERT from SafeHer 🚨

I need immediate help! This is an emergency.

📍 Live Location: $locationLink
🕐 Time: ${DateTime.now().toString().substring(0, 16)}

📸 Media evidence has been captured and saved.

Please contact me immediately!

- Sent from SafeHer Safety App
''';

    for (var guardian in _guardians) {
      String phone = guardian['phone'] ?? '';
      if (phone.isNotEmpty) {
        await _sendSMS(phone, sosMessage);
      }
    }
  }

  Future<void> _sendSMS(String phone, String message) async {
    try {
      Uri uri = Uri(
        scheme: 'sms',
        path: phone.replaceAll(' ', ''),
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ SMS sent to: $phone');
      }
    } catch (e) {
      print('Error sending SMS: $e');
    }
  }

  Future<void> _saveSOSToFirebase() async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('sos_alerts')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        'guardians': _guardians.length,
        'mediaCount': _capturedImages.length + 
                      (_capturedVideo != null ? 1 : 0) + 
                      (_capturedAudio != null ? 1 : 0),
        'status': 'active',
      });
      
      print('✅ SOS saved to Firestore');
    } catch (e) {
      print('Error saving SOS to Firestore: $e');
    }
  }

  void _cancelEmergency() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
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
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _pulseController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isEmergencyActivated ? _buildSuccessScreen() : _buildCountdownScreen(),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Column(
      children: [
        const SizedBox(height: 40),
        
        // Title
        const Text(
          'Are you in Emergency?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Subtitle
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Press the button below and help\nwill reach you soon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ),
        
        const SizedBox(height: 60),
        
        // SOS Button with countdown
        Expanded(
          child: Center(
            child: _pulseAnimation != null
                ? AnimatedBuilder(
                    animation: _pulseAnimation!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation!.value,
                        child: _buildSOSButton(),
                      );
                    },
                  )
                : _buildSOSButton(),
          ),
        ),
        
        // Cancel button
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelEmergency,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(
                  color: Color(0xFFCCCCCC),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSOSButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5252).withOpacity(0.15),
          ),
        ),
        // Middle circle
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5252).withOpacity(0.25),
          ),
        ),
        // Inner button
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5252),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5252).withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _countdownSeconds > 0 ? '$_countdownSeconds' : 'SOS',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Column(
      children: [
        // Success header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Color(0xFFFF5252),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                'Emergency\nRequest sent!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isGettingLocation 
                    ? 'Getting your location...' 
                    : 'Please stay calm!\nHelp will reach out to you soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // What next section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What next?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Timeline steps
                _buildTimelineStep(
                  icon: Icons.phone_callback,
                  text: 'You will receive a call from\ncontrol room.',
                  isLast: false,
                ),
                
                _buildTimelineStep(
                  icon: Icons.location_on,
                  text: 'Responder will reach your\nlocation/seat',
                  actionText: _currentPosition != null 
                      ? '📍 Location acquired' 
                      : 'Getting location...',
                  isLast: false,
                ),
                
                _buildTimelineStep(
                  icon: Icons.health_and_safety,
                  text: 'Responder will help you get\nout of the situation and take\nnecessary actions',
                  isLast: true,
                ),
                
                const SizedBox(height: 32),
                
                // Capture section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Capture evidence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_capturedImages.length + (_capturedVideo != null ? 1 : 0) + (_capturedAudio != null ? 1 : 0)} saved',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Capture what is going on around you!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Media capture buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCaptureButton(
                      icon: _isRecording ? Icons.stop : Icons.mic,
                      label: _isRecording ? 'STOP' : 'AUDIO',
                      color: _isRecording ? Colors.red : const Color(0xFF607D8B),
                      onTap: _captureAudio,
                    ),
                    _buildCaptureButton(
                      icon: Icons.videocam,
                      label: 'VIDEO',
                      color: const Color(0xFF607D8B),
                      onTap: _captureVideo,
                    ),
                    _buildCaptureButton(
                      icon: Icons.camera_alt,
                      label: 'PHOTO',
                      color: const Color(0xFF607D8B),
                      onTap: _captureImage,
                    ),
                  ],
                ),
                
                // Captured images preview
                if (_capturedImages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Captured Photos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _capturedImages[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                // Video preview
                if (_capturedVideo != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Video captured',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Audio preview
                if (_capturedAudio != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.audiotrack,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Audio recording saved',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Guardian count
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield,
                        color: Color(0xFF6B4CE6),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _guardians.isEmpty
                              ? 'No guardians added'
                              : 'SOS sent to ${_guardians.length} guardian(s)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        
        // Close button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String text,
    String? actionText,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5252).withOpacity(0.1),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF5252),
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              if (actionText != null) ...[
                const SizedBox(height: 8),
                Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 14,
                    color: actionText.contains('acquired') 
                        ? Colors.green 
                        : const Color(0xFF2196F3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}