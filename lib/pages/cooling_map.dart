import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'cooling_centers.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class CoolingCenterDirectionsPage extends StatefulWidget {
  final OpenCenter center;

  const CoolingCenterDirectionsPage({
    Key? key,
    required this.center,
  }) : super(key: key);

  @override
  _CoolingCenterDirectionsPageState createState() => _CoolingCenterDirectionsPageState();
}

class _CoolingCenterDirectionsPageState extends State<CoolingCenterDirectionsPage> {
  Position? _currentLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = "Location services are disabled. Please enable location services.";
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = "Location permissions are denied. Please allow location access.";
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = "Location permissions are permanently denied. Please enable in settings.";
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(Duration(seconds: 15));

      setState(() {
        _currentLocation = position;
        _isLoading = false;
      });
      
      print('Got location: ${position.latitude}, ${position.longitude}');
      
    } catch (e) {
      print('Location error: $e');
      setState(() {
        _errorMessage = "Unable to get your location: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom App Bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Directions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            widget.center.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Map Container
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Getting your location...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 64, color: Colors.red[400]),
                            SizedBox(height: 16),
                            Text(
                              'Location Error',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _getCurrentLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        margin: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: InteractiveMap(
                            userLat: _currentLocation?.latitude ?? 29.7604,
                            userLon: _currentLocation?.longitude ?? -95.3698,
                            destinationAddress: widget.center.address,
                            destinationName: widget.center.name,
                          ),
                        ),
                      ),
          ),

          // Bottom Info Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.cyan[300]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.ac_unit_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.center.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.center.address,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.green[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    widget.center.window,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

// Enhanced Interactive Map Widget
class InteractiveMap extends StatefulWidget {
  final double userLat;
  final double userLon;
  final String destinationAddress;
  final String destinationName;

  const InteractiveMap({
    Key? key,
    required this.userLat,
    required this.userLon,
    required this.destinationAddress,
    required this.destinationName,
  }) : super(key: key);

  @override
  _InteractiveMapState createState() => _InteractiveMapState();
}

class _InteractiveMapState extends State<InteractiveMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = true;
  String _selectedMode = 'driving';
  List<Map<String, dynamic>> _steps = [];
  String? _duration;
  String? _distance;
  LatLng? _destinationLatLng;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _geocodeDestination();
    await _createMarkers();
    await _getDirections();
  }

  // Geocode the destination address to get coordinates
  Future<void> _geocodeDestination() async {
    try {
      final apiKey = "***REMOVED***";
      // Don't assume Houston - use the address as-is with just Texas
      final encodedAddress = Uri.encodeComponent("${widget.destinationAddress}, TX");
      final url = "https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$apiKey";
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          _destinationLatLng = LatLng(location['lat'].toDouble(), location['lng'].toDouble());
          print('Geocoded destination: ${_destinationLatLng}');
        } else {
          // Fallback: try without state
          final fallbackAddress = Uri.encodeComponent(widget.destinationAddress);
          final fallbackUrl = "https://maps.googleapis.com/maps/api/geocode/json?address=$fallbackAddress&key=$apiKey";
          final fallbackResponse = await http.get(Uri.parse(fallbackUrl));
          
          if (fallbackResponse.statusCode == 200) {
            final fallbackData = json.decode(fallbackResponse.body);
            if (fallbackData['results'] != null && fallbackData['results'].isNotEmpty) {
              final location = fallbackData['results'][0]['geometry']['location'];
              _destinationLatLng = LatLng(location['lat'].toDouble(), location['lng'].toDouble());
              print('Geocoded destination (fallback): ${_destinationLatLng}');
            }
          }
        }
        
        // Final fallback to center coordinates if available
        if (_destinationLatLng == null) {
          _destinationLatLng = LatLng(29.7604, -95.3698); // Generic fallback
          print('Using generic fallback coordinates');
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
      _destinationLatLng = LatLng(29.7604, -95.3698);
    }
  }

  Future<void> _createMarkers() async {
    if (_destinationLatLng == null) return;
    
    _markers = {
      Marker(
        markerId: MarkerId('user_location'),
        position: LatLng(widget.userLat, widget.userLon),
        infoWindow: InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: MarkerId('destination'),
        position: _destinationLatLng!,
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: widget.destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Future<void> _getDirections() async {
    if (_destinationLatLng == null) return;
    
    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
      _steps.clear();
      _duration = null;
      _distance = null;
    });

    try {
      final apiKey = "***REMOVED***";
      
      // Use coordinates for both origin and destination for better reliability
      final origin = "${widget.userLat},${widget.userLon}";
      final destination = "${_destinationLatLng!.latitude},${_destinationLatLng!.longitude}";
      
      // Build URL with mode-specific parameters
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=$origin&'
          'destination=$destination&'
          'mode=$_selectedMode&'
          'units=imperial&'
          'alternatives=false&'
          'key=$apiKey';
      
      // Add transit-specific parameters if needed
      if (_selectedMode == 'transit') {
        // Add current time for transit scheduling
        final departureTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        url += '&departure_time=$departureTime';
        url += '&transit_mode=bus|subway|train|tram';
      }

      print('Directions API URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('API Response status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Extract route information
          _duration = leg['duration']['text'];
          _distance = leg['distance']['text'];
          
          print('Route found: $_distance, $_duration');
          
          // Extract turn-by-turn steps
          _steps = [];
          for (var step in leg['steps']) {
            Map<String, dynamic> stepData = {
              'instruction': _removeHtmlTags(step['html_instructions']),
              'distance': step['distance']['text'],
              'duration': step['duration']['text'],
              'maneuver': step['maneuver'] ?? 'straight',
              'travel_mode': step['travel_mode'] ?? _selectedMode.toUpperCase(),
            };
            
            // Handle transit sub-steps
            if (_selectedMode == 'transit' && step['steps'] != null) {
              for (var subStep in step['steps']) {
                _steps.add({
                  'instruction': _removeHtmlTags(subStep['html_instructions']),
                  'distance': subStep['distance']['text'],
                  'duration': subStep['duration']['text'],
                  'maneuver': subStep['maneuver'] ?? 'straight',
                  'travel_mode': subStep['travel_mode'] ?? 'WALKING',
                });
              }
            } else {
              _steps.add(stepData);
            }
          }
          
          // Draw route polyline
          final polylinePoints = route['overview_polyline']['points'];
          final List<LatLng> polylineCoordinates = _decodePolyline(polylinePoints);
          
          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route_$_selectedMode'),
                points: polylineCoordinates,
                color: _getModeColor(),
                width: _getModeWidth(),
                patterns: _getModePatterns(),
              ),
            );
            _isLoadingRoute = false;
          });
          
          // Fit camera to show full route
          _fitCameraToRoute(polylineCoordinates);
          
        } else {
          // Handle specific API errors
          String errorMsg = 'No routes found';
          
          if (data['status'] == 'ZERO_RESULTS') {
            if (_selectedMode == 'transit') {
              errorMsg = 'No public transit routes available for this location';
            } else if (_selectedMode == 'bicycling') {
              errorMsg = 'No bike routes available for this location';
            } else {
              errorMsg = 'No ${_getModeLabel().toLowerCase()} routes found';
            }
          } else if (data['status'] == 'NOT_FOUND') {
            errorMsg = 'Location not found. Please check the address.';
          } else if (data['status'] == 'REQUEST_DENIED') {
            errorMsg = 'Directions request denied. Please try again.';
          } else if (data['error_message'] != null) {
            errorMsg = data['error_message'];
          }
          
          throw Exception(errorMsg);
        }
      } else {
        throw Exception('Directions API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting directions: $e');
      setState(() {
        _isLoadingRoute = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load ${_getModeLabel().toLowerCase()} directions: $e'),
            backgroundColor: Colors.red[600],
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _getDirections();
              },
            ),
          ),
        );
      }
    }
  }

  String _removeHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '');
  }

  Color _getModeColor() {
    switch (_selectedMode) {
      case 'driving':
        return Colors.blue[600]!;
      case 'walking':
        return Colors.green[600]!;
      case 'transit':
        return Colors.orange[600]!;
      case 'bicycling':
        return Colors.purple[600]!;
      default:
        return Colors.blue[600]!;
    }
  }

  IconData _getModeIcon() {
    switch (_selectedMode) {
      case 'driving':
        return Icons.directions_car;
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_bus;
      case 'bicycling':
        return Icons.directions_bike;
      default:
        return Icons.directions_car;
    }
  }

  String _getModeLabel() {
    switch (_selectedMode) {
      case 'driving':
        return 'Driving';
      case 'walking':
        return 'Walking';
      case 'transit':
        return 'Transit';
      case 'bicycling':
        return 'Biking';
      default:
        return 'Driving';
    }
  }

  void _fitCameraToRoute(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return;
    
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;
    
    for (LatLng coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }
    
    Future.delayed(Duration(milliseconds: 500), () {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - 0.005, minLng - 0.005),
              northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
            ),
            100.0,
          ),
        );
      }
    });
  }

  List<LatLng> _decodePolyline(String polylineString) {
    List<LatLng> polylineCoordinates = [];
    int index = 0, len = polylineString.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polylineString.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polylineString.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylineCoordinates;
  }

  void _showDirections() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Icon(_getModeIcon(), color: _getModeColor(), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_distance • $_duration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${_getModeLabel()} to ${widget.destinationName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1),
              
              // Turn-by-turn directions
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getModeColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getStepIcon(step['maneuver'], step['travel_mode']),
                              color: _getModeColor(),
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['instruction'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${step['distance']} • ${step['duration']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStepIcon(String maneuver, String travelMode) {
    // Handle different travel modes
    if (travelMode == 'WALKING') return Icons.directions_walk;
    if (travelMode == 'TRANSIT') return Icons.directions_bus;
    if (travelMode == 'BICYCLING') return Icons.directions_bike;
    
    // Handle maneuvers
    switch (maneuver.toLowerCase()) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'merge':
        return Icons.merge;
      case 'fork-left':
      case 'fork-right':
        return Icons.call_split;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_left;
      case 'ramp-left':
      case 'ramp-right':
        return Icons.ramp_left;
      default:
        return Icons.straight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.userLat, widget.userLon),
            zoom: 12,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        
        // Transportation mode selector
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),  
              ],
            ),
            child: Row(
              children: [
                _buildModeButton('driving', Icons.directions_car),
                _buildModeButton('walking', Icons.directions_walk),
                _buildModeButton('transit', Icons.directions_bus),
                _buildModeButton('bicycling', Icons.directions_bike),
              ],
            ),
          ),
        ),
        
        // Zoom controls
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              _buildZoomButton(Icons.add, () {
                _mapController?.animateCamera(CameraUpdate.zoomIn());
              }),
              SizedBox(height: 8),
              _buildZoomButton(Icons.remove, () {
                _mapController?.animateCamera(CameraUpdate.zoomOut());
              }),
            ],
          ),
        ),
        
        // Directions button with better error handling
        if (!_isLoadingRoute && _duration != null && _distance != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _steps.isNotEmpty ? _showDirections : null,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _steps.isNotEmpty ? _getModeColor() : Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (_steps.isNotEmpty ? _getModeColor() : Colors.grey[400]!).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getModeIcon(), color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _steps.isNotEmpty 
                            ? 'View Directions • $_distance • $_duration'
                            : 'Route info: $_distance • $_duration',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Loading indicator
        if (_isLoadingRoute)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading ${_getModeLabel().toLowerCase()} route...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModeButton(String mode, IconData icon) {
    final isSelected = _selectedMode == mode;
    final isEnabled = _isTransportModeAvailable(mode);
    
    return GestureDetector(
      onTap: isEnabled ? () {
        setState(() {
          _selectedMode = mode;
        });
        _getDirections();
      } : null,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _getModeColor() : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isEnabled 
              ? (isSelected ? Colors.white : Colors.grey[600])
              : Colors.grey[400],
          size: 20,
        ),
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.grey[700]),
      ),
    );
  }

  int _getModeWidth() {
    switch (_selectedMode) {
      case 'walking':
        return 3;
      case 'bicycling':
        return 4;
      case 'transit':
        return 6;
      case 'driving':
      default:
        return 5;
    }
  }

  List<PatternItem> _getModePatterns() {
    switch (_selectedMode) {
      case 'walking':
        return [PatternItem.dash(15), PatternItem.gap(8)];
      case 'bicycling':
        return [PatternItem.dash(10), PatternItem.gap(5)];
      case 'transit':
        return [PatternItem.dash(25), PatternItem.gap(15)];
      case 'driving':
      default:
        return [];
    }
  }

  bool _isTransportModeAvailable(String mode) {
    // You could implement logic here to check if certain modes are available
    // For now, we'll assume all modes are available but handle errors gracefully
    return true;
  }
}