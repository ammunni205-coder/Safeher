import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;

class LiveTrackingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final List<Map<String, dynamic>> contacts;
  final String duration;
  final String message;
  final latlong2.LatLng initialLocation;

  const LiveTrackingScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.contacts,
    required this.duration,
    required this.message,
    required this.initialLocation,
  }) : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();
  latlong2.LatLng? _currentLocation;
  String? _sessionId;
  bool _isLoading = true;

  // Replace with your Render URL after deployment
  final String _notificationServerUrl = 'https://safeher-63yl.onrender.com/send-notification';

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _endSession();
    super.dispose();
  }

  Future<void> _createSession() async {
    try {
      final docRef = await _firestore.collection('tracking_sessions').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'message': widget.message,
        'contacts': widget.contacts.map((c) => {
          'name': c['name'],
          'phone': c['phone'],
          'userId': c['userId'],
        }).toList(),
        'startLocation': GeoPoint(widget.initialLocation.latitude, widget.initialLocation.longitude),
        'duration': widget.duration,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });
      _sessionId = docRef.id;

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((Position pos) {
        _updateLocation(pos);
      });

      setState(() {
        _currentLocation = widget.initialLocation;
        _isLoading = false;
      });

      // 🔔 Send notification to selected contacts
      _sendNotification();
    } catch (e) {
      print('Error creating session: $e');
    }
  }

  Future<void> _sendNotification() async {
    final contactUids = widget.contacts.map((c) => c['userId']).toList();
    if (contactUids.isEmpty) return;

    try {
      await http.post(
        Uri.parse(_notificationServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userIds': contactUids,
          'message': widget.message,
          'sessionId': _sessionId,
        }),
      );
      print('Notification request sent');
    } catch (e) {
      print('Error calling notification server: $e');
    }
  }

  Future<void> _updateLocation(Position pos) async {
    if (_sessionId == null) return;
    final latLng = latlong2.LatLng(pos.latitude, pos.longitude);
    try {
      await _firestore.collection('tracking_sessions').doc(_sessionId!).update({
        'currentLocation': GeoPoint(pos.latitude, pos.longitude),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      setState(() => _currentLocation = latLng);
      _mapController.move(latLng, _mapController.camera.zoom);
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _endSession() async {
    if (_sessionId != null) {
      await _firestore.collection('tracking_sessions').doc(_sessionId!).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _stopTracking() async {
    await _endSession();
    _positionStream?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharing Location'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.red),
            onPressed: _stopTracking,
          ),
        ],
      ),
      body: Stack(
        children: [
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
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Message: ${widget.message}'),
                    const Divider(),
                    const Text('You are sharing your location with:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.contacts.map((c) => Text('• ${c['name']}')),
                    Text('Duration: ${widget.duration}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}