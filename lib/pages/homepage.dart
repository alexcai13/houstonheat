import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import "dart:math";
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/chat_service.dart';

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

IconData getPrecipitationIcon(String? condition) {
  if (condition == null) return Icons.water_drop;
  final cond = condition.toLowerCase();
  if (cond.contains('snow') || cond.contains('blizzard') || cond.contains('flurr')) return Icons.ac_unit;
  if (cond.contains('sleet') || cond.contains('freezing')) return Icons.grain;
  if (cond.contains('hail')) return Icons.circle;
  if (cond.contains('thunder') || cond.contains('storm')) return Icons.flash_on;
  if (cond.contains('rain') || cond.contains('shower') || cond.contains('drizzle')) return Icons.water_drop;
  return Icons.water_drop; 
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


class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  double? currentTempF;
  double? feelsLikeF;
  String? condition;
  String? iconBaseUri;
  List<Map<String, dynamic>> hourlyForecast = [];
  List<Map<String, dynamic>> dailyForecast = [];
  bool showActualTemp = true;
  bool isLoading = true;
  String? errorMessage;
  String? weatherSummary;
  bool isLoadingSummary = false;
  DateTime? lastRefreshTime;
  late final ChatGPTService _chatService;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _chatService = ChatGPTService(dotenv.env['GROQ_API_KEY'] ?? '');
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    fetchWeatherData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    Future.delayed(Duration(hours: 3), () {
      if (mounted) {
        print('Auto-refreshing weather data...');
        fetchWeatherData();
        _startAutoRefresh();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
        lastRefreshTime = DateTime.now();
      });
      
      _fadeController.forward();
      _slideController.forward();
      
      _fetchWeatherSummary();
    } catch (e) {
      print('Error fetching weather data: $e');
      setState(() {
        errorMessage = "Error loading weather data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherSummary() async {
    if (currentTempF == null || feelsLikeF == null || condition == null) {
      print('Cannot fetch weather summary - missing weather data');
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      isLoadingSummary = true;
      weatherSummary = null;
    });

    try {
      print('Fetching weather summary...');
      print('Current temp: $currentTempF, Feels like: $feelsLikeF');
      print('Hourly forecast length: ${hourlyForecast.length}');
      print('Daily forecast length: ${dailyForecast.length}');
      
      final summary = await _chatService.getWeatherSummary(
        currentTemp: currentTempF!,
        feelsLike: feelsLikeF!,
        condition: condition!,
        cityName: widget.cityName,
        hourlyForecast: hourlyForecast,
        dailyForecast: dailyForecast,
      );
      
      print('Received summary: $summary');
      
      if (!mounted) return;
      
      setState(() {
        weatherSummary = summary;
        isLoadingSummary = false;
      });
    } catch (e) {
      print('Error fetching weather summary: $e');
      
      if (!mounted) return;
      
      setState(() {
        weatherSummary = 'Stay safe and hydrated today!';
        isLoadingSummary = false;
      });
    }
  }

  Future<void> fetchCurrentWeather() async {
    final apiKey = dotenv.env['GOOGLE_WEATHER_API_KEY'] ?? '';
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
    final apiKey = dotenv.env['GOOGLE_WEATHER_API_KEY'] ?? '';
    final hourlyUrl =
        "https://weather.googleapis.com/v1/forecast/hours:lookup?key=$apiKey&location.latitude=${widget.lat}&location.longitude=${widget.lon}&hours=12";

    final response = await http.get(Uri.parse(hourlyUrl)).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final now = DateTime.now();
      
      setState(() {
         hourlyForecast = List<Map<String, dynamic>>.from(
        (data['forecastHours'] as List)
          .map((entry) {
            final forecastDateTime = DateTime(
              entry['displayDateTime']['year'] as int,
              entry['displayDateTime']['month'] as int,
              entry['displayDateTime']['day'] as int,
              entry['displayDateTime']['hours'] as int,
            );
            
            final hours = entry['displayDateTime']['hours'] as int;
            return {
              "time": "${hours % 12 == 0 ? 12 : hours % 12}${hours >= 12 ? "PM" : "AM"}",
              "temp": _cToF((entry['temperature']['degrees'] as num).toDouble()),
              "feels": _cToF((entry['feelsLikeTemperature']['degrees'] as num).toDouble()),
              "condition": entry['weatherCondition']['description']['text'],
              "iconBaseUri": entry['weatherCondition']['iconBaseUri'],
              "dateTime": forecastDateTime,
            };
          })
          .where((forecast) {
            return (forecast['dateTime'] as DateTime).isAfter(now);
          })
          .take(12)
          .toList(),
      );
    });
    } else {
      throw Exception('Failed to load hourly forecast: ${response.statusCode}');
    }
  }

  Future<void> fetchDailyForecast() async {
    final apiKey = dotenv.env['GOOGLE_WEATHER_API_KEY'] ?? '';
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
    final textStyle = GoogleFonts.manrope(color: Colors.grey[800]);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [          SliverAppBar(
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
                  stops: [0.0, 1.0],
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
                        widget.cityName,
                        style: GoogleFonts.manrope(
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

          if (isLoading) ...[
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Loading weather data...",
                      style: textStyle.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (errorMessage != null) ...[
            SliverFillRemaining(
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.red[400]),
                      SizedBox(height: 16),
                      Text(
                        "Weather Unavailable",
                        style: textStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: textStyle.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: fetchWeatherData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[400],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text("Try Again"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (currentTempF != null) ...[
            SliverPadding(
              padding: EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: iconBaseUri != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: SvgPicture.network(
                                              iconBaseUri! + '.svg',
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  Icon(getWeatherIcon(condition), size: 40, color: Colors.blue[400]),
                                            ),
                                          )
                                        : Icon(getWeatherIcon(condition), size: 40, color: Colors.blue[400]),
                                  ),
                                ),
                                
                                SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        "${currentTempF?.toStringAsFixed(0)}°F",
                                        style: textStyle.copyWith(
                                          fontSize: 42,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(width: 16),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Feels like",
                                      style: textStyle.copyWith(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: tempToColor(feelsLikeF ?? 0).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: tempToColor(feelsLikeF ?? 0).withValues(alpha: 1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "${feelsLikeF?.toStringAsFixed(0)}°F",
                                        style: textStyle.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: isLoadingSummary
                                        ? Row(
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                'Getting weather insights...',
                                                style: textStyle.copyWith(
                                                  fontSize: 14,
                                                  color: Colors.blue[700],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            weatherSummary ?? 'Loading weather advice...',
                                            style: textStyle.copyWith(
                                              fontSize: 14,
                                              color: Colors.blue[900],
                                              height: 1.4,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  if (hourlyForecast.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.purple[400], size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Hourly Forecast',
                                style: textStyle.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => showActualTemp = true),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: showActualTemp ? Colors.blue[400] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Temperature",
                                      textAlign: TextAlign.center,
                                      style: textStyle.copyWith(
                                        color: showActualTemp ? Colors.white : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => showActualTemp = false),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !showActualTemp ? Colors.red[400] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Feels Like",
                                      textAlign: TextAlign.center,
                                      style: textStyle.copyWith(
                                        color: !showActualTemp ? Colors.white : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 20),
                          
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
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final chartHeight = constraints.maxHeight;
                                          final topPadding = 55.0;
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
                                                
                                                Positioned(
                                                  left: 60.0 * i + 30.0 - 16,
                                                  top: getY(temps[i]) - 16,
                                                  child: Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                    ),
                                                    child: hourlyForecast[i]['iconBaseUri'] != null
                                                        ? Image.network(
                                                            hourlyForecast[i]['iconBaseUri'] + '.png',
                                                            width: 28,
                                                            height: 28,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (context, error, stackTrace) => 
                                                                Icon(getWeatherIcon(hourlyForecast[i]['condition']), 
                                                                    size: 20, color: Colors.grey[600]),
                                                          )
                                                        : Icon(getWeatherIcon(hourlyForecast[i]['condition']), 
                                                              size: 20, color: Colors.grey[600]),
                                                  ),
                                                ),
                                                Positioned(
                                                left: 60.0 * i + 30.0 - 15,
                                                top: getY(temps[i]) - 50,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (showActualTemp ? Colors.blue[400] : Colors.red[400])!.withValues(alpha: 0.9),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    "${temps[i].toStringAsFixed(0)}°",
                                                    style: textStyle.copyWith(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
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
                        ],
                      ),
                    ),

                    SizedBox(height: 24),
                  ],

                  if (dailyForecast.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.purple[400], size: 24),
                              SizedBox(width: 8),
                              Text(
                                '7-Day Forecast',
                                style: textStyle.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          Column(
                            children: dailyForecast.asMap().entries.map((entry) {
                              final index = entry.key;
                              final day = entry.value;
                              final precipChance = day['precipitationChance'] as int;
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: index == dailyForecast.length - 1 ? 0 : 12),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    
                                    SizedBox(
                                      width: 80,
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
                                    
                                    SizedBox(width: 16),
                                    
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                      ),
                                      child: day['iconBaseUri'] != null
                                          ? Image.network(
                                              day['iconBaseUri'] + '.png',
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  Icon(getWeatherIcon(day['condition']), 
                                                      size: 24, color: Colors.grey[600]),
                                            )
                                          : Icon(getWeatherIcon(day['condition']), 
                                                size: 24, color: Colors.grey[600]),
                                    ),
                                    
                                    SizedBox(width: 16),
                                    
                                    SizedBox(
                                      width: 72,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: precipChance > 0 ? Colors.blue[50] : Colors.orange[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              precipChance > 0 
                                                  ? getPrecipitationIcon(day['condition'])
                                                  : Icons.wb_sunny,
                                              size: 14, 
                                              color: precipChance > 0 ? Colors.blue[600] : Colors.orange[600],
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              "$precipChance%",
                                              style: textStyle.copyWith(
                                                fontSize: 12,
                                                color: precipChance > 0 ? Colors.blue[600] : Colors.orange[600],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    Spacer(),
                                    
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${day['high'].toStringAsFixed(0)}°",
                                          style: textStyle.copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[600],
                                          ),
                                        ),
                                        Text(
                                          "${day['low'].toStringAsFixed(0)}°",
                                          style: textStyle.copyWith(
                                            fontSize: 16,
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
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
