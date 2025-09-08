import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

// -------------------- MODEL --------------------
class OpenCenter {
  final String name;
  final String address;
  final String window;
  OpenCenter({required this.name, required this.address, required this.window});
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
  late Future<List<OpenCenter>> _futureCenters;

  @override
  void initState() {
    super.initState();
    _futureCenters = _loadCenters();
  }

  Future<List<OpenCenter>> _loadCenters() async {
    final csvText =
        await rootBundle.loadString('assets/Houston_Cooling_Centers.csv');
    final service = CoolingCentersService();
    return service.openNowFromCsv(csvText);
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
                      'Open Cooling Centers',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find a safe, cool place near you',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<OpenCenter>>(
                  future: _futureCenters,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No centers open right now.', style: TextStyle(fontSize: 18, color: Colors.black54)));
                    } else {
                      final centers = snapshot.data!;
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
