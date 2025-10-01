import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const reactionsList = [
  {'emoji': '🤣', 'type': 'funny'},
  {'emoji': '😱', 'type': 'shocked'},
  {'emoji': '😭', 'type': 'sad'},
  {'emoji': '😡', 'type': 'angry'},
  {'emoji': '🤯', 'type': 'mindblown'},
  {'emoji': '❤', 'type': 'love'},
];

class LieVaultPage extends StatefulWidget {
  const LieVaultPage({super.key});

  @override
  State<LieVaultPage> createState() => _LieVaultPageState();
}

class _LieVaultPageState extends State<LieVaultPage> {
  List userLies = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchUserLies();
  }

  Future<void> _fetchUserLies() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final res = await Supabase.instance.client
          .from('lies')
          .select('id, lie_text, category, region, created_at, image_url')
          .eq('user_id', user!.id)
          .order('created_at', ascending: false);
      setState(() {
        userLies = res as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Error loading your lies: $e";
      });
    }
  }

  Future<int> _getReactionCount(int lieId, String reactionType) async {
    final res = await Supabase.instance.client
        .from('reactions')
        .select('id')
        .eq('lie_id', lieId)
        .eq('reaction_type', reactionType);
    return (res as List).length;
  }

  Widget _reactionsSummaryRow(int lieId) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children:
          reactionsList.map((reaction) {
            final emoji = reaction['emoji']!;
            final type = reaction['type']!;
            return FutureBuilder<int>(
              future: _getReactionCount(lieId, type),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return count > 0
                    ? Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: TextStyle(fontSize: 18)),
                          SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                    : SizedBox.shrink();
              },
            );
          }).toList(),
    );
  }

  Widget _lieCard(Map lie) {
    final String text = (lie['lie_text'] ?? '').toString();
    final String category = lie['category'] ?? '';
    final String region = lie['region'] ?? '';
    final createdAt = lie['created_at']?.toString() ?? '';
    final String? imageUrl = lie['image_url'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.isNotEmpty ? text : "No text.",
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            if (category.isNotEmpty)
              Text(
                "Category: $category",
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (region.isNotEmpty)
              Text(
                "Country: $region",
                style: TextStyle(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (createdAt.isNotEmpty)
              Text(
                "Created: ${createdAt.substring(0, 10)}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  color: Colors.grey[100],
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: 350, minHeight: 150),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                    : null,
                            color: Colors.deepPurple,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text('Failed to load image'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              "Reactions received:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            _reactionsSummaryRow(lie['id']),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Lie Vault')),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null
                ? Center(
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                : (userLies.isEmpty
                    ? const Center(
                      child: Text("You haven't submitted any lies yet."),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: userLies.length,
                      itemBuilder: (context, index) {
                        return _lieCard(userLies[index]);
                      },
                    )),
      ),
    );
  }
}
