import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أدواتي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class Task {
  final String id;
  String title;
  bool done;
  Task({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory Task.fromJson(Map<String, dynamic> j) =>
      Task(id: j['id'], title: j['title'], done: j['done'] ?? false);
}

class Note {
  final String id;
  String title;
  String body;
  Note({required this.id, required this.title, required this.body});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};
  factory Note.fromJson(Map<String, dynamic> j) =>
      Note(id: j['id'], title: j['title'], body: j['body'] ?? '');
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  List<Task> _tasks = [];
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final t = jsonDecode(p.getString('tasks') ?? '[]') as List;
    final n = jsonDecode(p.getString('notes') ?? '[]') as List;
    setState(() {
      _tasks = t.map((e) => Task.fromJson(e)).toList();
      _notes = n.map((e) => Note.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tasks', jsonEncode(_tasks.map((e) => e.toJson()).toList()));
    await p.setString('notes', jsonEncode(_notes.map((e) => e.toJson()).toList()));
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _addTask() async {
    final c = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مهمة جديدة'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'شنو خاصك دير؟'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('زيد')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      setState(() => _tasks.insert(0, Task(id: _newId(), title: title.trim())));
      _save();
    }
  }

  Future<void> _editNote([Note? note]) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );
    if (result == null) return;
    setState(() {
      final i = _notes.indexWhere((n) => n.id == result.id);
      if (i >= 0) {
        _notes[i] = result;
      } else {
        _notes.insert(0, result);
      }
    });
    _save();
  }

  void _deleteNote(Note n) {
    setState(() => _notes.removeWhere((x) => x.id == n.id));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _tasks.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'المهام' : 'الملاحظات'),
        bottom: _tab == 0 && _tasks.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: doneCount / _tasks.length),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_tab == 0 ? _buildTasks() : _buildNotes()),
      floatingActionButton: FloatingActionButton(
        onPressed: _tab == 0 ? _addTask : () => _editNote(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'المهام'),
          NavigationDestination(icon: Icon(Icons.note_alt_outlined), label: 'الملاحظات'),
        ],
      ),
    );
  }

  Widget _buildTasks() {
    if (_tasks.isEmpty) {
      return const Center(child: Text('ما كاين حتى مهمة. ضغط على + باش تزيد.'));
    }
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (_, i) {
        final t = _tasks[i];
        return Dismissible(
          key: ValueKey(t.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.startToEnd,
          onDismissed: (_) {
            setState(() => _tasks.removeWhere((x) => x.id == t.id));
            _save();
          },
          child: CheckboxListTile(
            value: t.done,
            onChanged: (v) {
              setState(() => t.done = v ?? false);
              _save();
            },
            title: Text(
              t.title,
              style: TextStyle(
                decoration: t.done ? TextDecoration.lineThrough : null,
                color: t.done ? Colors.grey : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotes() {
    if (_notes.isEmpty) {
      return const Center(child: Text('ما كاين حتى ملاحظة. ضغط على + باش تزيد.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _notes.length,
      itemBuilder: (_, i) {
        final n = _notes[i];
        return Card(
          child: ListTile(
            title: Text(n.title.isEmpty ? 'بلا عنوان' : n.title),
            subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _editNote(n),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNote(n),
            ),
          ),
        );
      },
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.note?.body ?? '');

  void _saveAndClose() {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      Note(
        id: widget.note?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        body: _body.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveAndClose),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(hintText: 'العنوان', border: InputBorder.none),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'كتب ملاحظتك هنا...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
