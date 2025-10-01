import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ShareLiePage extends StatefulWidget {
  const ShareLiePage({Key? key}) : super(key: key);

  @override
  _ShareLiePageState createState() => _ShareLiePageState();
}

class _ShareLiePageState extends State<ShareLiePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _lieController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _shareLie() async {
    if (_lieController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a lie or select an image")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fileBytes = await _selectedImage!.readAsBytes();

        await supabase.storage
            .from('lies')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        imageUrl = supabase.storage.from('lies').getPublicUrl(fileName);
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      // Insert lie into database
      await supabase.from('lies').insert({
        'user_id': user.id,
        'content': _lieController.text.trim(),
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });

      _lieController.clear();
      setState(() {
        _selectedImage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lie shared successfully!")));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error sharing lie: $e")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _lieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Share a Lie"),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _shareLie,
            icon:
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.send),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _lieController,
              decoration: const InputDecoration(
                labelText: "What's your lie?",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("Add Image"),
            ),
          ],
        ),
      ),
    );
  }
}
