import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer' as developer;

enum TransportationMode {
  driving,
  walking,
  cycling,
}

enum NavigationMode {
  preview,
  navigating,
}

class NavigationPage extends StatefulWidget {
  final Map<String, dynamic> center;
  final Position? userLocation;

  const NavigationPage({
    super.key,
    required this.center,
    this.userLocation,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  MapBoxNavigation? _directions;
  MapBoxOptions? _options;
  MapBoxNavigationViewController? _controller;

  GoogleMapController? _previewMapController; 
  CameraPosition? _previewCameraPosition;    // NEW
  Set<Marker> _previewMarkers = const {};    // NEW

  NavigationMode _currentMode = NavigationMode.preview;
  Position? _currentLocation;
  String? _instruction = 'Ready to navigate';
  double? _distanceRemaining;
  double? _durationRemaining;
  String? _nextManeuver;
  
  TransportationMode _selectedMode = TransportationMode.driving; // Default to driving

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.userLocation;
    _setupPreview();
  }

  void _setupPreview() {
    final destLat = widget.center['lat']?.toDouble();
    final destLon = widget.center['lon']?.toDouble();
    if (destLat == null || destLon == null) return;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(destLat, destLon),
        infoWindow: InfoWindow(
          title: widget.center['name'] ?? 'Cooling Center',
        ),
      ),
    };

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    setState(() {
      _previewMarkers = markers;
      _previewCameraPosition = CameraPosition(
        target: LatLng(destLat, destLon),
        zoom: 15,
      );
    });
  }

  MapBoxNavigationMode _getMapBoxMode() {
    switch (_selectedMode) {
      case TransportationMode.driving:
        return MapBoxNavigationMode.driving;
      case TransportationMode.walking:
        return MapBoxNavigationMode.walking;
      case TransportationMode.cycling:
        return MapBoxNavigationMode.cycling;
    }
  }

  Widget _buildTransportationModeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildModeButton(TransportationMode.driving, Icons.directions_car, 'Drive'),
          _buildModeButton(TransportationMode.walking, Icons.directions_walk, 'Walk'),
          _buildModeButton(TransportationMode.cycling, Icons.directions_bike, 'Bike'),
        ],
      ),
    );
  }

  Widget _buildModeButton(TransportationMode mode, IconData icon, String label) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
          if (_currentMode == NavigationMode.preview) {
            _setupPreview();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[600] : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNavigation() async {
    try {
      await _initializeNavigation();

      double? destLat = widget.center['lat']?.toDouble();
      double? destLon = widget.center['lon']?.toDouble();

      if (destLat == null || destLon == null) {
        throw Exception('Invalid destination coordinates');
      }

      if (_currentLocation == null) {
        _currentLocation = await _getCurrentLocation();
      }

      // CHANGED: Updated options for actual navigation
      _options = MapBoxOptions(
        initialLatitude: _currentLocation!.latitude,
        initialLongitude: _currentLocation!.longitude,
        zoom: 18.0,
        tilt: 60.0,
        bearing: 0.0,
        enableRefresh: true,
        alternatives: false,
        voiceInstructionsEnabled: true, // CHANGED: Enable voice for navigation
        bannerInstructionsEnabled: true,
        allowsUTurnAtWayPoints: true,
        mode: _getMapBoxMode(),
        units: VoiceUnits.imperial,
        simulateRoute: false, // CHANGED: Set to false for real navigation
        animateBuildRoute: true,
        longPressDestinationEnabled: false,
        language: "en",
      );

      final List<WayPoint> wayPoints = [
        WayPoint(
          name: "Start",
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
        ),
        WayPoint(
          name: widget.center['name'] ?? 'Destination',
          latitude: destLat,
          longitude: destLon,
        ),
      ];

      // CHANGED: Start navigation and immediately switch to navigation mode
      await _directions!.startNavigation(
        wayPoints: wayPoints,
        options: _options!,
      );

      // CHANGED: Set to navigating mode immediately after starting
      if (mounted) {
        setState(() {
          _currentMode = NavigationMode.navigating;
          _instruction = 'Starting navigation...';
        });
      }

    } catch (e) {
      developer.log('Start navigation error: $e');
      if (mounted) {
        setState(() {
          _instruction = 'Failed to start navigation: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _initializeNavigation() async {
    await _requestPermissions();
    _directions = MapBoxNavigation.instance;
    _directions!.registerRouteEventListener(_onRouteEvent);
  }

  Future<void> _stopNavigation() async {
    try {
      if (_directions != null) {
        await _directions!.finishNavigation();
      }
      Navigator.pop(context);
    } catch (e) {
      developer.log('Stop navigation error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final locationStatus = await Permission.location.request();
    if (locationStatus.isDenied) {
      throw Exception('Location permission required');
    }
  }

  Future<Position> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permissions required');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).timeout(const Duration(seconds: 15));
  }

  void _onRouteEvent(dynamic event) {
    try {
      if (event != null && mounted) {
        String? eventType = event['eventType'] as String?;
        
        switch (eventType) {
          case 'navigation.instruction':
          case 'route_progress':
            // CHANGED: Ensure we're in navigation mode when receiving navigation events
            if (_currentMode != NavigationMode.navigating) {
              setState(() {
                _currentMode = NavigationMode.navigating;
              });
            }
            _handleNavigationProgress(event);
            break;
          case 'navigation.arrival':
            _handleArrival(event);
            break;
          case 'navigation.off_route':
            setState(() {
              _instruction = 'Recalculating route...';
            });
            break;
          case 'navigation.started': // CHANGED: Handle navigation started event
            setState(() {
              _currentMode = NavigationMode.navigating;
              _instruction = 'Navigation started';
            });
            break;
          default:
            developer.log('Unhandled route event: $eventType');
            break;
        }
      }
    } catch (e) {
      developer.log('Route event error: $e');
    }
  }

  void _handleNavigationProgress(dynamic event) {
    if (!mounted) return;
    
    setState(() {
      if (event['instruction'] != null) {
        _instruction = event['instruction'];
      }
      if (event['distance'] != null) {
        _distanceRemaining = (event['distance'] as num).toDouble();
      }
      if (event['duration'] != null) {
        _durationRemaining = (event['duration'] as num).toDouble();
      }
      if (event['maneuver'] != null) {
        _nextManeuver = event['maneuver'];
      }
    });
  }

  void _handleArrival(dynamic event) {
    setState(() {
      _instruction = 'You have arrived!';
    });
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters >= 1609.34) {
      return '${(meters / 1609.34).toStringAsFixed(1)} mi';
    } else {
      return '${(meters * 3.28084).round()} ft';
    }
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '';
    final int totalSeconds = seconds.round();
    final int minutes = (totalSeconds / 60).round();
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    } else {
      return '${minutes}m';
    }
  }

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver?.toLowerCase()) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'straight':
        return Icons.straight;
      case 'uturn':
        return Icons.u_turn_left;
      default:
        return Icons.navigation;
    }
  }

  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.center['name'] ?? 'Cooling Center',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Transportation selector BELOW the AppBar
          _buildTransportationModeSelector(),
          const SizedBox(height: 8),
          // Map takes remaining space
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _previewCameraPosition == null
                    ? Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : GoogleMap(
                        initialCameraPosition: _previewCameraPosition!,
                        markers: _previewMarkers,
                        zoomControlsEnabled: false,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        onMapCreated: (controller) => _previewMapController = controller,
                      ),
              ),
            ),
          ),
          // Start button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  // CHANGED: Show loading state while starting navigation
                  setState(() {
                    _instruction = 'Starting navigation...';
                  });
                  await _startNavigation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Start ${_selectedMode == TransportationMode.driving ? 'Driving' : _selectedMode == TransportationMode.walking ? 'Walking' : 'Cycling'} Navigation', // CHANGED: Show selected mode
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationScreen() {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          if (_options != null)
            MapBoxNavigationView(
              options: _options!,
              onRouteEvent: _onRouteEvent,
              onCreated: (MapBoxNavigationViewController controller) {
                _controller = controller;
              },
            )
          else
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          
          // Bottom instruction bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _stopNavigation,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instruction ?? 'Navigating...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_distanceRemaining != null && _durationRemaining != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDistance(_distanceRemaining)} • ${_formatDuration(_durationRemaining)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _getManeuverIcon(_nextManeuver),
                      color: Colors.blue[600],
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentMode) {
      case NavigationMode.preview:
        return _buildPreviewScreen();
      case NavigationMode.navigating:
        return _buildNavigationScreen();
    }
  }

  @override
  void dispose() {
    _directions?.finishNavigation();
    super.dispose();
  }
}