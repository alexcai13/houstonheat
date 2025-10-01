import 'package:flutter/material.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'navigation.dart';

// -------------------- MODEL --------------------
class OpenCenter {
  final String name;
  final String address;
  final String window;
  final double? lat;
  final double? lon;
  double? distance;

  OpenCenter({
    required this.name,
    required this.address,
    required this.window,
    this.lat,
    this.lon,
    this.distance,
  });
}

// -------------------- SERVICE --------------------
class CoolingCentersService {
  CoolingCentersService() {
    tzdata.initializeTimeZones();
    _chicago = tz.getLocation('America/Chicago');
  }

  late final tz.Location _chicago;

  (tz.TZDateTime start, tz.TZDateTime end) _parseRange(
    String rng,
    tz.TZDateTime anchorDay,
  ) {
    final s = rng.replaceAll(' ', '');
    final parts = s.split('-');
    final left = parts[0];
    final right = parts[1];

    tz.TZDateTime _mk(String token) {
      final re = RegExp(r'^(\d{1,2}):(\d{2})(AM|PM)$', caseSensitive: false);
      final m = re.firstMatch(token);
      if (m == null) throw FormatException('Bad time: $token');
      var hour = int.parse(m.group(1)!);
      final minute = int.parse(m.group(2)!);
      final ap = m.group(3)!.toUpperCase();
      if (ap == 'PM' && hour != 12) hour += 12;
      if (ap == 'AM' && hour == 12) hour = 0;
      return tz.TZDateTime(
        _chicago,
        anchorDay.year,
        anchorDay.month,
        anchorDay.day,
        hour,
        minute,
      );
    }

    final start = _mk(left);
    final end = _mk(right);
    return (start, end);
  }

  List<OpenCenter> openNowFromCsv(String csvText, {tz.TZDateTime? now}) {
    final nowCt = now ?? tz.TZDateTime.now(_chicago);
    final todayName = _weekdayName(nowCt.weekday);

    final rows = const CsvToListConverter().convert(csvText);
    if (rows.isEmpty) return [];
    final header = rows.first.map((e) => e.toString().trim()).toList();

    final nameIdx = header.indexOf('Name');
    final addrIdx = header.indexOf('Address');
    final dayIdx = header.indexOf(todayName);

    final latIdx = header.indexOf('Lat');
    final lonIdx = header.indexOf('Lon');

    final open = <OpenCenter>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = (row.length > nameIdx) ? row[nameIdx].toString().trim() : '';
      final address =
          (addrIdx >= 0 && row.length > addrIdx) ? row[addrIdx].toString().trim() : '';
      final window =
          (row.length > dayIdx) ? row[dayIdx].toString().trim() : '';
      double? lat;
      double? lon;
      if (latIdx >= 0 && row.length > latIdx) {
      lat = double.tryParse(row[latIdx].toString().trim());
      }
      if (lonIdx >= 0 && row.length > lonIdx) {
      lon = double.tryParse(row[lonIdx].toString().trim());
      }
      if (name.isEmpty || window.isEmpty || !window.contains('-')) continue;

      final anchor =
          tz.TZDateTime(_chicago, nowCt.year, nowCt.month, nowCt.day);
      try {
        final (start, end) = _parseRange(window, anchor);
        if (start.isBefore(nowCt) && nowCt.isBefore(end)) {
          open.add(OpenCenter(name: name, address: address, window: window, lat: lat, lon: lon));
        }
      } catch (_) {
        continue;
      }
    }
    return open;
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }
}

// -------------------- ANIMATED WIDGETS --------------------
class AnimatedCenterCard extends StatefulWidget {
  final OpenCenter center;
  final int index;

  const AnimatedCenterCard({
    Key? key,
    required this.center,
    required this.index,
  }) : super(key: key);

  @override
  _AnimatedCenterCardState createState() => _AnimatedCenterCardState();
}

class _AnimatedCenterCardState extends State<AnimatedCenterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Add method to handle navigation
  Future<void> _navigateToCenter() async {
    try {
      // Get current location for navigation
      Position? currentLocation;
      try {
        currentLocation = await _getCurrentLocation();
      } catch (e) {
        print('Could not get current location: $e');
      }

      // Create center data map for navigation
      final centerData = {
        'name': widget.center.name,
        'address': widget.center.address,
        'lat': widget.center.lat,
        'lon': widget.center.lon,
        'window': widget.center.window,
      };

      // Navigate to navigation page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationPage(
              center: centerData,
              userLocation: currentLocation,
            ),
          ),
        );
      }
    } catch (e) {
      // Show error if navigation fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start navigation: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              child: InkWell( // Added InkWell for tap functionality
                onTap: _navigateToCenter, // Added tap handler
                borderRadius: BorderRadius.circular(20), // Match container border radius
                splashColor: Colors.blue.withOpacity(0.1), // Add splash effect
                highlightColor: Colors.blue.withOpacity(0.05), // Add highlight effect
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'cooling_icon_${widget.index}',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Colors.blue[400]!, Colors.cyan[300]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.ac_unit_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
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
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.center.address,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
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
                              if (widget.center.distance != null && widget.center.distance != double.infinity) ...[
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${widget.center.distance!.toStringAsFixed(1)} mi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Spacer(),
                                    // Add visual indicator that card is clickable
                                    Icon(
                                      Icons.navigation,
                                      size: 20,
                                      color: Colors.blue[600],
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
  }
}

class AnimatedToggleButton extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedToggleButton({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  _AnimatedToggleButtonState createState() => _AnimatedToggleButtonState();
}

class _AnimatedToggleButtonState extends State<AnimatedToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ));
  }
}

// -------------------- MAIN UI PAGE --------------------
class CoolingCentersPage extends StatefulWidget {
  @override
  _CoolingCentersPageState createState() => _CoolingCentersPageState();
}

class _CoolingCentersPageState extends State<CoolingCentersPage>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  double _deg2rad(double deg) => deg * (pi / 180);

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 3958.8;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<List<OpenCenter>> _getAllOpenCentersByDistance() async {
    try {
      // Get user location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      final userLat = position.latitude;
      final userLon = position.longitude;

      // Load and parse CSV
      final csvText = await rootBundle.loadString('assets/Houston_Cooling_Centers.csv');
      final service = CoolingCentersService();
      final openCenters = service.openNowFromCsv(csvText);

      // Calculate distances for all open centers
      for (var center in openCenters) {
        if (center.lat != null && center.lon != null) {
          center.distance = _haversine(userLat, userLon, center.lat!, center.lon!);
        } else {
          center.distance = double.infinity;
        }
      }

      // Sort by distance (closest first) and return ALL open centers
      openCenters.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
      return openCenters;
    } catch (e) {
      // If location fails, still get open centers but without distance sorting
      final csvText = await rootBundle.loadString('assets/Houston_Cooling_Centers.csv');
      final service = CoolingCentersService();
      return service.openNowFromCsv(csvText);
    }
  }

  late Future<List<OpenCenter>> _futureOpenCenters;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeInOut),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _futureOpenCenters = _getAllOpenCentersByDistance();
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 1.0], // Ensure smooth transition
                ),
              ),
              child: SafeArea(
                child: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCollapsed = constraints.maxHeight <= 80;
                      return Text(
                        'Open Cooling Centers',
                        style: TextStyle(
                          fontSize: isCollapsed ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: FutureBuilder<List<OpenCenter>>(
              future: _futureOpenCenters,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Finding open cooling centers...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                          SizedBox(height: 16),
                          Text(
                            'Error loading centers',
                            style: TextStyle(fontSize: 18, color: Colors.red[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No centers open right now',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check back during operating hours',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final centers = snapshot.data!;
                  return Column(
                    children: [
                      SizedBox(height: 16),
                      if (centers.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Icon(Icons.near_me, size: 18, color: Colors.blue[600]),
                              SizedBox(width: 8),
                              Text(
                                '${centers.length} centers open now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 8),
                      ...List.generate(
                        centers.length,
                        (index) => AnimatedCenterCard(
                          center: centers[index],
                          index: index,
                        ),
                      ),
                      SizedBox(height: 32),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ToggleHeaderDelegate({required this.child});

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// For geolocation:
Future<Position> _getCurrentLocation() async {
  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
}
