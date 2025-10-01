import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

const Color kLieDarBg = Color(0xFFD8E4BC);
const Color kAccent = Color(0xFF00A86B);

class SubmitLiePage extends StatefulWidget {
  const SubmitLiePage({super.key});

  @override
  State<SubmitLiePage> createState() => _SubmitLiePageState();
}

class _SubmitLiePageState extends State<SubmitLiePage> {
  final TextEditingController _lieController = TextEditingController();
  bool _isAnonymous = false;
  String? _selectedCategory;
  Map<String, String>? _selectedCountry;
  String? _selectedReaction;

  File? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _imagePreviewPath;

  final categories = [
    'Social',
    'Personal',
    'Work',
    'Family',
    'Relationship',
    'Other',
  ];
  final reactionsList = [
    {'emoji': '🤣', 'type': 'funny'},
    {'emoji': '😱', 'type': 'shocked'},
    {'emoji': '😭', 'type': 'sad'},
    {'emoji': '😡', 'type': 'angry'},
    {'emoji': '🤯', 'type': 'mindblown'},
    {'emoji': '❤', 'type': 'love'},
  ];
  final List<Map<String, String>> countryList = [
    {"name": "India", "flag": "🇮🇳"},
    {"name": "United States", "flag": "🇺🇸"},
    {"name": "United Kingdom", "flag": "🇬🇧"},
    {"name": "Australia", "flag": "🇦🇺"},
    {"name": "Canada", "flag": "🇨🇦"},
    {"name": "Germany", "flag": "🇩🇪"},
    {"name": "France", "flag": "🇫🇷"},
    {"name": "Brazil", "flag": "🇧🇷"},
    {"name": "Japan", "flag": "🇯🇵"},
    {"name": "China", "flag": "🇨🇳"},
    {"name": "South Africa", "flag": "🇿🇦"},
    {"name": "Mexico", "flag": "🇲🇽"},
    {"name": "Others", "flag": "🌎"},
  ];

  bool _isSubmitting = false;
  String? _errorMsg;

  Future<void> _pickImage() async {
    setState(() {
      _errorMsg = null;
    });
    FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: kIsWeb, // for web
    );
    if (picked != null && picked.files.isNotEmpty) {
      final file = picked.files.first;
      _pickedImageBytes = file.bytes;
      if (kIsWeb) {
        _imagePreviewPath = null;
      } else {
        _pickedImageFile = File(file.path!);
        _imagePreviewPath = file.path!;
      }
      setState(() {});
    }
  }

  Future<String?> _uploadImageFile(String userId) async {
    if (_pickedImageBytes == null && _pickedImageFile == null) return null;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name =
          _pickedImageFile != null
              ? _pickedImageFile!.path.split('/').last
              : 'webfile_$timestamp.jpg';
      final filename = '${userId}$timestamp$name';

      final storage = Supabase.instance.client.storage.from('lie-images');
      final bytes = _pickedImageBytes ?? await _pickedImageFile!.readAsBytes();
      await storage.uploadBinary(filename, bytes);
      final publicUrl = storage.getPublicUrl(filename);
      return publicUrl;
    } catch (e) {
      setState(() {
        _errorMsg = "Image upload error: $e";
      });
      return null;
    }
  }

  Future<void> _submitLie() async {
    final user = Supabase.instance.client.auth.currentUser;
    final lieText = _lieController.text.trim();
    final country = _selectedCountry?['name'];
    final category = _selectedCategory;
    final reactionType = _selectedReaction;

    if (user == null ||
        lieText.isEmpty ||
        country == null ||
        category == null ||
        reactionType == null) {
      setState(() {
        _errorMsg =
            "Please fill all fields and select country, category, and reaction.";
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    String? imageUrl;
    if (_pickedImageFile != null || _pickedImageBytes != null) {
      imageUrl = await _uploadImageFile(user.id);
      if (imageUrl == null) {
        setState(() {
          _isSubmitting = false;
        });
        return; // error is already set
      }
    }

    try {
      final reactionEmoji =
          reactionsList.firstWhere((r) => r['type'] == reactionType)['emoji'];
      final inserted =
          await Supabase.instance.client.from('lies').insert({
            'lie_text': lieText,
            'user_id': user.id,
            'region': country,
            'is_anonymous': _isAnonymous,
            'category': category,
            'emonji': reactionEmoji,
            'image_url': imageUrl, // can be null
          }).select();

      setState(() {
        _isSubmitting = false;
        _pickedImageFile = null;
        _pickedImageBytes = null;
        _imagePreviewPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Lie has been submitted!"),
          backgroundColor: kAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMsg = "Submit error: $e";
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLieDarBg,
      appBar: AppBar(
        title: Text(
          "Submit Your Lie",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kAccent,
        elevation: 5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
          child: Card(
            color: Colors.white,
            elevation: 7,
            margin: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Share your lie of the day!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _lieController,
                    decoration: InputDecoration(
                      labelText: "Your lie",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      fillColor: kLieDarBg,
                      filled: true,
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 18),
                  // IMAGE PICKER SECTION
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.image, color: kAccent),
                        label: Text(
                          "Add Image",
                          style: TextStyle(color: kAccent),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLieDarBg.withOpacity(0.7),
                          elevation: 0,
                          side: BorderSide(color: kAccent),
                        ),
                      ),
                      SizedBox(width: 12),
                      if (_pickedImageFile != null || _pickedImageBytes != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _pickedImageFile = null;
                              _pickedImageBytes = null;
                              _imagePreviewPath = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: kAccent, width: 1.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, color: kAccent),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_pickedImageFile != null || _pickedImageBytes != null)
                    Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 5),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child:
                              kIsWeb
                                  ? Image.memory(
                                    _pickedImageBytes!,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  )
                                  : Image.file(
                                    _pickedImageFile!,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                      ),
                    ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<Map<String, String>>(
                    value: _selectedCountry,
                    items:
                        countryList
                            .map(
                              (country) => DropdownMenuItem(
                                value: country,
                                child: Row(
                                  children: [
                                    Text(
                                      country['flag']!,
                                      style: TextStyle(fontSize: 19),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      country['name']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: kAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    decoration: InputDecoration(
                      labelText: "Country",
                      labelStyle: TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      filled: true,
                      fillColor: kLieDarBg.withOpacity(0.35),
                    ),
                    onChanged: (val) => setState(() => _selectedCountry = val),
                    isExpanded: true,
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Checkbox(
                        value: _isAnonymous,
                        activeColor: kAccent,
                        onChanged:
                            (val) =>
                                setState(() => _isAnonymous = val ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Text(
                        "Submit as anonymous",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items:
                        categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                            .toList(),
                    decoration: InputDecoration(
                      labelText: "Category",
                      labelStyle: TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: kLieDarBg.withOpacity(0.28),
                    ),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "Choose your reaction:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: kAccent,
                    ),
                  ),
                  SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children:
                        reactionsList.map((reaction) {
                          final emoji = reaction['emoji']!;
                          final type = reaction['type']!;
                          final isSelected = _selectedReaction == type;
                          return ChoiceChip(
                            label: Text(emoji, style: TextStyle(fontSize: 18)),
                            selected: isSelected,
                            selectedColor: kAccent.withOpacity(0.30),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 10,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: kAccent, width: 1.2),
                            onSelected:
                                (_) => setState(() => _selectedReaction = type),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: 25),
                  _isSubmitting
                      ? Center(child: CircularProgressIndicator(color: kAccent))
                      : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _submitLie,
                        child: Text(
                          "Submit",
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                  if (_errorMsg != null) ...[
                    SizedBox(height: 13),
                    Text(
                      _errorMsg!,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
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
  }
}
