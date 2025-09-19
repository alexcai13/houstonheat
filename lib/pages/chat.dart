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
  late List<Map<String, dynamic>> _chatHistories;
  late int _chatIndex;
  bool _isLoading = false;
  bool _titleRequested = false;
  final ChatGPTService _chatService = ChatGPTService('***REMOVED***'); // Replace with your key

  @override
  void initState() {
    super.initState();
    _chatHistories = widget.chatHistories;
    _chatIndex = widget.chatIndex;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatHistories[_chatIndex]['messages'].add({'role': 'user', 'content': text});
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
        _chatHistories[_chatIndex]['messages'].add({'role': 'assistant', 'content': response});
        _isLoading = false;
      });
      widget.onUpdateChats(_chatHistories);

      // If this is the first assistant response, get a title
      if (!_titleRequested &&
          (_chatHistories[_chatIndex]['title'] == null ||
           _chatHistories[_chatIndex]['title'] == 'New Chat' ||
           (_chatHistories[_chatIndex]['title'] as String).trim().isEmpty)) {
        _titleRequested = true;
        final title = await _chatService.getChatTitle(_chatHistories[_chatIndex]['messages']);
        setState(() {
          _chatHistories[_chatIndex]['title'] = title.trim();
        });
        widget.onUpdateChats(_chatHistories);
      }
    } catch (e) {
      setState(() {
        _chatHistories[_chatIndex]['messages'].add({'role': 'assistant', 'content': 'Sorry, something went wrong.'});
        _isLoading = false;
      });
      widget.onUpdateChats(_chatHistories);
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
        title: Text(widget.chatHistories[widget.chatIndex]['title'] ?? 'Chat'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.add),
                title: Text('Start New Chat'),
                onTap: () {
                  final newChat = {
                    'title': 'New Chat',
                    'messages': <Map<String, String>>[],
                  };
                  final updatedChats = [...widget.chatHistories, newChat];
                  widget.onUpdateChats(updatedChats);
                  widget.onSwitchChat?.call(updatedChats.length - 1); // <-- always valid index
                  Navigator.pop(context); // Close drawer
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
              itemCount: _chatHistories[_chatIndex]['messages'].length,
              itemBuilder: (context, index) {
                final msg = _chatHistories[_chatIndex]['messages'][index];
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
