import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic>? weatherData;
  final List<Map<String, dynamic>> chatHistories;
  final int chatIndex;
  final Function(List<Map<String, dynamic>>) onUpdateChats;
  final Function(int)? onSwitchChat; // <-- Add this callback

  const ChatPage({
    Key? key,
    required this.weatherData,
    required this.chatHistories,
    required this.chatIndex,
    required this.onUpdateChats,
    this.onSwitchChat, // <-- Add this
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _titleRequested = false;
  final ChatGPTService _chatService = ChatGPTService('***REMOVED***'); // Replace with your key

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final updatedChats = List<Map<String, dynamic>>.from(widget.chatHistories);
    final isNewChat = updatedChats[widget.chatIndex]['title'] == 'New Chat' &&
                      updatedChats[widget.chatIndex]['messages'].isEmpty;
    
    setState(() {
      updatedChats[widget.chatIndex]['messages'].add({
        'role': 'user',
        'content': text
      });
      _isLoading = true;
      _controller.clear();
    });

    try {
      final weatherContext = buildWeatherContext(widget.weatherData);
      final response = await _chatService.getChatResponse(
        text,
        weatherContext: weatherContext,
      );

      setState(() {
        updatedChats[widget.chatIndex]['messages'].add({
          'role': 'assistant',
          'content': response
        });
        _isLoading = false;
      });
      
      widget.onUpdateChats(updatedChats);

      // Generate title for new chats after first message exchange
      if (isNewChat) {
        try {
          final title = await _chatService.getChatTitle(
            List<Map<String, String>>.from(updatedChats[widget.chatIndex]['messages'])
          );
          
          final chatsWithTitle = List<Map<String, dynamic>>.from(updatedChats);
          chatsWithTitle[widget.chatIndex]['title'] = title.trim();
          
          setState(() {});
          widget.onUpdateChats(chatsWithTitle);
        } catch (e) {
          print('Error generating title: $e');
        }
      }
    } catch (e) {
      final chatsWithError = List<Map<String, dynamic>>.from(updatedChats);
      setState(() {
        chatsWithError[widget.chatIndex]['messages'].add({
          'role': 'assistant',
          'content': 'Sorry, something went wrong.'
        });
        _isLoading = false;
      });
      widget.onUpdateChats(chatsWithError);
    }
  }

  String buildWeatherContext(Map<String, dynamic>? weatherData) {
    if (weatherData == null) return "";
    final temp = weatherData['currentTempF'] ?? '';
    final feelsLike = weatherData['feelsLikeF'] ?? '';
    final cond = weatherData['condition'] ?? '';
    final city = weatherData['city'] ?? '';
    return "It is currently $temp°F and $cond in $city. It feels like $feelsLike°F.";
  }

  @override
  Widget build(BuildContext context) {
    // Add guard to prevent index out of range
    if (widget.chatIndex >= widget.chatHistories.length) {
    print('Invalid chat index: ${widget.chatIndex} (total: ${widget.chatHistories.length})');
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Center(child: Text('Loading chat...')),
    );
  }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.chatHistories[widget.chatIndex]['title'] ?? 'Chat',
          style: TextStyle(color: Colors.black),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,  // Add this
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.add, color: Colors.blue),
                title: Text('Start New Chat'),
                onTap: () {
                  final newChat = {
                    'title': 'New Chat',
                    'messages': <Map<String, String>>[],
                  };
                  
                  // Create new list and add chat
                  final updatedChats = List<Map<String, dynamic>>.from(widget.chatHistories)
                    ..add(newChat);
                  
                  // Update parent first
                  widget.onUpdateChats(updatedChats);
                  
                  // Switch to new chat index
                  widget.onSwitchChat?.call(updatedChats.length - 1);
                  
                  // Close drawer after state updates
                  Navigator.of(context).pop();
                },
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chatHistories.length,
                  itemBuilder: (context, i) {
                    return ListTile(
                      leading: Icon(Icons.chat),
                      title: Text(widget.chatHistories[i]['title'] ?? 'Chat ${i + 1}'),
                      selected: i == widget.chatIndex,
                      onTap: () {
                        widget.onSwitchChat?.call(i);
                        Navigator.pop(context); // Close drawer
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.chatHistories[widget.chatIndex]['messages'].length,
              itemBuilder: (context, index) {
                final msg = widget.chatHistories[widget.chatIndex]['messages'][index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isUser
                        ? Text(msg['content'] ?? '')
                        : MarkdownBody(
                            data: msg['content'] ?? '',
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about heat safety...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
