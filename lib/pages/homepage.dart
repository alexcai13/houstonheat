import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import "dart:math";

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
  if (tempF < 60) return Colors.blue[300]!;
  if (tempF < 70) return Colors.cyan[300]!;
  if (tempF < 80) return Colors.green[300]!;
  if (tempF < 90) return Colors.yellow[300]!;
  if (tempF < 100) return Colors.orange[300]!;
  return Colors.red[300]!;
}

class WeatherScreen extends StatefulWidget {
  final double lat;
  final double lon;
  final String cityName;
  final void Function(Map<String, dynamic>)? onWeatherData; 

  const WeatherScreen({
    Key? key,
    this.lat = 29.7604,
    this.lon = -95.3698,
    this.cityName = "Houston",
    this.onWeatherData,
  }) : super(key: key);

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  double? currentTempF;
  double? feelsLikeF;
  String? condition;
  String? iconBaseUri;
  List<Map<String, dynamic>> hourlyForecast = [];
  List<Map<String, dynamic>> dailyForecast = [];
  bool showActualTemp = true; // For hourly graph: true = temperature, false = feels like
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchWeatherData();
  }

  double _cToF(double c) => (c * 9 / 5) + 32;

  Future<void> fetchWeatherData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await Future.wait([
        fetchCurrentWeather(),
        fetchHourlyForecast(),
        fetchDailyForecast(),
      ]);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching weather data: $e');
      setState(() {
        errorMessage = "Error loading weather data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> fetchCurrentWeather() async {
    final apiKey = "***REMOVED***";
    final currentUrl =
        "https://weather.googleapis.com/v1/currentConditions:lookup"
        "?location.latitude=${widget.lat}&location.longitude=${widget.lon}&key=$apiKey";

    final response = await http.get(Uri.parse(currentUrl)).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      setState(() {
        currentTempF = _cToF((data['temperature']['degrees'] as num).toDouble());
        feelsLikeF = _cToF((data['feelsLikeTemperature']['degrees'] as num).toDouble());
        condition = data['weatherCondition']['description']['text'];
        iconBaseUri = data['weatherCondition']['iconBaseUri'];

        // Call the callback with the weather data
        if (widget.onWeatherData != null) {
          widget.onWeatherData!({
            "currentTempF": currentTempF,
            "feelsLikeF": feelsLikeF,
            "condition": condition,
            "city": widget.cityName, 
          });
        }
      });
    } else {
      throw Exception('Failed to load current weather: ${response.statusCode}');
    }
  }

  Future<void> fetchHourlyForecast() async {
    final apiKey = "***REMOVED***";
    final hourlyUrl =
        "https://weather.googleapis.com/v1/forecast/hours:lookup?key=$apiKey&location.latitude=${widget.lat}&location.longitude=${widget.lon}&hours=12";

    final response = await http.get(Uri.parse(hourlyUrl)).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      setState(() {
        hourlyForecast = List<Map<String, dynamic>>.from(
          (data['forecastHours'] as List).map((entry) {
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
    } else {
      throw Exception('Failed to load hourly forecast: ${response.statusCode}');
    }
  }

  Future<void> fetchDailyForecast() async {
    final apiKey = "***REMOVED***";
    final dailyUrl =
        "https://weather.googleapis.com/v1/forecast/days:lookup?key=$apiKey&location.latitude=${widget.lat}&location.longitude=${widget.lon}&days=7&pageSize=7";

    final response = await http.get(Uri.parse(dailyUrl)).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['forecastDays'] != null) {
        setState(() {
          dailyForecast = List<Map<String, dynamic>>.from(
            (data['forecastDays'] as List).take(7).map((entry) {
              final displayDate = entry['displayDate'];
              final date = DateTime(displayDate['year'], displayDate['month'], displayDate['day']);
              final dayName = DateFormat('EEE').format(date);
              
              // Use daytimeForecast for main weather condition and precipitation
              final daytimeForecast = entry['daytimeForecast'];
              final precipChance = daytimeForecast['precipitation']['probability']['percent'] ?? 0;
              
              return {
                "day": dayName,
                "date": DateFormat('M/d').format(date),
                "high": _cToF((entry['maxTemperature']['degrees'] as num).toDouble()),
                "low": _cToF((entry['minTemperature']['degrees'] as num).toDouble()),
                "condition": daytimeForecast['weatherCondition']['description']['text'],
                "iconBaseUri": daytimeForecast['weatherCondition']['iconBaseUri'],
                "precipitationChance": precipChance,
              };
            }),
          );
        });
      }
    } else {
      throw Exception('Failed to load daily forecast: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.manrope(color: Colors.black);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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

                if (isLoading) ...[
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Loading weather data...", style: textStyle),
                        ],
                      ),
                    ),
                  ),
                ] else if (errorMessage != null) ...[
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: textStyle.copyWith(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: fetchWeatherData,
                            child: Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (currentTempF != null) ...[
                  // Current weather display
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
                      Expanded(
                        child: Text(condition ?? "",
                            style: textStyle.copyWith(
                                fontSize: 18, fontWeight: FontWeight.w500)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${currentTempF?.toStringAsFixed(0)}°F",
                              style: textStyle.copyWith(
                                  fontSize: 54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Feels like: ${feelsLikeF?.toStringAsFixed(0)}°F",
                              style: textStyle.copyWith(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Temperature vs Feels Like toggle for hourly graph
                  if (hourlyForecast.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showActualTemp ? Colors.blue[400] : Colors.grey[300],
                            elevation: showActualTemp ? 2 : 0,
                          ),
                          onPressed: () {
                            setState(() {
                              showActualTemp = true;
                            });
                          },
                          child: Text(
                            "Temperature",
                            style: textStyle.copyWith(
                              color: showActualTemp ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !showActualTemp ? Colors.red[400] : Colors.grey[300],
                            elevation: !showActualTemp ? 2 : 0,
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

                    // Hourly chart
                    SizedBox(
                      height: 180,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: hourlyForecast.length * 60.0,
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
                              // Chart area
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final chartHeight = constraints.maxHeight;
                                    final topPadding = 40.0; // Increased from 20.0 to give more space for labels
                                    final bottomPadding = 20.0;

                                    final allTemps = [
                                      ...hourlyForecast.map((e) => e['temp'] as double),
                                      ...hourlyForecast.map((e) => e['feels'] as double),
                                    ];
                                    final minY = allTemps.reduce((a, b) => a < b ? a : b);
                                    final maxY = allTemps.reduce((a, b) => a > b ? a : b);
                                    final tempRange = (maxY - minY) == 0 ? 1 : (maxY - minY);

                                    final temps = hourlyForecast
                                        .map((e) => showActualTemp ? e['temp'] as double : e['feels'] as double)
                                        .toList();

                                    double getY(double temp) {
                                      final availableHeight = chartHeight - topPadding - bottomPadding;
                                      return ((maxY - temp) / tempRange) * availableHeight + topPadding;
                                    }

                                    return Stack(
                                      children: [
                                        // Draw connecting line
                                        CustomPaint(
                                          size: Size(hourlyForecast.length * 60.0, chartHeight),
                                          painter: _CurvedLinePainter(
                                            hourlyForecast.asMap().entries.map((entry) {
                                              final index = entry.key;
                                              final temp = temps[index];
                                              return Offset(60.0 * index + 30.0, getY(temp));
                                            }).toList(),
                                            showActualTemp,
                                          ),
                                        ),
                                        for (int i = 0; i < hourlyForecast.length; i++) ...[
                                          // Weather icon
                                          Positioned(
                                            left: 60.0 * i + 30.0 - 9,
                                            top: getY(temps[i]) - 9,
                                            child: hourlyForecast[i]['iconBaseUri'] != null
                                                ? Image.network(
                                                    hourlyForecast[i]['iconBaseUri'] + '.png',
                                                    width: 18,
                                                    height: 18,
                                                    errorBuilder: (context, error, stackTrace) => 
                                                        Icon(Icons.help_outline, size: 18, color: Colors.grey[700]),
                                                  )
                                                : Icon(Icons.help_outline, size: 18, color: Colors.grey[700]),
                                          ),
                                          // Temperature label
                                          Positioned(
                                            left: 60.0 * i + 30.0 - 15,
                                            top: getY(temps[i]) - 35, // Increased from -30 to -35 for more space
                                            child: Text(
                                              "${temps[i].toStringAsFixed(0)}°",
                                              style: textStyle.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: showActualTemp ? Colors.blue[600] : Colors.red[600],
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
                    
                    const SizedBox(height: 20),
                  ],

                  // 7-Day forecast list
                  if (dailyForecast.isNotEmpty) ...[
                    Text(
                      '7-Day Forecast',
                      style: textStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Column(
                      children: dailyForecast.map((day) {
                        final precipChance = day['precipitationChance'] as int;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Day and date
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day['day'],
                                      style: textStyle.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      day['date'],
                                      style: textStyle.copyWith(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Weather icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: day['iconBaseUri'] != null
                                    ? Image.network(
                                        day['iconBaseUri'] + '.png',
                                        width: 30,
                                        height: 30,
                                        errorBuilder: (context, error, stackTrace) => 
                                            Icon(Icons.help_outline, size: 24, color: Colors.grey[700]),
                                      )
                                    : Icon(Icons.help_outline, size: 24, color: Colors.grey[700]),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Precipitation
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.water_drop, size: 16, color: Colors.blue[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$precipChance%",
                                        style: textStyle.copyWith(
                                          fontSize: 14,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Rain",
                                    style: textStyle.copyWith(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(width: 20),
                              
                              // High/Low temps with same size
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${day['high'].toStringAsFixed(0)}°",
                                    style: textStyle.copyWith(
                                      fontSize: 16,  // Changed from 18 to 16
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[600],
                                    ),
                                  ),
                                  Text(
                                    "${day['low'].toStringAsFixed(0)}°",
                                    style: textStyle.copyWith(
                                      fontSize: 16,  // Keep at 16
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// Replace the _CurvedLinePainter class with this version:
class _CurvedLinePainter extends CustomPainter {
  final List<Offset> points;
  final bool showActualTemp;
  _CurvedLinePainter(this.points, this.showActualTemp);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = showActualTemp 
          ? (Colors.blue[400] ?? Colors.blue)
          : (Colors.red[400] ?? Colors.red)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      
      if (i == points.length - 1) {
        // Last point - just draw straight line
        path.lineTo(curr.dx, curr.dy);
      } else {
        final next = points[i + 1];
        
        // Calculate the curve radius (smaller = tighter curve)
        final curveRadius = 15.0;
        
        // Direction vectors
        final dx1 = curr.dx - prev.dx;
        final dy1 = curr.dy - prev.dy;
        final dx2 = next.dx - curr.dx;
        final dy2 = next.dy - curr.dy;
        
        // Normalize the distances
        final dist1 = (dx1 * dx1 + dy1 * dy1).abs();
        final dist2 = (dx2 * dx2 + dy2 * dy2).abs();
        
        if (dist1 > 0 && dist2 > 0) {
          final len1 = sqrt(dist1);
          final len2 = sqrt(dist2);
          
          // Calculate points before and after the current point for smooth curve
          final t1 = (curveRadius / len1).clamp(0.0, 0.5);
          final t2 = (curveRadius / len2).clamp(0.0, 0.5);
          
          final beforePoint = Offset(
            curr.dx - dx1 * t1,
            curr.dy - dy1 * t1,
          );
          
          final afterPoint = Offset(
            curr.dx + dx2 * t2,
            curr.dy + dy2 * t2,
          );
          
          // Draw straight line to the point before the curve
          path.lineTo(beforePoint.dx, beforePoint.dy);
          
          // Draw smooth curve around the point
          path.quadraticBezierTo(
            curr.dx, curr.dy,  // Control point is the actual data point
            afterPoint.dx, afterPoint.dy,
          );
        } else {
          // Fallback to straight line if calculations fail
          path.lineTo(curr.dx, curr.dy);
        }
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}