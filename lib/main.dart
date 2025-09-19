import 'package:flutter/material.dart';
import 'pages/cooling_centers.dart';
import 'pages/homepage.dart';
import 'pages/map.dart';
import 'pages/chat.dart';
import 'pages/chat_selector.dart'; 
import 'dart:math' as Math;

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
  bool _showChatSelector = false; // <-- Add this
  List<Map<String, dynamic>> _chatHistories = [
    {
      'title': 'New Chat',
      'messages': <Map<String, String>>[],
    }
  ];
  int _currentChatIndex = 0;
  Map<String, dynamic>? _currentWeatherData;

  void _updateChats(List<Map<String, dynamic>> chats) {
    setState(() {
      _chatHistories = chats;
    });
  }

  void _onSelectChat(List<Map<String, dynamic>> chats, int chatIndex) {
    print('Selecting chat $chatIndex (total chats: ${chats.length})');
    if (chatIndex >= chats.length) {
      print('Warning: Invalid chat index, resetting to last chat');
      chatIndex = Math.max(0, chats.length - 1);
    }
    setState(() {
      _chatHistories = chats;
      _currentChatIndex = chatIndex;
      _selectedIndex = 3;
      _showChatSelector = false;  // Add this line to hide the selector
    });
  }

  void _onSwitchChat(int newIndex) {
    print('Switching to chat $newIndex of ${_chatHistories.length} chats'); // Debug print

    // Ensure index is valid
    if (newIndex >= _chatHistories.length) {
      newIndex = _chatHistories.length - 1;
    }

    setState(() {
      _currentChatIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      CoolingCentersPage(),
      WeatherScreen(
        lat: 29.7604,
        lon: -95.3698,
        cityName: "Houston",
        onWeatherData: (data) {
          setState(() {
            _currentWeatherData = data;
          });
        },
      ),
      MapPage(),
      ChatPage(
        weatherData: _currentWeatherData,
        chatHistories: _chatHistories,
        chatIndex: _currentChatIndex,
        onUpdateChats: _updateChats,
        onSwitchChat: (int newIndex) {
          setState(() {
            _currentChatIndex = newIndex;
          });
        },
      ),
    ];

    return Scaffold(
      body: (_selectedIndex == 3 && _showChatSelector)
          ? ChatSelectorPage(
              chatHistories: _chatHistories,
              weatherData: _currentWeatherData,
              onSelectChat: _onSelectChat,
            )
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            if (index == 3) {
              if (_selectedIndex != 3) {
                // First time tapping chat or coming from another tab
                _showChatSelector = true;
              } else {
                // Already in chat, toggle between selector and current chat
                _showChatSelector = !_showChatSelector;
              }
            }
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: "Centers",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: "Weather",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
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
