import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

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

class _NavigationPageState extends State<NavigationPage> 
    with TickerProviderStateMixin {
  MapBoxNavigation? _directions;
  MapBoxOptions? _options;
  MapBoxNavigationViewController? _controller;
  
  // Navigation states
  NavigationMode _currentMode = NavigationMode.preview;
  String? _errorMessage;
  Position? _currentLocation;
  String? _instruction = 'Ready to navigate';
  double? _distanceRemaining;
  double? _durationRemaining;
  String? _nextManeuver;
  
  // Route information
  double? _routeDistance;
  double? _routeDuration;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.userLocation;
    
    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Show preview immediately
    _showPreviewImmediately();
  }

  void _showPreviewImmediately() {
    // Calculate estimates and setup map for cooling center location
    _calculateStraightLineDistance();
    _setupMapOptionsForCoolingCenter();
    
    setState(() {
      _currentMode = NavigationMode.preview;
    });

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  void _setupMapOptionsForCoolingCenter() {
    // Set up map options to show the cooling center location
    double? destLat = widget.center['lat']?.toDouble();
    double? destLon = widget.center['lon']?.toDouble();
    
    if (destLat != null && destLon != null) {
      _options = MapBoxOptions(
        initialLatitude: destLat, // Focus on cooling center
        initialLongitude: destLon, // Focus on cooling center
        zoom: 15.0, // Good zoom to see the location clearly
        tilt: 0.0,
        bearing: 0.0,
        enableRefresh: true,
        alternatives: false,
        voiceInstructionsEnabled: false,
        bannerInstructionsEnabled: false,
        allowsUTurnAtWayPoints: false,
        mode: MapBoxNavigationMode.driving,
        units: VoiceUnits.imperial,
        simulateRoute: false,
        animateBuildRoute: false, // No auto route building
        longPressDestinationEnabled: false,
        language: "en",
      );
    }
  }

  void _calculateStraightLineDistance() {
    try {
      double? destLat = widget.center['lat']?.toDouble();
      double? destLon = widget.center['lon']?.toDouble();

      if (destLat != null && destLon != null && _currentLocation != null) {
        final double distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          destLat,
          destLon,
        );

        setState(() {
          _routeDistance = distance * 1.3; // Add 30% for realistic driving distance
          _routeDuration = (distance * 1.3) / 11.18; // Estimate based on 25 mph average
        });
      }
    } catch (e) {
      developer.log('Estimate calculation error: $e');
    }
  }

  Future<void> _startNavigation() async {
    try {
      // Initialize navigation if not ready
      if (_directions == null) {
        await _initializeNavigation();
      }

      double? destLat = widget.center['lat']?.toDouble();
      double? destLon = widget.center['lon']?.toDouble();

      if (destLat == null || destLon == null) {
        throw Exception('Invalid destination coordinates');
      }

      // Get current location for navigation
      if (_currentLocation == null) {
        _currentLocation = await _getCurrentLocation();
      }

      // Update options for navigation mode
      _options = MapBoxOptions(
        initialLatitude: _currentLocation!.latitude,
        initialLongitude: _currentLocation!.longitude,
        zoom: 18.0,
        tilt: 60.0,
        bearing: 0.0,
        enableRefresh: true,
        alternatives: false,
        voiceInstructionsEnabled: false,
        bannerInstructionsEnabled: true,
        allowsUTurnAtWayPoints: true,
        mode: MapBoxNavigationMode.driving,
        units: VoiceUnits.imperial,
        simulateRoute: false,
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

      // Start navigation first, then switch mode only when it's actually started
      await _directions!.startNavigation(
        wayPoints: wayPoints,
        options: _options!,
      );

      // Only switch to navigation mode after MapBox navigation has started
      setState(() {
        _currentMode = NavigationMode.navigating;
      });

    } catch (e) {
      developer.log('Start navigation error: $e');
      setState(() {
        _currentMode = NavigationMode.preview;
        _instruction = 'Failed to start navigation';
      });
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
      
      setState(() {
        _currentMode = NavigationMode.preview;
        _instruction = 'Ready to navigate';
        _distanceRemaining = null;
        _durationRemaining = null;
        _nextManeuver = null;
      });

      // Reset to cooling center view
      _setupMapOptionsForCoolingCenter();

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
      if (event != null && mounted && _currentMode == NavigationMode.navigating) {
        String? eventType = event['eventType'] as String?;
        
        switch (eventType) {
          case 'navigation.instruction':
          case 'route_progress':
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
          default:
            break;
        }
      }
    } catch (e) {
      developer.log('Route event error: $e');
    }
  }

  void _handleNavigationProgress(dynamic event) {
    if (!mounted || _currentMode != NavigationMode.navigating) return;
    
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
      _currentMode = NavigationMode.preview;
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
          // Map Preview - takes most space (removed route info header)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
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
                child: _options != null
                    ? MapBoxNavigationView(
                        options: _options!,
                        onRouteEvent: _onRouteEvent,
                        onCreated: (MapBoxNavigationViewController controller) {
                          _controller = controller;
                          _moveCameraToCoolingCenter();
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
              ),
            ),
          ),
          
          // Bottom action buttons (unchanged)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Start Navigation Button
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _startNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                          elevation: 4,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Start Navigation',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Call button (if phone number available)
                if (widget.center['phone'] != null)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        // Add phone call functionality
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                        side: BorderSide(color: Colors.blue[600]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, size: 18, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Call Center',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
          MapBoxNavigationView(
            options: _options!,
            onRouteEvent: _onRouteEvent,
            onCreated: (MapBoxNavigationViewController controller) {
              _controller = controller;
            },
          ),
          
          // Top instruction bar
          SafeArea(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _routeDistance == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 20),
                Text(
                  'Navigation Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _showPreviewImmediately();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Return appropriate screen based on mode
    switch (_currentMode) {
      case NavigationMode.preview:
        return _buildPreviewScreen();
      case NavigationMode.navigating:
        return _buildNavigationScreen();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _directions?.finishNavigation();
    super.dispose();
  }

  void _moveCameraToCoolingCenter() {
    double? destLat = widget.center['lat']?.toDouble();
    double? destLon = widget.center['lon']?.toDouble();
    
    if (destLat != null && destLon != null && _controller != null && _currentLocation != null) {
      // Use a shorter delay and immediately build the route to show the preview
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_controller != null && mounted && _currentMode == NavigationMode.preview) {
          try {
            _controller!.buildRoute(wayPoints: [
              WayPoint(
                name: "Your Location",
                latitude: _currentLocation!.latitude,
                longitude: _currentLocation!.longitude,
              ),
              WayPoint(
                name: widget.center['name'] ?? 'Cooling Center',
                latitude: destLat,
                longitude: destLon,
              ),
            ]);
          } catch (e) {
            developer.log('Camera move error: $e');
          }
        }
      });
    }
  }
}

enum NavigationMode {
  preview,
  navigating,
}