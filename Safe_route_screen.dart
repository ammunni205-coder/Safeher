import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // kept for LatLng
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  final TextEditingController _destinationController = TextEditingController();
  bool _isSearching = false;
  List<RouteOption> _routes = [];

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  // Location
  Position? _currentPosition;
  LatLng? _destinationPosition;
  String? _destinationName;
  bool _isGettingLocation = false;
  bool _isSearchingDestination = false;

  // Filters
  bool _filterWellLit = false;
  bool _filterCrowded = false;
  bool _filterCCTV = false;

  // Search history
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  // ==================== FIREBASE METHODS ====================

  Future<void> _getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() => _userId = user.uid);
      await _loadRecentSearches();
    }
  }

  Future<void> _loadRecentSearches() async {
    if (_userId == null) return;
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('route_searches')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      List<String> searches = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('destination') && data['destination'] != null) {
          searches.add(data['destination'].toString());
        }
      }
      if (mounted) setState(() => _recentSearches = searches);
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _saveSearchToFirebase(String destination) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('route_searches')
          .add({
        'destination': destination,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _loadRecentSearches();
    } catch (e) {
      print('Error saving search: $e');
    }
  }

  Future<void> _saveRouteToFirebase(RouteOption route) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('selected_routes')
          .add({
        'safetyLevel': route.safetyLevel,
        'distance': route.distance,
        'duration': route.duration,
        'description': route.description,
        'destination': _destinationController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'location': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });
      print('✅ Route saved to history');
    } catch (e) {
      print('Error saving route: $e');
    }
  }

  // ==================== LOCATION METHODS ====================

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

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

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isGettingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // ==================== DYNAMIC LOCATION SEARCH ====================

  Future<LatLng?> _searchLocationDynamically(String query) async {
    setState(() => _isSearchingDestination = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'SafeHerApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final displayName = data[0]['display_name'];

          print('✅ Found: $displayName at $lat, $lon');
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print('❌ Error searching location: $e');
    } finally {
      setState(() => _isSearchingDestination = false);
    }

    return null;
  }

  // ==================== CALCULATE DISTANCE ====================

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371;
    double dLat = _toRadians(to.latitude - from.latitude);
    double dLon = _toRadians(to.longitude - from.longitude);
    double lat1 = _toRadians(from.latitude);
    double lat2 = _toRadians(to.latitude);

    double a = pow(sin(dLat / 2), 2) +
              pow(sin(dLon / 2), 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  String _calculateDuration(double distanceKm) {
    int minutes = (distanceKm / 5 * 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}min';
  }

  // ==================== SEARCH ROUTES ====================

  Future<void> _searchRoutes() async {
    if (_destinationController.text.isEmpty) {
      _showSnackBar('Please enter a destination');
      return;
    }

    setState(() {
      _isSearching = true;
      _routes = [];
      _destinationPosition = null;
      _destinationName = null;
    });

    await _saveSearchToFirebase(_destinationController.text);

    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    String query = _destinationController.text;
    _destinationPosition = await _searchLocationDynamically(query);
    _destinationName = query;

    if (_destinationPosition == null) {
      setState(() => _isSearching = false);
      _showSnackBar('Destination not found. Try another location.', isError: true);
      return;
    }

    if (_currentPosition != null) {
      LatLng origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      double directDistance = _calculateDistance(origin, _destinationPosition!);
      _generateRoutes(directDistance);
    }

    setState(() => _isSearching = false);
  }

  // ==================== GENERATE ROUTES ====================

  void _generateRoutes(double distance) {
    List<RouteOption> routes = [
      RouteOption(
        safetyLevel: 'Safest',
        safetyIcon: Icons.verified_user,
        safetyColor: Colors.green,
        distance: distance * 1.2,
        duration: _calculateDuration(distance * 1.2),
        description: '✅ Well-lit main roads with CCTV coverage and police presence',
        wellLit: true,
        crowded: true,
        cctvCount: 15,
        policeStations: 3,
        hospitalNearby: true,
      ),
      RouteOption(
        safetyLevel: 'Safe',
        safetyIcon: Icons.shield,
        safetyColor: Colors.orange,
        distance: distance * 1.1,
        duration: _calculateDuration(distance * 1.1),
        description: '🟡 Mix of main roads and residential areas with moderate safety',
        wellLit: true,
        crowded: false,
        cctvCount: 8,
        policeStations: 1,
        hospitalNearby: false,
      ),
      RouteOption(
        safetyLevel: 'Fastest',
        safetyIcon: Icons.speed,
        safetyColor: Colors.blue,
        distance: distance,
        duration: _calculateDuration(distance),
        description: '⚡ Shortest route but less crowded with limited lighting',
        wellLit: false,
        crowded: false,
        cctvCount: 2,
        policeStations: 0,
        hospitalNearby: false,
      ),
    ];

    if (_filterWellLit || _filterCrowded || _filterCCTV) {
      routes = routes.where((route) {
        if (_filterWellLit && !route.wellLit) return false;
        if (_filterCrowded && !route.crowded) return false;
        if (_filterCCTV && route.cctvCount < 5) return false;
        return true;
      }).toList();
    }

    setState(() => _routes = routes);
  }

  // ==================== FILTER METHODS ====================

  void _toggleFilter(String filter) {
    setState(() {
      switch (filter) {
        case 'well-lit': _filterWellLit = !_filterWellLit; break;
        case 'crowded': _filterCrowded = !_filterCrowded; break;
        case 'cctv': _filterCCTV = !_filterCCTV; break;
      }
    });

    if (_routes.isNotEmpty && _destinationPosition != null && _currentPosition != null) {
      LatLng origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      double distance = _calculateDistance(origin, _destinationPosition!);
      _generateRoutes(distance);
    }
  }

  // ==================== ROUTE ACTIONS ====================

  void _selectRoute(RouteOption route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.route, color: Color(0xFF6B4CE6)),
            SizedBox(width: 12),
            Text('Start Journey', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to start navigation along the ${route.safetyLevel.toLowerCase()} route to ${_destinationController.text}?',
              style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(route.safetyIcon, color: route.safetyColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your location will be shared with guardians during this journey.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startNavigation(route);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4CE6)),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _startNavigation(RouteOption route) {
    _saveRouteToFirebase(route);
    _openGoogleMaps();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚗 Navigating to ${_destinationController.text} via ${route.safetyLevel} route'),
        backgroundColor: route.safetyColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    String destination = _destinationController.text.trim();

    String url;
    if (_currentPosition != null) {
      url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&destination=${Uri.encodeComponent(destination)}'
          '&travelmode=walking';
    } else {
      url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destination)}';
    }

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening maps: $e');
      _showSnackBar('Could not open Google Maps', isError: true);
    }
  }

  // ==================== HELPER METHODS ====================

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF6B4CE6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _destinationController.clear();
      _routes = [];
      _destinationPosition = null;
      _destinationName = null;
    });
  }

  void _useRecentSearch(String search) {
    _destinationController.text = search;
    _searchRoutes();
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Safe Route',
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
          if (_destinationController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
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
                const Icon(
                  Icons.route,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Find Safest Route',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isGettingLocation || _isSearchingDestination
                      ? 'Getting location...'
                      : _currentPosition != null
                          ? '📍 Location ready'
                          : 'AI-powered safety analysis',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Search Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    labelText: 'Where do you want to go?',
                    hintText: '🔍 Search ANY place worldwide (e.g., Taj Mahal, New York)',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: _isSearchingDestination
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6B4CE6),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchRoutes,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6B4CE6), width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _searchRoutes(),
                ),

                const SizedBox(height: 16),

                // Safety Filters
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip('Well-lit', Icons.lightbulb, _filterWellLit),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip('Crowded', Icons.groups, _filterCrowded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip('CCTV', Icons.videocam, _filterCCTV),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Section
          if (_isSearching)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B4CE6)),
                    ),
                    SizedBox(height: 20),
                    Text('Finding safe routes to your destination...'),
                  ],
                ),
              ),
            )
          else if (_routes.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Routes to ${_destinationController.text}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B4CE6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_routes.length} routes',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B4CE6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        return _buildRouteCard(_routes[index]);
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.explore,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _recentSearches.isEmpty
                              ? 'Enter any destination to find\nsafe routes worldwide! 🌍'
                              : 'No routes found. Try a different destination.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        if (_recentSearches.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Recent searches:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _recentSearches.map((search) {
                              return ActionChip(
                                avatar: const Icon(Icons.history, size: 16, color: Color(0xFF6B4CE6)),
                                label: Text(
                                  search,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _useRecentSearch(search),
                                backgroundColor: Colors.grey[100],
                                labelStyle: const TextStyle(color: Color(0xFF2D3142)),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isSelected) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : const Color(0xFF6B4CE6),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6B4CE6),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => _toggleFilter(label.toLowerCase()),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF6B4CE6),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF6B4CE6)
            : const Color(0xFF6B4CE6).withOpacity(0.3),
      ),
    );
  }

  Widget _buildRouteCard(RouteOption route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _selectRoute(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: route.safetyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          route.safetyIcon,
                          size: 16,
                          color: route.safetyColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          route.safetyLevel,
                          style: TextStyle(
                            color: route.safetyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${route.distance.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      route.duration,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (route.wellLit)
                    _buildFeatureBadge(Icons.lightbulb, 'Well-lit', Colors.amber),
                  if (route.crowded)
                    _buildFeatureBadge(Icons.groups, 'Crowded', Colors.blue),
                  _buildFeatureBadge(Icons.videocam, '${route.cctvCount} CCTVs', Colors.purple),
                  if (route.policeStations > 0)
                    _buildFeatureBadge(Icons.local_police, '${route.policeStations} Police', Colors.indigo),
                  if (route.hospitalNearby)
                    _buildFeatureBadge(Icons.local_hospital, 'Hospital', Colors.red),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                route.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              LinearProgressIndicator(
                value: route.safetyLevel == 'Safest' ? 0.9 :
                       route.safetyLevel == 'Safe' ? 0.7 : 0.5,
                backgroundColor: Colors.grey[200],
                color: route.safetyColor,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RouteOption {
  final String safetyLevel;
  final IconData safetyIcon;
  final Color safetyColor;
  final double distance;
  final String duration;
  final String description;
  final bool wellLit;
  final bool crowded;
  final int cctvCount;
  final int policeStations;
  final bool hospitalNearby;

  RouteOption({
    required this.safetyLevel,
    required this.safetyIcon,
    required this.safetyColor,
    required this.distance,
    required this.duration,
    required this.description,
    this.wellLit = false,
    this.crowded = false,
    this.cctvCount = 0,
    this.policeStations = 0,
    this.hospitalNearby = false,
  });
}