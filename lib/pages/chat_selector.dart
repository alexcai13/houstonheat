import 'package:flutter/material.dart';

class ChatSelectorPage extends StatefulWidget {
  final List<Map<String, dynamic>> chatHistories;
  final Function(List<Map<String, dynamic>>, int) onSelectChat;
  final Map<String, dynamic>? weatherData;

  const ChatSelectorPage({
    Key? key,
    required this.chatHistories,
    required this.onSelectChat,
    this.weatherData,
  }) : super(key: key);

  @override
  _ChatSelectorPageState createState() => _ChatSelectorPageState();
}

class _ChatSelectorPageState extends State<ChatSelectorPage>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _fabController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeInOut),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_fabController);

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black),
            automaticallyImplyLeading: false,
            title: null,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final double appBarHeight = constraints.biggest.height;
                final double collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                final double expandedHeight = 200 + MediaQuery.of(context).padding.top;
                
                final double collapseProgress = ((expandedHeight - appBarHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
                
                final double titleFontSize = 32 - (collapseProgress * 14);
                final double subtitleFontSize = 16 - (collapseProgress * 4);
                
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: SlideTransition(
                      position: _headerSlideAnimation,
                      child: FadeTransition(
                        opacity: _headerFadeAnimation,
                          child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: collapseProgress > 0.5 ? 8 : 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: collapseProgress > 0.5 ? MainAxisAlignment.center : MainAxisAlignment.end,
                            children: [
                              Hero(
                                tag: 'chat_selector_title',
                                child: Material(
                                  color: Colors.transparent,
                                  child: Text(
                                    'Your Chats',
                                    style: TextStyle(
                                      fontSize: titleFontSize.clamp(18.0, 32.0),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              if (collapseProgress < 0.8) ...[
                                SizedBox(height: 8 * (1 - collapseProgress)),
                                Opacity(
                                  opacity: (1 - collapseProgress).clamp(0.0, 1.0),
                                  child: Text(
                                    widget.chatHistories.isEmpty
                                        ? 'No conversations yet'
                                        : '${widget.chatHistories.length} conversation${widget.chatHistories.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: subtitleFontSize.clamp(14.0, 16.0),
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: widget.chatHistories.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.blue[400],
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'No chats yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Start your first conversation about\nheat safety and weather',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AnimatedChatCard(
                        chat: widget.chatHistories[index],
                        index: index,
                        onTap: () => widget.onSelectChat(widget.chatHistories, index),
                      ),
                      childCount: widget.chatHistories.length,
                    ),
                  ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: GestureDetector(
          onTapDown: (_) => _fabController.forward(),
          onTapUp: (_) => _fabController.reverse(),
          onTapCancel: () => _fabController.reverse(),
          onTap: () {
            final newChat = {
              'title': 'New Chat',
              'messages': <Map<String, String>>[],
            };
            
            final updatedChats = List<Map<String, dynamic>>.from(widget.chatHistories)
              ..add(newChat);
            
            widget.onSelectChat(updatedChats, updatedChats.length - 1);
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      drawer: ModernDrawer(
        chatHistories: widget.chatHistories,
        currentChatIndex: widget.chatHistories.isEmpty ? -1 : widget.chatHistories.indexOf(widget.chatHistories.last),
        onUpdateChats: (updatedChats) {
          setState(() {
            widget.chatHistories.clear();
            widget.chatHistories.addAll(updatedChats);
          });
        },
        onSwitchChat: (index) {
          widget.onSelectChat(widget.chatHistories, index);
        },
      ),
    );
  }
}

class AnimatedChatCard extends StatefulWidget {
  final Map<String, dynamic> chat;
  final int index;
  final VoidCallback onTap;

  const AnimatedChatCard({
    Key? key,
    required this.chat,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  _AnimatedChatCardState createState() => _AnimatedChatCardState();
}

class _AnimatedChatCardState extends State<AnimatedChatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
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
    final messageCount = (widget.chat['messages'] as List).length;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Material(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onTap,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'chat_icon_${widget.index}',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[300]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.chat['title'] ?? 'Untitled Chat',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.message_rounded,
                                  size: 16,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '$messageCount message${messageCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
  }
}

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
                    child: Icon(Icons.menu, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Navigation',
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
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.home, color: Colors.blue[600]),
                  ),
                  title: Text(
                    'Chat Homepage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.blue[600]),
                  ),
                  title: Text(
                    'Start New Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
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
                ),
              ),
            ),

            Divider(indent: 16, endIndent: 16),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    'Previous Chats',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: chatHistories.length,
                itemBuilder: (context, i) {
                  final isSelected = i == currentChatIndex;
                  final messageCount = (chatHistories[i]['messages'] as List).length;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected ? Colors.blue[50] : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (!isSelected) {
                            onSwitchChat?.call(i);
                          }
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chatHistories[i]['title'] ?? 'Chat ${i + 1}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.blue[700] : Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (messageCount > 0)
                                      Text(
                                        '$messageCount message${messageCount == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.blue[400],
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
            
            Divider(indent: 16, endIndent: 16),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.ac_unit, color: Colors.green[600]),
              ),
              title: Text('Cooling Centers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/cooling-centers');
              },
            ),
            
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cloud, color: Colors.orange[600]),
              ),
              title: Text('Weather'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/weather');
              },
            ),
          ],
        ),
      ),
    );
  }
}