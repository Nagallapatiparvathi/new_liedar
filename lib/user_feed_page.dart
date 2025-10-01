import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserFeedPage extends StatefulWidget {
  final String userId;
  final String username;

  const UserFeedPage({super.key, required this.userId, required this.username});

  @override
  State<UserFeedPage> createState() => _UserFeedPageState();
}

class _UserFeedPageState extends State<UserFeedPage> {
  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
  }

  Future<List<Map<String, dynamic>>> _fetchUserLies() async {
    final response = await _supabase
        .from('lies')
        .select()
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUserLies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final lies = snapshot.data ?? [];

          if (lies.isEmpty) {
            return const Center(child: Text("No lies shared yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: lies.length,
            itemBuilder: (context, index) {
              final lie = lies[index];
              final content = lie['content'] ?? '';
              final createdAt = DateTime.tryParse(lie['created_at'] ?? '');

              return Align(
                alignment: Alignment.centerLeft, // Always left-aligned
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (createdAt != null)
                            Text(
                              "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(
                              Icons.emoji_emotions_outlined,
                              size: 20,
                              color: Colors.orange,
                            ),
                            onPressed: () {
                              // TODO: add reactions insert here
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.share,
                              size: 20,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              // TODO: share feature here
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
