import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  final LatLng _houston = const LatLng(29.7604, -95.3698);
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final String csvData = await rootBundle.loadString('assets/Houston_Cooling_Centers.csv');
    final List<String> lines = csvData.split('\n');
    final headers = lines.first.split(',');
    final nameIdx = headers.indexOf('Name');
    final addressIdx = headers.indexOf('Address');
    final latIdx = headers.indexOf('Lat');
    final lonIdx = headers.indexOf('Lon');

    setState(() {
      for (var i = 1; i < lines.length; i++) {
        final row = lines[i];
        if (row.trim().isEmpty) continue;
        final fields = _parseCsvRow(row);
        double? lat = double.tryParse(fields[latIdx]);
        double? lon = double.tryParse(fields[lonIdx]);
        if (lat == null || lon == null) continue;
        _markers.add(
          Marker(
            markerId: MarkerId('${fields[nameIdx]}_${lat}_${lon}'),
            position: LatLng(lat, lon),
            infoWindow: InfoWindow(
              title: fields[nameIdx],
              snippet: fields[addressIdx],
            ),
            icon: BitmapDescriptor.defaultMarker,
          ),
        );
      }
    });
  }

  // Simple CSV parser for quoted fields
  List<String> _parseCsvRow(String row) {
    final List<String> result = [];
    bool inQuotes = false;
    String field = '';
    for (int i = 0; i < row.length; i++) {
      final char = row[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(field);
        field = '';
      } else {
        field += char;
      }
    }
    result.add(field);
    return result;
  }

  Future<void> goToCurrentLocation(GoogleMapController controller) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    Position pos = await Geolocator.getCurrentPosition();
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(pos.latitude, pos.longitude),
        zoom: 15,
      ),
    ));
  }

  bool isCurrentlyOpen(String schedule) {
    final now = DateTime.now();
    final weekday = DateFormat('EEEE').format(now);

    final lines = schedule.split('\n');
    final todayLine = lines.firstWhere(
      (line) => line.startsWith(weekday),
      orElse: () => '',
    );
    if (todayLine.isEmpty) return false;

    final parts = todayLine.split(': ');
    if (parts.length < 2) return false;
    final hours = parts[1];

    if (hours.toLowerCase().contains("closed")) return false;

    final range = hours.split('-');
    if (range.length != 2) return false;

    final openTime = DateFormat("h:mma").parse(range[0]);
    final closeTime = DateFormat("h:mma").parse(range[1]);

    final openToday = DateTime(now.year, now.month, now.day, openTime.hour, openTime.minute);
    DateTime closeToday = DateTime(now.year, now.month, now.day, closeTime.hour, closeTime.minute);

    if (closeToday.isBefore(openToday)) {
      closeToday = closeToday.add(Duration(days: 1));
    }

    return now.isAfter(openToday) && now.isBefore(closeToday);
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      initialCameraPosition: CameraPosition(
        target: _houston,
        zoom: 12.0,
      ),
      markers: _markers,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      },
      onMapCreated: (controller) {
        _mapController = controller;
        goToCurrentLocation(controller);
      },
    );
  }
}