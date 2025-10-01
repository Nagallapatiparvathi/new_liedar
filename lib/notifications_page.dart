import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class ChatPage extends StatelessWidget {
  final String receiverId;
  final String receiverUsername;
  final String? receiverAvatarUrl;

  const ChatPage({
    required this.receiverId,
    required this.receiverUsername,
    this.receiverAvatarUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverUsername)),
      body: Center(child: Text('Chat with $receiverUsername here!')),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with RouteAware {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _lastNotificationCount = 0;
  StreamSubscription<dynamic>? _notificationSub;
  StreamSubscription<dynamic>? _messageSub;
  final Set<int> _processedMessageIds = {}; // ✅ Track processed messages

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    setupRealtimeListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _audioPlayer.dispose();
    _notificationSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchNotifications();
  }

  Future<void> playNotificationSound() async {
    if (kIsWeb) return;
    await _audioPlayer.play(AssetSource('audio/notification.mp3'));
  }

  Future<void> fetchNotifications() async {
    setState(() => loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          notifications = [];
          loading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('notifications')
          .select('id, type, data, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      final List<Map<String, dynamic>> fetchedNotifications =
          List<Map<String, dynamic>>.from(data);

      if (_lastNotificationCount != 0 &&
          fetchedNotifications.length > _lastNotificationCount) {
        await playNotificationSound();
      }
      _lastNotificationCount = fetchedNotifications.length;

      setState(() {
        notifications = fetchedNotifications;
        loading = false;
      });
    } catch (e) {
      print('❌ NOTIFICATIONS FETCH ERROR: $e');
      setState(() {
        notifications = [];
        loading = false;
      });
    }
  }

  void setupRealtimeListeners() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ Notifications realtime stream
    final notificationStream = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);

    _notificationSub = notificationStream.listen((event) async {
      await playNotificationSound();
      fetchNotifications();
    });

    // ✅ Messages realtime stream
    final messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId);

    _messageSub = messageStream.listen((event) async {
      if (event.isEmpty) return;

      for (final msg in event) {
        final msgId = msg['id'] as int?;
        if (msgId == null || _processedMessageIds.contains(msgId)) {
          continue; // already handled this one
        }
        _processedMessageIds.add(msgId);

        try {
          final response =
              await Supabase.instance.client.from('notifications').insert({
                'user_id': userId,
                'type': 'message',
                'data': json.encode({
                  'sender_id': msg['sender_id'],
                  'sender_username': msg['sender_username'],
                  'sender_avatar_url': msg['sender_avatar_url'],
                  'message': msg['content'],
                }),
                'created_at':
                    msg['created_at'] ?? DateTime.now().toIso8601String(),
              }).select();

          if (response.isEmpty) {
            print('❌ Insert failed — check RLS policy on notifications table');
          } else {
            print('✅ Notification inserted: $response');
            await playNotificationSound();
            fetchNotifications();
          }
        } catch (e) {
          print('❌ Failed to insert notification for message: $e');
        }
      }
    });
  }

  Future<void> _clearAllNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('user_id', userId);

      setState(() => notifications.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear notifications: $e')),
      );
    }
  }

  IconData typeIcon(String? type) {
    switch (type) {
      case 'motivation':
        return Icons.lightbulb;
      case 'reminder':
        return Icons.alarm;
      case 'reaction':
        return Icons.emoji_emotions;
      case 'follow':
        return Icons.person_add;
      case 'message':
        return Icons.mark_email_unread;
      default:
        return Icons.notifications;
    }
  }

  void _openNotification(Map<String, dynamic> n) {
    if (n['type'] == 'message') {
      dynamic rawData = n['data'];
      Map<String, dynamic> msgData = {};
      if (rawData != null) {
        if (rawData is String) {
          try {
            msgData = json.decode(rawData);
          } catch (_) {
            msgData = {};
          }
        } else if (rawData is Map<String, dynamic>) {
          msgData = rawData;
        }
      }

      final senderId = msgData['sender_id'];
      final senderUsername = msgData['sender_username'] ?? 'Unknown';
      final senderAvatarUrl = msgData['sender_avatar_url'];

      if (senderId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => ChatPage(
                  receiverId: senderId,
                  receiverUsername: senderUsername,
                  receiverAvatarUrl: senderAvatarUrl,
                ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          tooltip: 'Clear All Notifications',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Clear All Notifications?'),
                    content: const Text(
                      'This action cannot be undone. Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
            );
            if (confirmed == true) {
              await _clearAllNotifications();
            }
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.deepOrange),
        elevation: 2,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? const Center(child: Text('No notifications yet! 🎉'))
              : RefreshIndicator(
                onRefresh: fetchNotifications,
                child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (ctx, i) {
                    final n = notifications[i];
                    final createdAt =
                        n['created_at'] != null
                            ? n['created_at'].toString().substring(0, 16)
                            : '';
                    dynamic rawData = n['data'];
                    Map<String, dynamic> msgData = {};
                    if (rawData != null) {
                      if (rawData is String) {
                        try {
                          msgData = json.decode(rawData);
                        } catch (_) {
                          msgData = {};
                        }
                      } else if (rawData is Map<String, dynamic>) {
                        msgData = rawData;
                      }
                    }

                    final message = msgData['message'] ?? '';
                    final sender = msgData['sender_username'] ?? 'Unknown';
                    final avatarUrl = msgData['sender_avatar_url'];

                    String titleText;
                    if (n['type'] == 'message') {
                      titleText = '$sender: You have a new message';
                    } else {
                      titleText =
                          message.isNotEmpty
                              ? message
                              : n['type'] ?? 'Notification';
                    }

                    return ListTile(
                      leading:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? CircleAvatar(
                                backgroundImage: NetworkImage(avatarUrl),
                              )
                              : CircleAvatar(
                                child: Text(sender[0].toUpperCase()),
                              ),
                      title: Text(
                        titleText,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        createdAt,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => _openNotification(n),
                    );
                  },
                ),
              ),
    );
  }
}
