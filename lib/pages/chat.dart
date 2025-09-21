import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic>? weatherData;
  final List<Map<String, dynamic>> chatHistories;
  final int chatIndex;
  final Function(List<Map<String, dynamic>>) onUpdateChats;
  final Function(int)? onSwitchChat;

  const ChatPage({
    Key? key,
    required this.weatherData,
    required this.chatHistories,
    required this.chatIndex,
    required this.onUpdateChats,
    this.onSwitchChat,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _titleRequested = false;
  final ChatGPTService _chatService = ChatGPTService('***REMOVED***');

  late AnimationController _messageAnimationController;
  late AnimationController _inputAnimationController;
  late Animation<double> _inputScaleAnimation;

  @override
  void initState() {
    super.initState();
    _messageAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _inputAnimationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _inputScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_inputAnimationController);
  }

  @override
  void dispose() {
    _messageAnimationController.dispose();
    _inputAnimationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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

    _scrollToBottom();

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
      _scrollToBottom();

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
      _scrollToBottom();
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
    if (widget.chatIndex >= widget.chatHistories.length) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
              SizedBox(height: 16),
              Text(
                'Loading chat...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final messages = widget.chatHistories[widget.chatIndex]['messages'] as List;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent, // Change from Colors.white to transparent
            centerTitle: true,
            flexibleSpace: Container( // Wrap FlexibleSpaceBar in Container with gradient
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.chatHistories[widget.chatIndex]['title'] ?? 'Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${messages.length} messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.menu, color: Colors.black, size: 20),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: messages.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.blue[400],
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ask me about heat safety, weather, or cooling centers',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AnimatedMessageBubble(
                        message: messages[index],
                        index: index,
                      ),
                      childCount: messages.length,
                    ),
                  ),
          ),
          if (_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            'Thinking...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      drawer: ModernDrawer(
        chatHistories: widget.chatHistories,
        currentChatIndex: widget.chatIndex,
        onUpdateChats: widget.onUpdateChats,
        onSwitchChat: widget.onSwitchChat,
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        child: ScaleTransition(
          scale: _inputScaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about heat safety...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    style: TextStyle(fontSize: 16),
                    onSubmitted: (_) => _sendMessage(), // This handles Enter key
                    textInputAction: TextInputAction.send, // Add this line
                    keyboardType: TextInputType.text, // Add this line  
                    maxLines: 1, 
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => _inputAnimationController.forward(),
                  onTapUp: (_) => _inputAnimationController.reverse(),
                  onTapCancel: () => _inputAnimationController.reverse(),
                  child: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onTap: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Message Bubble Component
class AnimatedMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final int index;

  const AnimatedMessageBubble({
    Key? key,
    required this.message,
    required this.index,
  }) : super(key: key);

  @override
  _AnimatedMessageBubbleState createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message['role'] == 'user';

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.cyan[300]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 12),
                ],
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[500] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isUser
                        ? Text(
                            widget.message['content'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          )
                        : MarkdownBody(
                            data: widget.message['content'] ?? '',
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),
                ),
                if (isUser) ...[
                  SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.person, color: Colors.grey[600], size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Modern Drawer Component
class ModernDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> chatHistories;
  final int currentChatIndex;
  final Function(List<Map<String, dynamic>>) onUpdateChats;
  final Function(int)? onSwitchChat;

  const ModernDrawer({
    Key? key,
    required this.chatHistories,
    required this.currentChatIndex,
    required this.onUpdateChats,
    this.onSwitchChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.cyan[300]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chat, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Chat History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final newChat = {
                      'title': 'New Chat',
                      'messages': <Map<String, String>>[],
                    };
                    
                    final updatedChats = List<Map<String, dynamic>>.from(chatHistories)
                      ..add(newChat);
                    
                    onUpdateChats(updatedChats);
                    onSwitchChat?.call(updatedChats.length - 1);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add, color: Colors.blue[600], size: 20),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Start New Chat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: chatHistories.length,
                itemBuilder: (context, i) {
                  final isSelected = i == currentChatIndex;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected ? Colors.blue[50] : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          onSwitchChat?.call(i);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue[400] : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chatHistories[i]['title'] ?? 'Chat ${i + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? Colors.blue[700] : Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
