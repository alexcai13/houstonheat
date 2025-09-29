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
  bool _isInitializing = true;
  String? _errorMessage;
  Position? _currentLocation;
  String? _instruction = 'Ready to navigate';
  double? _distanceRemaining;
  double? _durationRemaining;
  String? _nextManeuver;
  double? _estimatedDistance;
  String? _estimatedDuration;

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
    
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      // Request permissions
      await _requestPermissions();

      // Get current location if not provided
      if (_currentLocation == null) {
        _currentLocation = await _getCurrentLocation();
      }

      // Initialize MapBox Navigation
      _directions = MapBoxNavigation.instance;
      _directions!.registerRouteEventListener(_onRouteEvent);

      // Configure navigation options
      _options = MapBoxOptions(
        initialLatitude: _currentLocation!.latitude,
        initialLongitude: _currentLocation!.longitude,
        zoom: 14.0,
        tilt: 0.0,
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

      // Calculate route info for preview
      await _calculateRouteInfo();

      setState(() {
        _isInitializing = false;
        _currentMode = NavigationMode.preview;
      });

      // Start animations
      _fadeController.forward();
      _slideController.forward();

    } catch (e) {
      developer.log('Navigation initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
        _isInitializing = false;
      });
    }
  }

  Future<void> _calculateRouteInfo() async {
    try {
      double? destLat = widget.center['lat']?.toDouble();
      double? destLon = widget.center['lon']?.toDouble();

      if (destLat == null || destLon == null || _currentLocation == null) {
        return;
      }

      // Calculate straight-line distance for estimate
      final double distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        destLat,
        destLon,
      );

      setState(() {
        _estimatedDistance = distance;
        // Estimate time based on average city driving (25 mph = 11.18 m/s)
        _estimatedDuration = _formatDuration((distance / 11.18).round());
      });

    } catch (e) {
      developer.log('Route calculation error: $e');
    }
  }

  Future<void> _startNavigation() async {
    if (_directions == null || _options == null || _currentLocation == null) {
      return;
    }

    try {
      setState(() {
        _currentMode = NavigationMode.navigating;
        _instruction = 'Starting navigation...';
      });

      // Animate transition to navigation mode
      await _slideController.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
      await _slideController.forward();

      double? destLat = widget.center['lat']?.toDouble();
      double? destLon = widget.center['lon']?.toDouble();

      if (destLat == null || destLon == null) {
        throw Exception('Invalid destination coordinates');
      }

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

      await _directions!.startNavigation(
        wayPoints: wayPoints,
        options: _options!,
      );

    } catch (e) {
      developer.log('Start navigation error: $e');
      setState(() {
        _currentMode = NavigationMode.preview;
        _instruction = 'Failed to start navigation';
      });
    }
  }

  Future<void> _stopNavigation() async {
    try {
      if (_directions != null) {
        await _directions!.finishNavigation();
      }
      
      setState(() {
        _currentMode = NavigationMode.preview;
        _instruction = 'Navigation stopped';
        _distanceRemaining = null;
        _durationRemaining = null;
        _nextManeuver = null;
      });

      // Animate back to preview
      await _slideController.reverse();
      await Future.delayed(const Duration(milliseconds: 200));
      await _slideController.forward();

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

  String _formatDuration(int seconds) {
    final int minutes = (seconds / 60).round();
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
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.center['name'] ?? 'Cooling Center',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.center['address'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.center['address'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Route info
                if (_estimatedDistance != null && _estimatedDuration != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.access_time, color: Colors.white, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                _estimatedDuration!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Estimated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.straighten, color: Colors.white, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                _formatDistance(_estimatedDistance),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Distance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Map Preview
          Expanded(
            flex: 3,
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
                child: Stack(
                  children: [
                    // Embedded map preview
                    if (_options != null)
                      MapBoxNavigationView(
                        options: _options!,
                        onRouteEvent: _onRouteEvent,
                        onCreated: (MapBoxNavigationViewController controller) {
                          _controller = controller;
                        },
                      ),
                    
                    // Overlay to prevent interaction
                    Container(
                      color: Colors.transparent,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Route Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Action buttons
          Expanded(
            flex: 1,
            child: Padding(
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
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _startNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 4,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Start Navigation',
                                style: TextStyle(
                                  fontSize: 18,
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
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          // Add phone call functionality
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[600],
                          side: BorderSide(color: Colors.blue[600]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, size: 20, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Call Center',
                              style: TextStyle(
                                fontSize: 16,
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
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
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
                        icon: const Icon(Icons.arrow_back),
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
                                '${_formatDistance(_distanceRemaining)} • ${_formatDuration(_durationRemaining!.round())}',
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
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom stop button
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: SafeArea(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_slideController),
                child: Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _stopNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Stop Navigation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Loading Route...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
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
                  onPressed: _initializeNavigation,
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
}

enum NavigationMode {
  preview,
  navigating,
}