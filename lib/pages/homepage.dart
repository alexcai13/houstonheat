import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';

IconData getWeatherIcon(String? condition) {
  if (condition == null) return Icons.help_outline;
  final cond = condition.toLowerCase();
  if (cond.contains('cloud') && cond.contains('partly')) return Icons.cloud_queue;
  if (cond.contains('cloud')) return Icons.cloud;
  if (cond.contains('sun') || cond.contains('clear')) return Icons.wb_sunny;
  if (cond.contains('rain')) return Icons.grain;
  if (cond.contains('storm')) return Icons.flash_on;
  if (cond.contains('snow')) return Icons.ac_unit;
  return Icons.wb_cloudy;
}

Color tempToColor(double tempF) {
  // Blue for cold, red for hot, yellow for warm
  if (tempF < 60) return Colors.blue[200]!;
  if (tempF < 80) return Colors.yellow[200]!;
  return Colors.red[200]!;
}

class WeatherScreen extends StatefulWidget {
  final double lat;
  final double lon;
  final String cityName;

  const WeatherScreen({
    super.key,
    this.lat = 29.7604,
    this.lon = -95.3698,
    this.cityName = "Houston",
  });

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  double? currentTempF;
  double? feelsLikeF;
  String? condition;
  String? iconBaseUri;
  List<Map<String, dynamic>> hourlyForecast = [];
  bool showActualTemp = true; // <-- Add this toggle state

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  double _cToF(double c) => (c * 9 / 5) + 32;

  Future<void> fetchWeather() async {
    final apiKey = "***REMOVED***";
    final currentUrl =
        "https://weather.googleapis.com/v1/currentConditions:lookup"
        "?location.latitude=${widget.lat}&location.longitude=${widget.lon}&key=$apiKey";
    final forecastUrl =
        "https://weather.googleapis.com/v1/forecast/hours:lookup?key=$apiKey&location.latitude=${widget.lat}&location.longitude=${widget.lon}&hours=12";

    final currentRes = await http.get(Uri.parse(currentUrl));
    final forecastRes = await http.get(Uri.parse(forecastUrl));

    if (currentRes.statusCode == 200 && forecastRes.statusCode == 200) {
      final currentData = jsonDecode(currentRes.body);
      final forecastData = jsonDecode(forecastRes.body);

      final now = DateTime.now();
      final currentHour = now.hour;

      setState(() {
        currentTempF =
            _cToF((currentData['temperature']['degrees'] as num).toDouble());
        feelsLikeF = _cToF(
            (currentData['feelsLikeTemperature']['degrees'] as num).toDouble());
  condition = currentData['weatherCondition']['description']['text'];
  iconBaseUri = currentData['weatherCondition']['iconBaseUri'];


      hourlyForecast = List<Map<String, dynamic>>.from(
        (forecastData['forecastHours'] as List)
          .map((entry) {
            final hours = entry['displayDateTime']['hours'] as int;
            return {
              "time": "${hours % 12 == 0 ? 12 : hours % 12}${hours >= 12 ? "PM" : "AM"}",
              "temp": _cToF((entry['temperature']['degrees'] as num).toDouble()),
              "feels": _cToF((entry['feelsLikeTemperature']['degrees'] as num).toDouble()),
              "condition": entry['weatherCondition']['description']['text'],
              "iconBaseUri": entry['weatherCondition']['iconBaseUri'],
            };
          }),
      );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.manrope(color: Colors.black);

    return Scaffold(
      backgroundColor: Colors.white,
      body: currentTempF == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City name at top
                    Center(
                      child: Text(
                        widget.cityName,
                        style: textStyle.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Condition + Big Temp row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        iconBaseUri != null
                            ? SvgPicture.network(
                                iconBaseUri! + '.svg',
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.help_outline, size: 60),
                              )
                            : Icon(Icons.help_outline, size: 60),
                        const SizedBox(width: 12),
                        Text(condition ?? "",
                            style: textStyle.copyWith(
                                fontSize: 20, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${currentTempF?.toStringAsFixed(0)}°F",
                                style: textStyle.copyWith(
                                    fontSize: 54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Feels like: ${feelsLikeF?.toStringAsFixed(0)}°F",
                                style: textStyle.copyWith(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

            
                    // Times and graph, horizontally scrollable, points aligned with times
                    SizedBox(
                      height: 220,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: hourlyForecast.length * 60,
                          child: Column(
                            children: [
                              // Times row
                              SizedBox(
                                height: 40,
                                child: Row(
                                  children: [
                                    for (int i = 0; i < hourlyForecast.length; i++)
                                      SizedBox(
                                        width: 60,
                                        child: Center(
                                          child: Text(
                                            hourlyForecast[i]['time'],
                                            style: textStyle.copyWith(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Graph area
                              SizedBox(
                                height: 180,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final chartHeight = constraints.maxHeight;
                                    final topPadding = 20.0;
                                    final bottomPadding = 20.0;
                                    final dotSize = 7.0;

                                    // Use BOTH temp and feels like for min/max so both graphs use the same scale
                                    final allTemps = [
                                      ...hourlyForecast.map((e) => e['temp'] as double),
                                      ...hourlyForecast.map((e) => e['feels'] as double),
                                    ];
                                    final minY = allTemps.reduce((a, b) => a < b ? a : b);
                                    final maxY = allTemps.reduce((a, b) => a > b ? a : b);
                                    final tempRange = (maxY - minY) == 0 ? 1 : (maxY - minY);

                                    // Choose which temperature to show
                                    final temps = hourlyForecast
                                        .map((e) => showActualTemp ? e['temp'] as double : e['feels'] as double)
                                        .toList();

                                    double getY(double temp) {
                                      final availableHeight = chartHeight - dotSize - topPadding - bottomPadding;
                                      return ((maxY - temp) / tempRange) * availableHeight + topPadding;
                                    }

                                    final points = <Offset>[
                                      for (int i = 0; i < hourlyForecast.length; i++)
                                        Offset(60.0 * i + 30.0, getY(temps[i]) + dotSize / 2)
                                    ];

                                    return Stack(
                                      children: [
                                        // Draw icons + labels for each point (no line, no dots)
                                        for (int i = 0; i < hourlyForecast.length; i++) ...[
                                          // Weather icon at the point
                                          Positioned(
                                            left: 60.0 * i + 30.0 - 13, // center the icon
                                            top: getY(temps[i]),
                                            child: hourlyForecast[i]['iconBaseUri'] != null
                                                ? Image.network(
                                                    hourlyForecast[i]['iconBaseUri'] + '.png',
                                                    width: 18,
                                                    height: 18,
                                                    errorBuilder: (context, error, stackTrace) => Icon(Icons.help_outline, size: 18, color: Colors.grey[700]),
                                                  )
                                                : Icon(Icons.help_outline, size: 18, color: Colors.grey[700]),
                                          ),
                                          // Label above the icon
                                          Positioned(
                                            left: 60.0 * i + 30.0 - 15,
                                            top: getY(temps[i]) - 23,
                                            child: Text(
                                              "${temps[i].toStringAsFixed(0)}°F",
                                              style: textStyle.copyWith(
                                                fontSize: 12,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Toggle buttons below the graph
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showActualTemp ? Colors.blue : Colors.grey[300],
                          ),
                          onPressed: () {
                            setState(() {
                              showActualTemp = true;
                            });
                          },
                          child: Text(
                            "Actual Temp",
                            style: textStyle.copyWith(
                              color: showActualTemp ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !showActualTemp ? Colors.red : Colors.grey[300],
                          ),
                          onPressed: () {
                            setState(() {
                              showActualTemp = false;
                            });
                          },
                          child: Text(
                            "Feels Like",
                            style: textStyle.copyWith(
                              color: !showActualTemp ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Centered compact hourly forecast table, only temperature and feels like, no gradient
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ListView.builder(
                          itemCount: hourlyForecast.length,
                          itemBuilder: (context, index) {
                            final hour = hourlyForecast[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              child: Row(
                                children: [
                                  // Left: Icon and time
                                  Row(
                                    children: [
                                      hour['iconBaseUri'] != null
                                          ? SvgPicture.network(
                                              hour['iconBaseUri'] + '.svg',
                                              width: 22,
                                              height: 22,
                                              errorBuilder: (context, error, stackTrace) => Icon(Icons.help_outline, size: 22, color: Colors.grey[700]),
                                            )
                                          : Icon(Icons.help_outline, size: 22, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      Text(hour['time'],
                                          style: textStyle.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Center: Temperatures, fixed width and centered
                                  SizedBox(
                                    width: 100,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${hour['temp'].toStringAsFixed(0)}°F",
                                          style: textStyle.copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          "Feels like: ${hour['feels'].toStringAsFixed(0)}°F",
                                          style: textStyle.copyWith(
                                              fontSize: 14,
                                              color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Update your CustomPainter to accept color:
class _CurvedLinePainter extends CustomPainter {
  final List<Offset> points;
  final bool showActualTemp;
  _CurvedLinePainter(this.points, this.showActualTemp);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = showActualTemp ? Colors.blue : Colors.red
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final control = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(control.dx, control.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
