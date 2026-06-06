import 'package:flutter/material.dart';
import 'package:yaman/models/adhkar.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/app_footer.dart';

class AdhkarCategoriesScreen extends StatefulWidget {
  const AdhkarCategoriesScreen({super.key});

  @override
  State<AdhkarCategoriesScreen> createState() => _AdhkarCategoriesScreenState();
}

class _AdhkarCategoriesScreenState extends State<AdhkarCategoriesScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<AdhkarCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _supabase.loadAdhkarCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الأذكار والأحاديث', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Hidden for BubbleAppBar flow
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backcolor, textcolor.withValues(alpha: 0.8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<AdhkarCategory>>(
                  stream: _supabase.subscribeToAdhkarCategories(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    final categories = snapshot.data ?? [];
                    if (categories.isEmpty) {
                      return const Center(child: Text('لا يوجد أقسام متاحة.', style: TextStyle(color: Colors.white)));
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return _buildCategoryCard(cat);
                      },
                    );
                  },
                ),
              ),
              const AppFooter(),
              const SizedBox(height: 80), // Padding for BubbleAppBar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(AdhkarCategory category) {
    IconData iconData;
    Color iconColor;

    final title = category.title.toLowerCase();
    if (title.contains('صباح') || title.contains('morning')) {
      iconData = Icons.wb_sunny_rounded;
      iconColor = Colors.orangeAccent;
    } else if (title.contains('مساء') || title.contains('evening')) {
      iconData = Icons.nightlight_round;
      iconColor = Colors.blueAccent;
    } else if (title.contains('نوم') || title.contains('sleep')) {
      iconData = Icons.bedtime_rounded;
      iconColor = Colors.indigoAccent;
    } else if (title.contains('خلاء') || title.contains('bathroom') || title.contains('دخول')) {
      iconData = Icons.clean_hands_rounded;
      iconColor = Colors.cyanAccent;
    } else if (title.contains('طواف') || title.contains('tawaf') || title.contains('حج')) {
      iconData = Icons.mosque_rounded;
      iconColor = Colors.amberAccent;
    } else if (title.contains('صلاة') || title.contains('prayer')) {
      iconData = Icons.self_improvement_rounded;
      iconColor = Colors.greenAccent;
    } else {
      iconData = Icons.menu_book_rounded;
      iconColor = Colors.tealAccent;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DhikrListScreen(category: category)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 40, color: iconColor),
            const SizedBox(height: 12),
            Text(
              category.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (category.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  category.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DhikrListScreen extends StatefulWidget {
  final AdhkarCategory category;
  const DhikrListScreen({super.key, required this.category});

  @override
  State<DhikrListScreen> createState() => _DhikrListScreenState();
}

class _DhikrListScreenState extends State<DhikrListScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<Dhikr> _adhkar = [];
  Map<String, int> _counters = {};

  @override
  void initState() {
    super.initState();
    _loadAdhkar();
  }

  Future<void> _loadAdhkar() async {
    setState(() => _isLoading = true);
    try {
      final adhkar = await _supabase.loadAdhkarForCategory(widget.category.id);
      final initialCounters = {for (var item in adhkar) item.id: 0};
      setState(() {
        _adhkar = adhkar;
        _counters = initialCounters;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _incrementCounter(Dhikr item) {
    if (_counters[item.id]! < item.count) {
      setState(() {
        _counters[item.id] = _counters[item.id]! + 1;
      });
      // Optionally play a sound or vibration here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.category.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backcolor, textcolor.withValues(alpha: 0.8)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Dhikr>>(
            stream: _supabase.subscribeToAdhkarForCategory(widget.category.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
              }
              final adhkar = snapshot.data ?? [];
              if (adhkar.isEmpty) {
                return const Center(child: Text('هذا القسم فارغ حالياً.', style: TextStyle(color: Colors.white)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: adhkar.length,
                itemBuilder: (context, index) {
                  final item = adhkar[index];
                  // Initialize counter for new item if not exists
                  _counters.putIfAbsent(item.id, () => 0);
                  
                  final currentCount = _counters[item.id] ?? 0;
                  final isCompleted = currentCount >= item.count;

                  return InkWell(
                    onTap: isCompleted ? null : () => _incrementCounter(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCompleted ? Colors.greenAccent : Colors.white.withValues(alpha: 0.2),
                          width: isCompleted ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.text,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (item.virtue != null && item.virtue!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'الفضل: ${item.virtue}',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.source ?? '',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green : regsin,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isCompleted ? 'اكتمل' : '$currentCount / ${item.count}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
        ),
      ),
    );
  }
}
