import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorganPdfProApp());
}

class MorganPdfProApp extends StatefulWidget {
  const MorganPdfProApp({super.key});

  @override
  State<MorganPdfProApp> createState() => _MorganPdfProAppState();
}

class _MorganPdfProAppState extends State<MorganPdfProApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.blue.shade800;
  bool _isArabic = true;
  String? _savedPin;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final t = prefs.getString('theme_mode') ?? 'system';
      _themeMode = t == 'dark' ? ThemeMode.dark : (t == 'light' ? ThemeMode.light : ThemeMode.system);
      _seedColor = Color(prefs.getInt('theme_color') ?? Colors.blue.shade800.value);
      _isArabic = prefs.getBool('is_arabic') ?? true;
      _savedPin = prefs.getString('app_pin');
      if (_savedPin == null || _savedPin!.isEmpty) _isUnlocked = true;
    });
  }

  void _updateSettings({ThemeMode? mode, Color? color, bool? arabic, String? pin}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (mode != null) {
        _themeMode = mode;
        prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
      }
      if (color != null) {
        _seedColor = color;
        prefs.setInt('theme_color', color.value);
      }
      if (arabic != null) {
        _isArabic = arabic;
        prefs.setBool('is_arabic', arabic);
      }
      if (pin != null) {
        _savedPin = pin.isEmpty ? null : pin;
        prefs.setString('app_pin', pin);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morgan PDF Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(colorSchemeSeed: _seedColor, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seedColor, useMaterial3: true, brightness: Brightness.dark),
      builder: (context, child) {
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: _isUnlocked
              ? child!
              : Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
                          const SizedBox(height: 16),
                          const Text('أدخل الرقم السري لفتح Morgan PDF', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextField(
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'PIN'),
                            onSubmitted: (val) {
                              if (val == _savedPin) setState(() => _isUnlocked = true);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
      home: MainWorkspace(
        isArabic: _isArabic,
        themeMode: _themeMode,
        onUpdateSettings: _updateSettings,
      ),
    );
  }
}

class MorganLogo extends StatelessWidget {
  final double size;
  const MorganLogo({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: size * 0.85, color: Colors.blue.shade800),
          Positioned(
            right: size * 0.06,
            bottom: size * 0.06,
            child: Container(
              padding: EdgeInsets.all(size * 0.07),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.shade700, width: 3),
                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
              ),
              child: Text(
                'PDF',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.17, color: Colors.blue.shade900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainWorkspace extends StatefulWidget {
  final bool isArabic;
  final ThemeMode themeMode;
  final Function({ThemeMode? mode, Color? color, bool? arabic, String? pin}) onUpdateSettings;

  const MainWorkspace({
    super.key,
    required this.isArabic,
    required this.themeMode,
    required this.onUpdateSettings,
  });

  @override
  State<MainWorkspace> createState() => _MainWorkspaceState();
}

class _MainWorkspaceState extends State<MainWorkspace> {
  int _navIndex = 0;
  List<String> _recentFiles = [];
  List<String> _favFiles = [];
  Map<String, String> _fileTags = {};
  List<String> _openTabs = [];
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentFiles = prefs.getStringList('recent_files') ?? [];
      _favFiles = prefs.getStringList('fav_files') ?? [];
      final tags = prefs.getStringList('file_tags') ?? [];
      _fileTags = {
        for (var t in tags)
          if (t.contains('||')) t.split('||')[0]: t.split('||')[1]
      };
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
    await prefs.setStringList('fav_files', _favFiles);
    await prefs.setStringList('file_tags', _fileTags.entries.map((e) => '${e.key}||${e.value}').toList());
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      _openPdfFile(result.files.single.path!);
    }
  }

  void _openPdfFile(String path) {
    if (!File(path).existsSync()) return;
    setState(() {
      _recentFiles.remove(path);
      _recentFiles.insert(0, path);
      if (!_openTabs.contains(path)) _openTabs.add(path);
      _activeTab = _openTabs.indexOf(path);
      _navIndex = 1;
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildFilesTab(),
      _buildReaderTabsView(),
      _buildSettingsTab(),
    ];

    return Scaffold(
      body: pages[_navIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'الملفات والمجلدات'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _openTabs.isNotEmpty,
              label: Text('${_openTabs.length}'),
              child: const Icon(Icons.menu_book_rounded),
            ),
            label: 'القارئ والتبويبات',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات والحماية'),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              MorganLogo(size: 36),
              SizedBox(width: 10),
              Text('Morgan PDF Pro', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الأخيرة', icon: Icon(Icons.history)),
              Tab(text: 'المفضلة ⭐', icon: Icon(Icons.star_outline)),
              Tab(text: 'المجلدات 📁', icon: Icon(Icons.folder_special_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFileListView(_recentFiles),
            _buildFileListView(_favFiles),
            _buildFoldersView(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _pickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('فتح ملف PDF'),
        ),
      ),
    );
  }

  Widget _buildFileListView(List<String> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MorganLogo(size: 95),
            const SizedBox(height: 12),
            const Text('لا توجد ملفات هنا بعد، افتح ملفاً للبدء'),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.add), label: const Text('اختيار ملف من الجهاز')),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final path = list[i];
        final name = path.split('/').last;
        final isFav = _favFiles.contains(path);
        final folder = _fileTags[path];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf, color: Colors.blue.shade800, size: 34),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (c, s) {
                final p = s.data?.getInt('page_$path') ?? 1;
                return Text('متوقف عند صفحة: $p ${folder != null ? " • 📁 $folder" : ""}');
              },
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'fav') {
                  setState(() => isFav ? _favFiles.remove(path) : _favFiles.add(path));
                  _saveData();
                } else if (v == 'tag') {
                  _setFolderDialog(path);
                } else if (v == 'share') {
                  Share.shareXFiles([XFile(path)]);
                } else if (v == 'del') {
                  setState(() {
                    _recentFiles.remove(path);
                    _favFiles.remove(path);
                  });
                  _saveData();
                }
              },
              itemBuilder: (c) => [
                PopupMenuItem(value: 'fav', child: Text(isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة ⭐')),
                const PopupMenuItem(value: 'tag', child: Text('تعيين مجلد المادة 📁')),
                const PopupMenuItem(value: 'share', child: Text('مشاركة / طباعة (NokoPrint) 🖨️')),
                const PopupMenuItem(value: 'del', child: Text('حذف من القائمة 🗑️')),
              ],
            ),
            onTap: () => _openPdfFile(path),
          ),
        );
      },
    );
  }

  Widget _buildFoldersView() {
    if (_fileTags.isEmpty) {
      return const Center(child: Text('اضغط على النقاط الثلاث بجانب أي ملف لإضافته لمجلد (مثل: جراحة، أطفال، نسا)'));
    }
    final folders = _fileTags.values.toSet().toList();
    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (ctx, i) {
        final fName = folders[i];
        final paths = _fileTags.entries.where((e) => e.value == fName).map((e) => e.key).toList();
        return ExpansionTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(fName, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: paths.map((p) => ListTile(
            title: Text(p.split('/').last),
            onTap: () => _openPdfFile(p),
          )).toList(),
        );
      },
    );
  }

  void _setFolderDialog(String path) {
    final ctrl = TextEditingController(text: _fileTags[path] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم مجلد المادة'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'مثال: جراحة، أطفال، باطنة...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (ctrl.text.trim().isEmpty) {
                  _fileTags.remove(path);
                } else {
                  _fileTags[path] = ctrl.text.trim();
                }
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderTabsView() {
    if (_openTabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('القارئ السلس')),
        body: Center(
          child: ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open), label: const Text('افتح ملف PDF للمذاكرة')),
        ),
      );
    }
    if (_activeTab >= _openTabs.length) _activeTab = 0;
    final currentPath = _openTabs[_activeTab];

    return SafeArea(
      child: Column(
        children: [
          Container(
            height: 42,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _openTabs.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _openTabs.length) {
                  return IconButton(icon: const Icon(Icons.add), onPressed: _pickFile);
                }
                final selected = i == _activeTab;
                final title = _openTabs[i].split('/').last;
                return GestureDetector(
                  onTap: () => setState(() => _activeTab = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(title.length > 16 ? '${title.substring(0, 16)}...' : title, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _openTabs.removeAt(i)),
                          child: const Icon(Icons.close, size: 15),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: AdvancedPdfViewer(
              key: ValueKey(currentPath),
              filePath: currentPath,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والتخصيص والحماية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: MorganLogo(size: 50),
            title: Text('Morgan PDF Pro v2.0', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('يعمل بدون إنترنت 100% - مصمم للمذاكرة السلسة'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('مظهر التطبيق'),
            trailing: DropdownButton<ThemeMode>(
              value: widget.themeMode,
              onChanged: (m) => widget.onUpdateSettings(mode: m),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('تلقائي')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('فاتح')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('داكن')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('لون التطبيق الرئيسي'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Colors.blue.shade800, Colors.teal, Colors.indigo, Colors.deepOrange].map((c) => GestureDetector(
                onTap: () => widget.onUpdateSettings(color: c),
                child: Container(margin: const EdgeInsets.all(4), width: 24, height: 24, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              )).toList(),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.language),
            title: const Text('واجهة عربية (RTL)'),
            value: widget.isArabic,
            onChanged: (v) => widget.onUpdateSettings(arabic: v),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('قفل التطبيق برقم سري (PIN)'),
            onTap: () {
              final ctrl = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تعيين رقم سري (اتركه فارغاً للإلغاء)'),
                  content: TextField(controller: ctrl, keyboardType: TextInputType.number),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                    ElevatedButton(
                      onPressed: () {
                        widget.onUpdateSettings(pin: ctrl.text.trim());
                        Navigator.pop(ctx);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  DrawStroke(this.points, this.color, this.width);
}

class AdvancedPdfViewer extends StatefulWidget {
  final String filePath;
  const AdvancedPdfViewer({super.key, required this.filePath});

  @override
  State<AdvancedPdfViewer> createState() => _AdvancedPdfViewerState();
}

class _AdvancedPdfViewerState extends State<AdvancedPdfViewer> {
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  late PdfViewerController _controller;
  final FlutterTts _tts = FlutterTts();

  bool _invertColors = false;
  double _dimOverlay = 0.0;
  bool _isHorizontal = false;
  bool _isSinglePage = false;
  bool _isFullScreen = false;
  int _rotation = 0;

  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  bool _drawingMode = false;
  Color _penColor = Colors.amber.withOpacity(0.45);
  double _penWidth = 14.0;
  final Map<int, List<DrawStroke>> _strokesByPage = {};
  final List<DrawStroke> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    WakelockPlus.enable();
    _restoreLastPage();
  }

  Future<void> _restoreLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getInt('page_${widget.filePath}') ?? 1;
    final z = prefs.getDouble('zoom_${widget.filePath}') ?? 1.0;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.jumpToPage(p);
        _controller.zoomLevel = z;
      }
    });
  }

  Future<void> _savePage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('page_${widget.filePath}', page);
    await prefs.setDouble('zoom_${widget.filePath}', _controller.zoomLevel);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ColorFilter invertMatrix = ColorFilter.matrix(<double>[
      -1,  0,  0, 0, 255,
       0, -1,  0, 0, 255,
       0,  0, -1, 0, 255,
       0,  0,  0, 1,   0,
    ]);

    final curPage = _controller.pageNumber > 0 ? _controller.pageNumber : 1;
    final currentStrokes = _strokesByPage[curPage] ?? [];

    Widget pdfWidget = RotatedBox(
      quarterTurns: _rotation,
      child: Stack(
        children: [
          SfPdfViewer.file(
            File(widget.filePath),
            key: _pdfKey,
            controller: _controller,
            pageLayoutMode: _isSinglePage ? PdfPageLayoutMode.single : PdfPageLayoutMode.continuous,
            scrollDirection: _isHorizontal ? PdfScrollDirection.horizontal : PdfScrollDirection.vertical,
            enableDoubleTapZooming: true,
            maxZoomLevel: 5.0,
            pageSpacing: 2.0,
            onPageChanged: (d) {
              setState(() {});
              _savePage(d.newPageNumber);
            },
          ),
          if (_drawingMode || currentStrokes.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_drawingMode,
                child: GestureDetector(
                  onPanStart: (d) {
                    setState(() {
                      _strokesByPage.putIfAbsent(curPage, () => []);
                      _strokesByPage[curPage]!.add(DrawStroke([d.localPosition], _penColor, _penWidth));
                    });
                  },
                  onPanUpdate: (d) {
                    setState(() {
                      _strokesByPage[curPage]!.last.points.add(d.localPosition);
                    });
                  },
                  child: CustomPaint(painter: StrokePainter(currentStrokes)),
                ),
              ),
            ),
          if (_dimOverlay > 0)
            IgnorePointer(child: Container(color: Colors.black.withOpacity(_dimOverlay))),
        ],
      ),
    );

    if (_invertColors) {
      pdfWidget = ColorFiltered(colorFilter: invertMatrix, child: pdfWidget);
    }

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              toolbarHeight: 46,
              title: _showSearch
                  ? TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'ابحث في النص...', border: InputBorder.none),
                      onSubmitted: (v) => setState(() => _searchResult = _controller.searchText(v)),
                    )
                  : Text('${_controller.pageNumber} / ${_controller.pageCount}', style: const TextStyle(fontSize: 14)),
              actions: [
                if (_showSearch) ...[
                  IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => _searchResult.previousInstance()),
                  IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => _searchResult.nextInstance()),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _showSearch = false;
                      _searchResult.clear();
                    }),
                  ),
                ] else ...[
                  IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _showSearch = true)),
                  IconButton(
                    icon: Icon(_drawingMode ? Icons.check_circle : Icons.draw_outlined, color: _drawingMode ? Colors.green : null),
                    tooltip: 'القلم والتظليل والتوقيع',
                    onPressed: _openDrawToolsSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_90_degrees_ccw),
                    onPressed: () => setState(() => _rotation = (_rotation + 1) % 4),
                  ),
                  IconButton(
                    icon: Icon(_invertColors ? Icons.light_mode : Icons.dark_mode),
                    onPressed: _openNightAndBrightnessDialog,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'toc') _pdfKey.currentState?.openBookmarkView();
                      if (v == 'jump') _jumpDialog();
                      if (v == 'single') setState(() => _isSinglePage = !_isSinglePage);
                      if (v == 'dir') setState(() => _isHorizontal = !_isHorizontal);
                      if (v == 'crop') _controller.zoomLevel = _controller.zoomLevel > 1.1 ? 1.0 : 1.35;
                      if (v == 'full') setState(() => _isFullScreen = true);
                      if (v == 'note') _pageNoteDialog();
                      if (v == 'save') {
                        final bytes = await _controller.saveDocument();
                        await File(widget.filePath).writeAsBytes(bytes);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات على الملف!')));
                      }
                      if (v == 'print') Share.shareXFiles([XFile(widget.filePath)]);
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(value: 'toc', child: Text('الفهرس (Bookmarks) 📑')),
                      const PopupMenuItem(value: 'jump', child: Text('انتقال لرقم صفحة 🔢')),
                      PopupMenuItem(value: 'single', child: Text(_isSinglePage ? 'تمرير مستمر ناعم (Smooth)' : 'صفحة بصفحة')),
                      PopupMenuItem(value: 'dir', child: Text(_isHorizontal ? 'تمرير رأسي' : 'تمرير أفقي')),
                      const PopupMenuItem(value: 'crop', child: Text('تكبير الهوامش تلقائياً 🔍')),
                      const PopupMenuItem(value: 'full', child: Text('وضع ملء الشاشة ⛶')),
                      const PopupMenuItem(value: 'note', child: Text('ملاحظات لاصقة وقراءة صوتية 🔊')),
                      const PopupMenuItem(value: 'save', child: Text('حفظ التظليل والنماذج 💾')),
                      const PopupMenuItem(value: 'print', child: Text('طباعة / مشاركة 🖨️')),
                    ],
                  ),
                ],
              ],
            ),
      body: pdfWidget,
      floatingActionButton: _isFullScreen
          ? FloatingActionButton.small(onPressed: () => setState(() => _isFullScreen = false), child: const Icon(Icons.fullscreen_exit))
          : (_drawingMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'u1',
                      onPressed: () {
                        final list = _strokesByPage[curPage];
                        if (list != null && list.isNotEmpty) setState(() => _redoStack.add(list.removeLast()));
                      },
                      child: const Icon(Icons.undo),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'r1',
                      onPressed: () {
                        if (_redoStack.isNotEmpty) {
                          setState(() {
                            _strokesByPage.putIfAbsent(curPage, () => []);
                            _strokesByPage[curPage]!.add(_redoStack.removeLast());
                          });
                        }
                      },
                      child: const Icon(Icons.redo),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'done1',
                      backgroundColor: Colors.green,
                      onPressed: () => setState(() => _drawingMode = false),
                      child: const Icon(Icons.check),
                    ),
                  ],
                )
              : null),
    );
  }

  void _openDrawToolsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(
              avatar: const Icon(Icons.highlight, color: Colors.amber),
              label: const Text('قلم تظليل (Highlight)'),
              onPressed: () {
                setState(() {
                  _drawingMode = true;
                  _penColor = Colors.yellow.withOpacity(0.4);
                  _penWidth = 18.0;
                });
                Navigator.pop(ctx);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.edit, color: Colors.blue),
              label: const Text('قلم حر / تخطيط (Pen)'),
              onPressed: () {
                setState(() {
                  _drawingMode = true;
                  _penColor = Colors.blue.shade800;
                  _penWidth = 3.5;
                });
                Navigator.pop(ctx);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.draw, color: Colors.indigo),
              label: const Text('توقيع بخط اليد ✍️'),
              onPressed: () {
                setState(() {
                  _drawingMode = true;
                  _penColor = Colors.indigo.shade900;
                  _penWidth = 2.5;
                });
                Navigator.pop(ctx);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.visibility_off, color: Colors.black),
              label: const Text('إخفاء معلومات (Redaction)'),
              onPressed: () {
                setState(() {
                  _drawingMode = true;
                  _penColor = Colors.black;
                  _penWidth = 22.0;
                });
                Navigator.pop(ctx);
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text('مسح رسومات الصفحة (ممحاة)'),
              onPressed: () {
                setState(() {
                  _strokesByPage[_controller.pageNumber]?.clear();
                  _drawingMode = false;
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openNightAndBrightnessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('الوضع الليلي والسطوع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('عكس ألوان الصفحات للأسود'),
                value: _invertColors,
                onChanged: (v) {
                  setState(() => _invertColors = v);
                  setSt(() {});
                },
              ),
              const Text('تعتيم الشاشة لراحة العين:'),
              Slider(
                value: _dimOverlay,
                min: 0.0,
                max: 0.75,
                onChanged: (v) {
                  setState(() => _dimOverlay = v);
                  setSt(() {});
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم'))],
        ),
      ),
    );
  }

  void _jumpDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('انتقال لصفحة (1 - ${_controller.pageCount})'),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null) _controller.jumpToPage(p);
              Navigator.pop(ctx);
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  void _pageNoteDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'note_${widget.filePath}_${_controller.pageNumber}';
    final ctrl = TextEditingController(text: prefs.getString(key) ?? '');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ملاحظات وأختام صفحة ${_controller.pageNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب ملاحظتك أو نصاً لقراءته صوتياً...')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['مهم للامتحان ✅', 'مراجعة 📌', 'سؤال متوقع ⭐'].map((s) => ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                onPressed: () => ctrl.text = '${ctrl.text} [$s]',
              )).toList(),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue), onPressed: () => _tts.speak(ctrl.text)),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString(key, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class StrokePainter extends CustomPainter {
  final List<DrawStroke> strokes;
  StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
