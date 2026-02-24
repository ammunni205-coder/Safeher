import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;

class FollowTripScreen extends StatefulWidget {
  final String sessionId;
  const FollowTripScreen({super.key, required this.sessionId});

  @override
  State<FollowTripScreen> createState() => _FollowTripScreenState();
}

class _FollowTripScreenState extends State<FollowTripScreen> {
  final MapController _mapController = MapController();
  latlong2.LatLng? _currentLocation;
  String? _message;
  String? _userName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following Trip'),
        backgroundColor: const Color(0xFF6B4CE6),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tracking_sessions')
            .doc(widget.sessionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null || data['status'] == 'completed') {
            return const Center(child: Text('This trip has ended.'));
          }

          _message = data['message'] ?? '';
          _userName = data['userName'] ?? 'Someone';

          final geo = data['currentLocation'] as GeoPoint?;
          if (geo != null) {
            _currentLocation = latlong2.LatLng(geo.latitude, geo.longitude);
            _mapController.move(_currentLocation!, _mapController.camera.zoom);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: _currentLocation ?? const latlong2.LatLng(0, 0),
                  zoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.safeher.app',
                  ),
                  if (_currentLocation != null)
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
                        Text('From $_userName', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Message: $_message'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}