import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;

  const ChatPage({
    Key? key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Stream<List<Map<String, dynamic>>> _chatStream() {
    final supabase = Supabase.instance.client;
    final userA = widget.currentUserId;
    final userB = widget.otherUserId;

    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          final list = List<Map<String, dynamic>>.from(data);
          return list.where((msg) {
            final from = msg['from_user_id'];
            final to = msg['to_user_id'];
            return (from == userA && to == userB) ||
                (from == userB && to == userA);
          }).toList();
        });
  }

  Future<void> _sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;

    try {
      final response = await Supabase.instance.client.from('messages').insert({
        'from_user_id': widget.currentUserId,
        'to_user_id': widget.otherUserId,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (response == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
        return;
      }
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 70,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null ||
          result.files.isEmpty ||
          result.files.single.bytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
        return;
      }
      final bytes = result.files.single.bytes!;
      final name = result.files.single.name;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp\_$name';

      final storage = Supabase.instance.client.storage;
      final uploadedPath = await storage
          .from('chat-images')
          .uploadBinary(fileName, bytes);

      if (uploadedPath == null) {
        throw Exception('Upload failed');
      }

      final publicUrl = storage.from('chat-images').getPublicUrl(fileName);
      debugPrint('Uploaded image public URL: $publicUrl');

      await Supabase.instance.client.from('messages').insert({
        'from_user_id': widget.currentUserId,
        'to_user_id': widget.otherUserId,
        'message': '[image]$publicUrl',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 250,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
    }
  }

  Future<void> _deleteChat() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('messages')
          .delete()
          .or(
            'and(from_user_id.eq.${widget.currentUserId},to_user_id.eq.${widget.otherUserId}),and(from_user_id.eq.${widget.otherUserId},to_user_id.eq.${widget.currentUserId})',
          );
      if (response == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete chat')));
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete chat: $e')));
    }
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text(
              'Are you sure you want to delete this chat? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteChat();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isMe = msg['from_user_id'] == widget.currentUserId;
    final message = msg['message'] ?? '';
    final msgId = msg['id'];

    if (message.startsWith('[image]')) {
      final imageUrl = message.substring(7);
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.deepOrangeAccent : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                imageUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
                        const Text('Image not available'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      size: 18,
                      color: Colors.black54,
                    ),
                    tooltip: 'Copy Image URL',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: imageUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Image URL copied to clipboard'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 18,
                      color: Colors.black54,
                    ),
                    tooltip: 'Delete Image',
                    onPressed: () async {
                      if (msgId != null) {
                        try {
                          await Supabase.instance.client
                              .from('messages')
                              .delete()
                              .eq('id', msgId);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Delete failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepOrangeAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                message,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: Colors.black54,
              ),
              onSelected: (value) async {
                if (value == 'delete') {
                  if (msgId != null) {
                    try {
                      await Supabase.instance.client
                          .from('messages')
                          .delete()
                          .eq('id', msgId);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delete failed: $e')),
                      );
                    }
                  }
                } else if (value == 'share') {
                  await Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                    ),
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'share', child: Text('Copy')),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Row(
          children: [
            widget.otherAvatarUrl != null
                ? CircleAvatar(
                  backgroundImage: NetworkImage(widget.otherAvatarUrl!),
                )
                : const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.otherUsername)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteChat();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Chat'),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder:
                      (context, index) => _buildMessageItem(messages[index]),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Type your message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendMessage(_messageController.text),
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
