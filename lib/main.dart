import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BibleApp());
}

// ============================================================
// APP
// ============================================================

class BibleApp extends StatefulWidget {
  const BibleApp({super.key});

  @override
  State<BibleApp> createState() => _BibleAppState();
}

class _BibleAppState extends State<BibleApp> {
  final AppState appState = AppState();

  @override
  void initState() {
    super.initState();
    appState.load();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        return AppScope(
          state: appState,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Bible',
            theme: ThemeData(
              useMaterial3: true,
              brightness:
                  appState.darkMode ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: appState.darkMode
                  ? const Color(0xFF121015)
                  : const Color(0xFFF7F4F8),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF8C5AC8),
                brightness:
                    appState.darkMode ? Brightness.dark : Brightness.light,
              ),
            ),
            home: const MainNavigation(),
          ),
        );
      },
    );
  }
}

// ============================================================
// APP SCOPE
// ============================================================

class AppScope extends InheritedWidget {
  final AppState state;

  const AppScope({
    super.key,
    required this.state,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(result != null, 'AppScope was not found above this widget.');
    return result!.state;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => state != oldWidget.state;
}

// ============================================================
// APP STATE
// ============================================================

class AppState extends ChangeNotifier {
  SharedPreferences? prefs;

  bool darkMode = true;
  double fontSize = 20;
  double lineHeight = 1.65;

  String lastBook = 'Genesis';
  int lastChapter = 1;

  final Set<String> bookmarks = <String>{};
  final Set<String> favorites = <String>{};
  final Set<String> highlights = <String>{};
  final Map<String, String> notes = <String, String>{};

  bool initialized = false;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();

    darkMode = prefs!.getBool('darkMode') ?? true;
    fontSize = prefs!.getDouble('fontSize') ?? 20;
    lineHeight = prefs!.getDouble('lineHeight') ?? 1.65;
    lastBook = prefs!.getString('lastBook') ?? 'Genesis';
    lastChapter = prefs!.getInt('lastChapter') ?? 1;

    bookmarks
      ..clear()
      ..addAll(prefs!.getStringList('bookmarks') ?? <String>[]);

    favorites
      ..clear()
      ..addAll(prefs!.getStringList('favorites') ?? <String>[]);

    highlights
      ..clear()
      ..addAll(prefs!.getStringList('highlights') ?? <String>[]);

    notes.clear();

    final savedNotes = prefs!.getString('notes');
    if (savedNotes != null && savedNotes.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedNotes);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            notes[entry.key.toString()] = entry.value.toString();
          }
        }
      } catch (_) {}
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> save() async {
    final p = prefs;
    if (p == null) return;

    await p.setBool('darkMode', darkMode);
    await p.setDouble('fontSize', fontSize);
    await p.setDouble('lineHeight', lineHeight);
    await p.setString('lastBook', lastBook);
    await p.setInt('lastChapter', lastChapter);
    await p.setStringList('bookmarks', bookmarks.toList());
    await p.setStringList('favorites', favorites.toList());
    await p.setStringList('highlights', highlights.toList());
    await p.setString('notes', jsonEncode(notes));
  }

  void toggleBookmark(String key) {
    bookmarks.contains(key) ? bookmarks.remove(key) : bookmarks.add(key);
    notifyListeners();
    save();
  }

  void toggleFavorite(String key) {
    favorites.contains(key) ? favorites.remove(key) : favorites.add(key);
    notifyListeners();
    save();
  }

  void toggleHighlight(String key) {
    highlights.contains(key) ? highlights.remove(key) : highlights.add(key);
    notifyListeners();
    save();
  }

  void setNote(String key, String value) {
    final note = value.trim();
    if (note.isEmpty) {
      notes.remove(key);
    } else {
      notes[key] = note;
    }
    notifyListeners();
    save();
  }

  void setFontSize(double value) {
    fontSize = value;
    notifyListeners();
    save();
  }

  void setLineHeight(double value) {
    lineHeight = value;
    notifyListeners();
    save();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    notifyListeners();
    save();
  }

  void setLastPosition(String book, int chapter) {
    lastBook = book;
    lastChapter = chapter;
    save();
  }

  void clearSavedData() {
    bookmarks.clear();
    favorites.clear();
    highlights.clear();
    notes.clear();
    notifyListeners();
    save();
  }
}

// ============================================================
// MODELS
// ============================================================

class BibleBook {
  final String name;
  final String fileName;
  final bool oldTestament;

  const BibleBook({
    required this.name,
    required this.fileName,
    required this.oldTestament,
  });
}

class BibleVerse {
  final int number;
  final String text;

  const BibleVerse({
    required this.number,
    required this.text,
  });
}

class BibleChapter {
  final int number;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.number,
    required this.verses,
  });
}

class BibleBookData {
  final String name;
  final List<BibleChapter> chapters;

  const BibleBookData({
    required this.name,
    required this.chapters,
  });
}

class SearchResult {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  const SearchResult({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  String get key => '$book|$chapter|$verse';
}

// ============================================================
// ALL 66 BOOKS
// ============================================================

const List<BibleBook> bibleBooks = [
  BibleBook(name: 'Genesis', fileName: 'Genesis.json', oldTestament: true),
  BibleBook(name: 'Exodus', fileName: 'Exodus.json', oldTestament: true),
  BibleBook(name: 'Leviticus', fileName: 'Leviticus.json', oldTestament: true),
  BibleBook(name: 'Numbers', fileName: 'Numbers.json', oldTestament: true),
  BibleBook(name: 'Deuteronomy', fileName: 'Deuteronomy.json', oldTestament: true),
  BibleBook(name: 'Joshua', fileName: 'Joshua.json', oldTestament: true),
  BibleBook(name: 'Judges', fileName: 'Judges.json', oldTestament: true),
  BibleBook(name: 'Ruth', fileName: 'Ruth.json', oldTestament: true),
  BibleBook(name: '1 Samuel', fileName: '1Samuel.json', oldTestament: true),
  BibleBook(name: '2 Samuel', fileName: '2Samuel.json', oldTestament: true),
  BibleBook(name: '1 Kings', fileName: '1Kings.json', oldTestament: true),
  BibleBook(name: '2 Kings', fileName: '2Kings.json', oldTestament: true),
  BibleBook(name: '1 Chronicles', fileName: '1Chronicles.json', oldTestament: true),
  BibleBook(name: '2 Chronicles', fileName: '2Chronicles.json', oldTestament: true),
  BibleBook(name: 'Ezra', fileName: 'Ezra.json', oldTestament: true),
  BibleBook(name: 'Nehemiah', fileName: 'Nehemiah.json', oldTestament: true),
  BibleBook(name: 'Esther', fileName: 'Esther.json', oldTestament: true),
  BibleBook(name: 'Job', fileName: 'Job.json', oldTestament: true),
  BibleBook(name: 'Psalms', fileName: 'Psalms.json', oldTestament: true),
  BibleBook(name: 'Proverbs', fileName: 'Proverbs.json', oldTestament: true),
  BibleBook(name: 'Ecclesiastes', fileName: 'Ecclesiastes.json', oldTestament: true),
  BibleBook(name: 'Song of Solomon', fileName: 'SongofSolomon.json', oldTestament: true),
  BibleBook(name: 'Isaiah', fileName: 'Isaiah.json', oldTestament: true),
  BibleBook(name: 'Jeremiah', fileName: 'Jeremiah.json', oldTestament: true),
  BibleBook(name: 'Lamentations', fileName: 'Lamentations.json', oldTestament: true),
  BibleBook(name: 'Ezekiel', fileName: 'Ezekiel.json', oldTestament: true),
  BibleBook(name: 'Daniel', fileName: 'Daniel.json', oldTestament: true),
  BibleBook(name: 'Hosea', fileName: 'Hosea.json', oldTestament: true),
  BibleBook(name: 'Joel', fileName: 'Joel.json', oldTestament: true),
  BibleBook(name: 'Amos', fileName: 'Amos.json', oldTestament: true),
  BibleBook(name: 'Obadiah', fileName: 'Obadiah.json', oldTestament: true),
  BibleBook(name: 'Jonah', fileName: 'Jonah.json', oldTestament: true),
  BibleBook(name: 'Micah', fileName: 'Micah.json', oldTestament: true),
  BibleBook(name: 'Nahum', fileName: 'Nahum.json', oldTestament: true),
  BibleBook(name: 'Habakkuk', fileName: 'Habakkuk.json', oldTestament: true),
  BibleBook(name: 'Zephaniah', fileName: 'Zephaniah.json', oldTestament: true),
  BibleBook(name: 'Haggai', fileName: 'Haggai.json', oldTestament: true),
  BibleBook(name: 'Zechariah', fileName: 'Zechariah.json', oldTestament: true),
  BibleBook(name: 'Malachi', fileName: 'Malachi.json', oldTestament: true),

  BibleBook(name: 'Matthew', fileName: 'Matthew.json', oldTestament: false),
  BibleBook(name: 'Mark', fileName: 'Mark.json', oldTestament: false),
  BibleBook(name: 'Luke', fileName: 'Luke.json', oldTestament: false),
  BibleBook(name: 'John', fileName: 'John.json', oldTestament: false),
  BibleBook(name: 'Acts', fileName: 'Acts.json', oldTestament: false),
  BibleBook(name: 'Romans', fileName: 'Romans.json', oldTestament: false),
  BibleBook(name: '1 Corinthians', fileName: '1Corinthians.json', oldTestament: false),
  BibleBook(name: '2 Corinthians', fileName: '2Corinthians.json', oldTestament: false),
  BibleBook(name: 'Galatians', fileName: 'Galatians.json', oldTestament: false),
  BibleBook(name: 'Ephesians', fileName: 'Ephesians.json', oldTestament: false),
  BibleBook(name: 'Philippians', fileName: 'Philippians.json', oldTestament: false),
  BibleBook(name: 'Colossians', fileName: 'Colossians.json', oldTestament: false),
  BibleBook(name: '1 Thessalonians', fileName: '1Thessalonians.json', oldTestament: false),
  BibleBook(name: '2 Thessalonians', fileName: '2Thessalonians.json', oldTestament: false),
  BibleBook(name: '1 Timothy', fileName: '1Timothy.json', oldTestament: false),
  BibleBook(name: '2 Timothy', fileName: '2Timothy.json', oldTestament: false),
  BibleBook(name: 'Titus', fileName: 'Titus.json', oldTestament: false),
  BibleBook(name: 'Philemon', fileName: 'Philemon.json', oldTestament: false),
  BibleBook(name: 'Hebrews', fileName: 'Hebrews.json', oldTestament: false),
  BibleBook(name: 'James', fileName: 'James.json', oldTestament: false),
  BibleBook(name: '1 Peter', fileName: '1Peter.json', oldTestament: false),
  BibleBook(name: '2 Peter', fileName: '2Peter.json', oldTestament: false),
  BibleBook(name: '1 John', fileName: '1John.json', oldTestament: false),
  BibleBook(name: '2 John', fileName: '2John.json', oldTestament: false),
  BibleBook(name: '3 John', fileName: '3John.json', oldTestament: false),
  BibleBook(name: 'Jude', fileName: 'Jude.json', oldTestament: false),
  BibleBook(name: 'Revelation', fileName: 'Revelation.json', oldTestament: false),
];

// ============================================================
// BIBLE SERVICE
// ============================================================

class BibleService {
  static const String baseUrl =
      'https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/';

  static final Map<String, BibleBookData> cache = {};

  static Future<BibleBookData> loadBook(BibleBook book) async {
    final cached = cache[book.name];
    if (cached != null) return cached;

    final response = await http
        .get(Uri.parse('$baseUrl${book.fileName}'))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}: unable to load ${book.name}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid Bible data for ${book.name}.');
    }

    final rawChapters = decoded['chapters'];
    if (rawChapters is! List) {
      throw Exception('No chapters found for ${book.name}.');
    }

    final chapters = <BibleChapter>[];

    for (final rawChapter in rawChapters) {
      if (rawChapter is! Map) continue;

      final chapterNumber =
          int.tryParse(rawChapter['chapter']?.toString() ?? '') ??
          (chapters.length + 1);

      final rawVerses = rawChapter['verses'];
      final verses = <BibleVerse>[];

      if (rawVerses is List) {
        for (final rawVerse in rawVerses) {
          if (rawVerse is! Map) continue;

          final number =
              int.tryParse(rawVerse['verse']?.toString() ?? '') ??
              (verses.length + 1);

          final text = rawVerse['text']?.toString().trim() ?? '';
          if (text.isEmpty) continue;

          verses.add(BibleVerse(number: number, text: text));
        }
      }

      chapters.add(
        BibleChapter(number: chapterNumber, verses: verses),
      );
    }

    chapters.sort((a, b) => a.number.compareTo(b.number));

    final result = BibleBookData(
      name: book.name,
      chapters: chapters,
    );

    cache[book.name] = result;
    return result;
  }

  static Future<BibleChapter> loadChapter(
    BibleBook book,
    int chapterNumber,
  ) async {
    final data = await loadBook(book);

    final index =
        data.chapters.indexWhere((c) => c.number == chapterNumber);

    if (index == -1) {
      throw Exception(
        '${book.name} chapter $chapterNumber does not exist.',
      );
    }

    return data.chapters[index];
  }

  static Future<List<SearchResult>> search(
    String query, {
    void Function(int current, int total)? onProgress,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <SearchResult>[];

    final results = <SearchResult>[];

    for (int i = 0; i < bibleBooks.length; i++) {
      final book = bibleBooks[i];
      onProgress?.call(i + 1, bibleBooks.length);

      BibleBookData data;
      try {
        data = await loadBook(book);
      } catch (_) {
        continue;
      }

      for (final chapter in data.chapters) {
        for (final verse in chapter.verses) {
          if (verse.text.toLowerCase().contains(q)) {
            results.add(
              SearchResult(
                book: book.name,
                chapter: chapter.number,
                verse: verse.number,
                text: verse.text,
              ),
            );

            if (results.length >= 100) {
              return results;
            }
          }
        }
      }
    }

    return results;
  }
}

// ============================================================
// MAIN NAVIGATION
// ============================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 1;

  final pages = const [
    HomePage(),
    BiblePage(),
    AudioPage(),
    SearchPage(),
    MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: app.darkMode
              ? const Color(0xFF211E24)
              : Colors.white,
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, -2),
              color: Colors.black26,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_outlined, 'Home', 0),
                _navItem(Icons.menu_book, 'Bible', 1),
                _navItem(Icons.headphones_outlined, 'Audio', 2),
                _navItem(Icons.search, 'Search', 3),
                _navItem(Icons.more_horiz, 'More', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int itemIndex) {
    final selected = index == itemIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => setState(() => index = itemIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF564267)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(icon, size: 27),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    final book = bibleBooks.firstWhere(
      (b) => b.name == app.lastBook,
      orElse: () => bibleBooks.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bible',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4E3670),
                  Color(0xFF291E36),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to the Bible',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Read the complete 66-book King James Version Bible.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BibleReaderPage(
                          book: book,
                          chapter: app.lastChapter,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: Text(
                    'Continue ${app.lastBook} ${app.lastChapter}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _quickCard(
                  context,
                  Icons.bookmark,
                  'Bookmarks',
                  () => _openSaved(context, SavedType.bookmarks),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickCard(
                  context,
                  Icons.favorite,
                  'Favorites',
                  () => _openSaved(context, SavedType.favorites),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quickCard(
                  context,
                  Icons.highlight,
                  'Highlights',
                  () => _openSaved(context, SavedType.highlights),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickCard(
                  context,
                  Icons.note_alt_outlined,
                  'Notes',
                  () => _openSaved(context, SavedType.notes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Popular Books',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final b in [
            bibleBooks[0],
            bibleBooks[18],
            bibleBooks[39],
            bibleBooks[42],
            bibleBooks[65],
          ])
            _homeBookButton(context, b),
        ],
      ),
    );
  }

  static Widget _quickCard(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _homeBookButton(
    BuildContext context,
    BibleBook book,
  ) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF563A82),
          child: Icon(Icons.menu_book),
        ),
        title: Text(
          book.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChapterSelectionPage(book: book),
            ),
          );
        },
      ),
    );
  }

  static void _openSaved(BuildContext context, SavedType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavedPage(type: type)),
    );
  }

  static void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }
}

// ============================================================
// BIBLE BOOKS PAGE
// ============================================================

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  bool oldTestament = true;

  @override
  Widget build(BuildContext context) {
    final books = bibleBooks
        .where((book) => book.oldTestament == oldTestament)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bible',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: _tab(
                    'Old Testament',
                    oldTestament,
                    () => setState(() => oldTestament = true),
                  ),
                ),
                Expanded(
                  child: _tab(
                    'New Testament',
                    !oldTestament,
                    () => setState(() => oldTestament = false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 5, 18, 20),
              itemCount: books.length,
              itemBuilder: (_, index) {
                final book = books[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 29,
                      backgroundColor: const Color(0xFF563A82),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      book.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 32,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChapterSelectionPage(book: book),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 4,
              color: selected
                  ? const Color(0xFFD0A7FF)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: selected
                ? const Color(0xFFD0A7FF)
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHAPTER SELECTION
// ============================================================

class ChapterSelectionPage extends StatefulWidget {
  final BibleBook book;

  const ChapterSelectionPage({
    super.key,
    required this.book,
  });

  @override
  State<ChapterSelectionPage> createState() =>
      _ChapterSelectionPageState();
}

class _ChapterSelectionPageState extends State<ChapterSelectionPage> {
  BibleBookData? bookData;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await BibleService.loadBook(widget.book);
      if (!mounted) return;

      setState(() {
        bookData = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Unable to load ${widget.book.name}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _errorBody()
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: bookData!.chapters.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, index) {
                    final chapter = bookData!.chapters[index].number;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BibleReaderPage(
                                book: widget.book,
                                chapter: chapter,
                              ),
                            ),
                          );
                        },
                        child: Center(
                          child: Text(
                            '$chapter',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 60),
          const SizedBox(height: 15),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _load,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BIBLE READER
// ============================================================

class BibleReaderPage extends StatefulWidget {
  final BibleBook book;
  final int chapter;

  const BibleReaderPage({
    super.key,
    required this.book,
    required this.chapter,
  });

  @override
  State<BibleReaderPage> createState() => _BibleReaderPageState();
}

class _BibleReaderPageState extends State<BibleReaderPage> {
  BibleChapter? chapterData;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await BibleService.loadChapter(
        widget.book,
        widget.chapter,
      );

      if (!mounted) return;

      setState(() {
        chapterData = data;
        loading = false;
      });

      AppScope.of(context).setLastPosition(
        widget.book.name,
        widget.chapter,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error =
            'Unable to load this chapter.\nCheck your internet connection.';
      });
    }
  }

  void _goPrevious() {
    if (widget.chapter <= 1) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderPage(
          book: widget.book,
          chapter: widget.chapter - 1,
        ),
      ),
    );
  }

  void _goNext() {
    final total =
        BibleService.cache[widget.book.name]?.chapters.length ?? 0;

    if (widget.chapter >= total) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderPage(
          book: widget.book,
          chapter: widget.chapter + 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final total =
        BibleService.cache[widget.book.name]?.chapters.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.book.name} ${widget.chapter}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AudioPage(
                    initialBook: widget.book,
                    initialChapter: widget.chapter,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChapterActions,
          ),
          IconButton(
            icon: const Icon(Icons.format_size),
            onPressed: _showReaderSettings,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 60),
                        const SizedBox(height: 15),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: _loadChapter,
                          child: const Text('TRY AGAIN'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          25,
                          22,
                          30,
                        ),
                        itemCount: chapterData!.verses.length,
                        itemBuilder: (_, index) {
                          final verse = chapterData!.verses[index];

                          return VerseWidget(
                            book: widget.book,
                            chapter: widget.chapter,
                            verse: verse,
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF211E24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                widget.chapter > 1 ? _goPrevious : null,
                            icon: const Icon(
                              Icons.chevron_left,
                              size: 35,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${widget.book.name} ${widget.chapter}'
                              '  鈥�  $total chapters',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                widget.chapter < total ? _goNext : null,
                            icon: const Icon(
                              Icons.chevron_right,
                              size: 35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showChapterActions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Choose chapter'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChapterSelectionPage(book: widget.book),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.headphones),
              title: const Text('Open audio'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AudioPage(
                      initialBook: widget.book,
                      initialChapter: widget.chapter,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReaderSettings() {
    final app = AppScope.of(context);
    double currentSize = app.fontSize;
    double currentHeight = app.lineHeight;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: const Text('Reading Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Text size: ${currentSize.round()}'),
                  Slider(
                    min: 15,
                    max: 30,
                    divisions: 15,
                    value: currentSize,
                    onChanged: (value) {
                      setDialogState(() => currentSize = value);
                      app.setFontSize(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Line spacing: ${currentHeight.toStringAsFixed(1)}',
                  ),
                  Slider(
                    min: 1.2,
                    max: 2.2,
                    divisions: 10,
                    value: currentHeight,
                    onChanged: (value) {
                      setDialogState(() => currentHeight = value);
                      app.setLineHeight(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('DONE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================
// VERSE WIDGET
// ============================================================

class VerseWidget extends StatelessWidget {
  final BibleBook book;
  final int chapter;
  final BibleVerse verse;

  const VerseWidget({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
  });

  String get keyName => '${book.name}|$chapter|${verse.number}';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final highlighted = app.highlights.contains(keyName);

    return GestureDetector(
      onTap: () => _showVerseActions(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFF5D4C25).withOpacity(.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${verse.number} ',
                style: const TextStyle(
                  color: Color(0xFFD0A7FF),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: verse.text,
                style: TextStyle(
                  fontSize: app.fontSize,
                  height: app.lineHeight,
                  color: app.darkMode
                      ? const Color(0xFFE9E5EA)
                      : const Color(0xFF242024),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerseActions(BuildContext context) {
    final app = AppScope.of(context);

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                app.bookmarks.contains(keyName)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              title: Text(
                app.bookmarks.contains(keyName)
                    ? 'Remove bookmark'
                    : 'Bookmark verse',
              ),
              onTap: () {
                app.toggleBookmark(keyName);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                app.favorites.contains(keyName)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              title: Text(
                app.favorites.contains(keyName)
                    ? 'Remove favorite'
                    : 'Add favorite',
              ),
              onTap: () {
                app.toggleFavorite(keyName);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight),
              title: Text(
                app.highlights.contains(keyName)
                    ? 'Remove highlight'
                    : 'Highlight verse',
              ),
              onTap: () {
                app.toggleHighlight(keyName);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('Add / edit note'),
              onTap: () {
                Navigator.pop(context);
                _showNoteDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy verse'),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '${book.name} $chapter:${verse.number}\n${verse.text}',
                  ),
                );

                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verse copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context) {
    final app = AppScope.of(context);
    final controller = TextEditingController(
      text: app.notes[keyName] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${book.name} $chapter:${verse.number}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Write your note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              app.setNote(keyName, '');
              Navigator.pop(context);
            },
            child: const Text('DELETE'),
          ),
          ElevatedButton(
            onPressed: () {
              app.setNote(keyName, controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCH
// ============================================================

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  List<SearchResult> results = <SearchResult>[];
  bool searching = false;
  int currentBook = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => results = <SearchResult>[]);
      return;
    }

    setState(() {
      searching = true;
      results = <SearchResult>[];
      currentBook = 0;
    });

    final found = await BibleService.search(
      query,
      onProgress: (current, _) {
        if (mounted) {
          setState(() => currentBook = current);
        }
      },
    );

    if (!mounted) return;

    setState(() {
      results = found;
      searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Bible')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search Scripture...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    setState(() => results = <SearchResult>[]);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Searching book $currentBook of 66...'),
                ],
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      searching
                          ? 'Searching the complete Bible...'
                          : 'Search for a word or phrase.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final result = results[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${result.book} ${result.chapter}:${result.verse}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(result.text),
                          onTap: () {
                            final book = bibleBooks.firstWhere(
                              (b) => b.name == result.book,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BibleReaderPage(
                                  book: book,
                                  chapter: result.chapter,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SAVED
// ============================================================

enum SavedType {
  bookmarks,
  favorites,
  highlights,
  notes,
}

class SavedPage extends StatelessWidget {
  final SavedType type;

  const SavedPage({
    super.key,
    required this.type,
  });

  String get title {
    switch (type) {
      case SavedType.bookmarks:
        return 'Bookmarks';
      case SavedType.favorites:
        return 'Favorites';
      case SavedType.highlights:
        return 'Highlights';
      case SavedType.notes:
        return 'Notes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    final Iterable<String> source;
    switch (type) {
      case SavedType.bookmarks:
        source = app.bookmarks;
        break;
      case SavedType.favorites:
        source = app.favorites;
        break;
      case SavedType.highlights:
        source = app.highlights;
        break;
      case SavedType.notes:
        source = app.notes.keys;
        break;
    }

    final keys = source.toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: keys.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 65,
                  ),
                  const SizedBox(height: 15),
                  Text('No $title yet.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: keys.length,
              itemBuilder: (_, index) {
                final key = keys[index];
                final parts = key.split('|');

                if (parts.length != 3) {
                  return const SizedBox.shrink();
                }

                final bookName = parts[0];
                final chapter = int.tryParse(parts[1]) ?? 1;
                final verse = int.tryParse(parts[2]) ?? 1;

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.menu_book),
                    ),
                    title: Text(
                      '$bookName $chapter:$verse',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: app.notes[key] != null
                        ? Text(app.notes[key]!)
                        : const Text('Tap to open verse'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final book = bibleBooks.firstWhere(
                        (b) => b.name == bookName,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BibleReaderPage(
                            book: book,
                            chapter: chapter,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// SETTINGS
// ============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: app.darkMode,
              onChanged: app.setDarkMode,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Reading',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('Font size'),
                  subtitle: Text('${app.fontSize.round()}'),
                ),
                Slider(
                  min: 15,
                  max: 30,
                  divisions: 15,
                  value: app.fontSize,
                  onChanged: app.setFontSize,
                ),
                ListTile(
                  leading: const Icon(Icons.height),
                  title: const Text('Line spacing'),
                  subtitle:
                      Text(app.lineHeight.toStringAsFixed(1)),
                ),
                Slider(
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  value: app.lineHeight,
                  onChanged: app.setLineHeight,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Bible',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Card(
            child: const ListTile(
              leading: Icon(Icons.menu_book),
              title: Text('Translation'),
              subtitle: Text('King James Version (KJV)'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear saved data'),
              onTap: () => _confirmClear(context, app),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, AppState app) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear saved data?'),
        content: const Text(
          'This removes bookmarks, favorites, highlights and notes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              app.clearSavedData();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saved data cleared'),
                ),
              );
            },
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AUDIO
// ============================================================

class AudioPage extends StatelessWidget {
  final BibleBook? initialBook;
  final int? initialChapter;

  const AudioPage({
    super.key,
    this.initialBook,
    this.initialChapter,
  });

  Future<void> _openAudio(BuildContext context) async {
    final uri = Uri.parse(
      'https://publicdomainaudiobibles.com/KJV.html',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open KJV audio.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open KJV audio.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = initialBook != null && initialChapter != null
        ? '${initialBook!.name} ${initialChapter!}'
        : 'Listen to the Bible';

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Bible')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4D3670),
                  Color(0xFF241B30),
                ],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.headphones, size: 70),
                const SizedBox(height: 15),
                const Text(
                  'KJV Audio Bible',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('OPEN KJV AUDIO'),
                  onPressed: () => _openAudio(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Audio',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The complete KJV text is loaded by book and chapter. '
            'The audio button opens the KJV audio source in your browser.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MORE
// ============================================================

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _item(
            context,
            Icons.bookmark,
            'Bookmarks',
            SavedType.bookmarks,
          ),
          _item(
            context,
            Icons.favorite,
            'Favorites',
            SavedType.favorites,
          ),
          _item(
            context,
            Icons.highlight,
            'Highlights',
            SavedType.highlights,
          ),
          _item(
            context,
            Icons.note_alt,
            'My Notes',
            SavedType.notes,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Bible',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    'King James Version Bible',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    SavedType type,
  ) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SavedPage(type: type),
          ),
        );
      },
    );
  }
}