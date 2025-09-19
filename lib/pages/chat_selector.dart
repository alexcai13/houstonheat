import 'package:flutter/material.dart';
import 'chat.dart';

class ChatSelectorPage extends StatelessWidget {
  final List<Map<String, dynamic>> chatHistories;
  final Map<String, dynamic>? weatherData;
  final Function(List<Map<String, dynamic>>, int) onSelectChat;

  const ChatSelectorPage({
    required this.chatHistories,
    required this.weatherData,
    required this.onSelectChat,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Chats', style: TextStyle(color: Colors.black)),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.add, color: Colors.blue),
            title: Text('Start New Chat'),
            onTap: () {
              // Create a completely new chat with empty messages
              final newChat = {
                'title': 'New Chat',
                'messages': <Map<String, String>>[], // Empty messages array
              };
              
              // Create new list and add chat
              final updatedChats = List<Map<String, dynamic>>.from(chatHistories)
                ..add(newChat);
              
              // Update parent first, then switch to new chat
              onSelectChat(updatedChats, updatedChats.length - 1);
            },
          ),
          ...List.generate(chatHistories.length, (i) {
            return ListTile(
              leading: Icon(Icons.chat_bubble_outline),
              title: Text(chatHistories[i]['title'] ?? 'Chat ${i + 1}'),
              onTap: () => onSelectChat(chatHistories, i),
            );
          }),
        ],
      ),
    );
  }
}