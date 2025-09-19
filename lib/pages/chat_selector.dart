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
      appBar: AppBar(title: Text('Chats')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.add),
            title: Text('Start New Chat'),
            onTap: () {
              final newChat = {
                'title': 'New Chat',
                'messages': <Map<String, String>>[],
              };
              onSelectChat([...chatHistories, newChat], chatHistories.length);
            },
          ),
          ...List.generate(chatHistories.length, (i) {
            return ListTile(
              leading: Icon(Icons.chat),
              title: Text(chatHistories[i]['title'] ?? 'Chat ${i + 1}'),
              onTap: () {
                onSelectChat(chatHistories, i);
              },
            );
          }),
        ],
      ),
    );
  }
}