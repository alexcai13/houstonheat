import 'package:flutter/material.dart';
import 'pages/cooling_centers.dart';     // your Cooling Centers page
import 'pages/homepage.dart';  // your Weather page
import 'pages/map.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather & Cooling Centers',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

// -------------------- NAVIGATION --------------------
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // pages to switch between
  final List<Widget> _pages = [
    CoolingCentersPage(),
    WeatherScreen(
      lat: 29.7604,   // Houston latitude
      lon: -95.3698,  // Houston longitude
      cityName: "Houston",
    ),
    MapPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue, // <-- Color for selected icon/text
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: "Cooling Centers",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: "Weather",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map), // <-- Add this line
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chat",
          ),
        ],
      ),
    );
  }
}
