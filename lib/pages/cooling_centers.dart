import 'package:flutter/material.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

// -------------------- MODEL --------------------
class OpenCenter {
  final String name;
  final String address;
  final String window;
  final double? lat;
  final double? lon;
  double? distance; // <-- Add this field

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

    final open = <OpenCenter>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final name = (row.length > nameIdx) ? row[nameIdx].toString().trim() : '';
      final address =
          (addrIdx >= 0 && row.length > addrIdx) ? row[addrIdx].toString().trim() : '';
      final window =
          (row.length > dayIdx) ? row[dayIdx].toString().trim() : '';

      if (name.isEmpty || window.isEmpty || !window.contains('-')) continue;

      final anchor =
          tz.TZDateTime(_chicago, nowCt.year, nowCt.month, nowCt.day);
      try {
        final (start, end) = _parseRange(window, anchor);
        if (start.isBefore(nowCt) && nowCt.isBefore(end)) {
          open.add(OpenCenter(name: name, address: address, window: window));
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

// -------------------- UI PAGE --------------------
class CoolingCentersPage extends StatefulWidget {
  @override
  _CoolingCentersPageState createState() => _CoolingCentersPageState();
}

class _CoolingCentersPageState extends State<CoolingCentersPage> {
  double _deg2rad(double deg) => deg * (pi / 180);

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 3958.8; // Earth radius in miles
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<List<OpenCenter>> _getClosestCenters(List<OpenCenter> centers) async {
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userLat = position.latitude;
      final userLon = position.longitude;
      for (var c in centers) {
        if (c.lat != null && c.lon != null) {
          c.distance = _haversine(userLat, userLon, c.lat!, c.lon!);
        } else {
          c.distance = double.infinity;
        }
      }
      centers.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
      return centers.take(10).toList();
    } catch (e) {
      return centers.take(10).toList();
    }
  }
  late Future<List<OpenCenter>> _futureOpenCenters;
  late Future<List<OpenCenter>> _futureAllCenters;
  bool showOpenOnly = true;

  @override
  void initState() {
  super.initState();
  _futureOpenCenters = _loadCenters(openOnly: true);
  _futureAllCenters = _loadCenters(openOnly: false);
  }

  Future<List<OpenCenter>> _loadCenters({required bool openOnly}) async {
    final csvText = await rootBundle.loadString('assets/Houston_Cooling_Centers.csv');
    final service = CoolingCentersService();
    if (openOnly) {
      // Add lat/lon to OpenCenter objects
      final rows = const CsvToListConverter().convert(csvText);
      if (rows.isEmpty) return [];
      final header = rows.first.map((e) => e.toString().trim()).toList();
      final nameIdx = header.indexOf('Name');
      final addrIdx = header.indexOf('Address');
      final dayIdx = header.indexOf(service._weekdayName(tz.TZDateTime.now(service._chicago).weekday));
      final latIdx = header.indexOf('Lat');
      final lonIdx = header.indexOf('Lon');
      final open = <OpenCenter>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final name = (row.length > nameIdx) ? row[nameIdx].toString().trim() : '';
        final address = (addrIdx >= 0 && row.length > addrIdx) ? row[addrIdx].toString().trim() : '';
        final window = (row.length > dayIdx) ? row[dayIdx].toString().trim() : '';
        final lat = (latIdx >= 0 && row.length > latIdx) ? double.tryParse(row[latIdx].toString()) : null;
        final lon = (lonIdx >= 0 && row.length > lonIdx) ? double.tryParse(row[lonIdx].toString()) : null;
        if (name.isEmpty || window.isEmpty || !window.contains('-')) continue;
        open.add(OpenCenter(name: name, address: address, window: window, lat: lat, lon: lon));
      }
      return open;
    } else {
      // Parse all centers, regardless of open status
      final rows = const CsvToListConverter().convert(csvText);
      if (rows.isEmpty) return [];
      final header = rows.first.map((e) => e.toString().trim()).toList();
      final nameIdx = header.indexOf('Name');
      final addrIdx = header.indexOf('Address');
      final todayName = service._weekdayName(tz.TZDateTime.now(service._chicago).weekday);
      final dayIdx = header.indexOf(todayName);
      final latIdx = header.indexOf('Lat');
      final lonIdx = header.indexOf('Lon');
      final all = <OpenCenter>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final name = (row.length > nameIdx) ? row[nameIdx].toString().trim() : '';
        final address = (addrIdx >= 0 && row.length > addrIdx) ? row[addrIdx].toString().trim() : '';
        final window = (row.length > dayIdx) ? row[dayIdx].toString().trim() : '';
        final lat = (latIdx >= 0 && row.length > latIdx) ? double.tryParse(row[latIdx].toString()) : null;
        final lon = (lonIdx >= 0 && row.length > lonIdx) ? double.tryParse(row[lonIdx].toString()) : null;
        if (name.isEmpty || window.isEmpty) continue;
        all.add(OpenCenter(name: name, address: address, window: window, lat: lat, lon: lon));
      }
      return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF74ebd5), Color(0xFFACB6E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showOpenOnly ? 'Open Cooling Centers' : 'All Cooling Centers',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      showOpenOnly ? 'Find a safe, cool place near you' : 'All available cooling centers',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: showOpenOnly ? Colors.blue[700] : Colors.grey[300],
                              foregroundColor: showOpenOnly ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                showOpenOnly = true;
                              });
                            },
                            child: const Text('Open Now'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !showOpenOnly ? Colors.blue[700] : Colors.grey[300],
                              foregroundColor: !showOpenOnly ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setState(() {
                                showOpenOnly = false;
                              });
                            },
                            child: const Text('All Centers'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<OpenCenter>>(
                  future: showOpenOnly ? _futureOpenCenters : _futureAllCenters,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text(showOpenOnly ? 'No centers open right now.' : 'No centers found.', style: TextStyle(fontSize: 18, color: Colors.black54)));
                    } else {
                      return FutureBuilder<List<OpenCenter>>(
                        future: _getClosestCenters(snapshot.data!),
                        builder: (context, closestSnapshot) {
                          if (closestSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (closestSnapshot.hasError) {
                            return Center(child: Text('Error: ${closestSnapshot.error}', style: TextStyle(color: Colors.red)));
                          } else if (!closestSnapshot.hasData || closestSnapshot.data!.isEmpty) {
                            return Center(child: Text('No centers found.', style: TextStyle(fontSize: 18, color: Colors.black54)));
                          } else {
                            final centers = closestSnapshot.data!;
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              itemCount: centers.length,
                              itemBuilder: (context, i) {
                                final c = centers[i];
                                return Card(
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(Icons.ac_unit, size: 22, color: Colors.blue[700]),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                                                  const SizedBox(width: 2),
                                                  Expanded(
                                                    child: Text(
                                                      c.address,
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 14, color: Colors.grey[700]),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Hours: ${c.window}',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                                  ),
                                                ],
                                              ),
                                              if (c.distance != null && c.distance != double.infinity)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.directions_walk, size: 14, color: Colors.green[700]),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${c.distance!.toStringAsFixed(2)} miles away',
                                                        style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
