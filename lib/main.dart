import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String themeKey = 'app_theme_dark_mode';
const String userNameKey = 'user_display_name';
const String notesKey = 'saved_notes';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final isDark = prefs.getBool(themeKey) ?? false;
  final userName = prefs.getString(userNameKey) ?? 'Guest User';

  List<NoteItem> notes = [];
  final String? rawJson = prefs.getString(notesKey);

  if (rawJson != null) {
    try {
      final List<dynamic> decoded = jsonDecode(rawJson);
      notes = decoded
          .map(
            (item) => NoteItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      notes = [];
    }
  }

  runApp(
    NotesVaultApp(
      prefs: prefs,
      initialDark: isDark,
      initialUserName: userName,
      initialNotes: notes,
    ),
  );
}

class NoteItem {
  final String id;
  final String title;
  final String dateText;
  final bool isCompleted;

  const NoteItem({
    required this.id,
    required this.title,
    required this.dateText,
    required this.isCompleted,
  });

  NoteItem copyWith({bool? isCompleted}) {
    return NoteItem(
      id: id,
      title: title,
      dateText: dateText,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateText': dateText,
    'isCompleted': isCompleted,
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'No title',
      dateText: json['dateText'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class NotesVaultApp extends StatefulWidget {
  final SharedPreferences prefs;
  final bool initialDark;
  final String initialUserName;
  final List<NoteItem> initialNotes;

  const NotesVaultApp({
    super.key,
    required this.prefs,
    required this.initialDark,
    required this.initialUserName,
    required this.initialNotes,
  });

  @override
  State<NotesVaultApp> createState() => _NotesVaultAppState();
}

class _NotesVaultAppState extends State<NotesVaultApp> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = widget.initialDark;
  }

  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDark = value;
    });

    await widget.prefs.setBool(themeKey, value);
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF02569B);

    return MaterialApp(
      title: 'Notes & Settings Vault',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: VaultScreen(
        prefs: widget.prefs,
        isDark: _isDark,
        onThemeChanged: _toggleTheme,
        initialUserName: widget.initialUserName,
        initialNotes: widget.initialNotes,
      ),
    );
  }
}

class VaultScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final String initialUserName;
  final List<NoteItem> initialNotes;

  const VaultScreen({
    super.key,
    required this.prefs,
    required this.isDark,
    required this.onThemeChanged,
    required this.initialUserName,
    required this.initialNotes,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late String _userName;
  late List<NoteItem> _notes;

  @override
  void initState() {
    super.initState();

    _userName = widget.initialUserName;
    _notes = List<NoteItem>.from(widget.initialNotes);

    final savedName = widget.prefs.getString(userNameKey);

    if (savedName != null) {
      _nameController.text = savedName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatNow() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(now.day)}.${two(now.month)}.${now.year} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  Future<void> _saveUserName() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    await widget.prefs.setString(userNameKey, name);

    if (!mounted) return;

    setState(() {
      _userName = name;
    });

    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Username saved!')));
  }

  Future<void> _saveNotes() async {
    final String jsonString = jsonEncode(
      _notes.map((note) => note.toJson()).toList(),
    );

    await widget.prefs.setString(notesKey, jsonString);
  }

  Future<void> _addNote() async {
    final title = _noteController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note title')),
      );
      return;
    }

    final note = NoteItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dateText: _formatNow(),
      isCompleted: false,
    );

    setState(() {
      _notes.insert(0, note);
    });

    _noteController.clear();

    await _saveNotes();
  }

  Future<void> _toggleNote(NoteItem note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);

    if (index == -1) return;

    setState(() {
      _notes[index] = note.copyWith(isCompleted: !note.isCompleted);
    });

    await _saveNotes();
  }

  Future<void> _deleteNote(NoteItem note) async {
    setState(() {
      _notes.removeWhere((item) => item.id == note.id);
    });

    await _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes Vault'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        _buildNameSection(),
        _buildAddNoteSection(),
        const Divider(height: 1),
        Expanded(child: _buildNotesList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hello, $_userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
            Switch(value: widget.isDark, onChanged: widget.onThemeChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveUserName(),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _saveUserName,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNoteSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addNote(),
              decoration: const InputDecoration(
                labelText: 'New note',
                prefixIcon: Icon(Icons.edit_note),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    if (_notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.note_alt_outlined, size: 70, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No notes yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Add your first note above.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _notes.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (context, index) {
        final note = _notes[index];

        return Card(
          elevation: 2,
          child: ListTile(
            leading: Checkbox(
              value: note.isCompleted,
              onChanged: (_) => _toggleNote(note),
            ),
            title: Text(
              note.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: note.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(note.dateText),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete note',
              onPressed: () => _deleteNote(note),
            ),
          ),
        );
      },
    );
  }
}
