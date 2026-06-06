import 'package:flutter/material.dart';
import 'package:yaman/models/adhkar.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/app_footer.dart';

class AdhkarManagement extends StatefulWidget {
  const AdhkarManagement({super.key});

  @override
  State<AdhkarManagement> createState() => _AdhkarManagementState();
}

class _AdhkarManagementState extends State<AdhkarManagement> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات الأذكار: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategoryDialog({AdhkarCategory? existingCategory}) async {
    final titleController = TextEditingController(text: existingCategory?.title);
    final descController = TextEditingController(text: existingCategory?.description);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingCategory == null ? 'إضافة قسم جديد' : 'تعديل القسم', textDirection: TextDirection.rtl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'اسم القسم (مثال: أذكار الصباح)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                
                final category = AdhkarCategory(
                  id: existingCategory?.id ?? '',
                  title: titleController.text,
                  description: descController.text,
                  createdAt: existingCategory?.createdAt ?? DateTime.now(),
                );

                Navigator.pop(context);
                try {
                  await _supabase.addAdhkarCategory(category);
                  if(mounted){
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existingCategory == null ? 'تم إضافة القسم بنجاح' : 'تم تعديل القسم بنجاح')));
                  }
                } catch (e) {
                  if(mounted){
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              child: Text(existingCategory == null ? 'إضافة' : 'حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(AdhkarCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text('هل أنت متأكد من حذف قسم "${category.title}"؟ سيؤدي ذلك لحذف جميع الأذكار بداخله.', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.deleteAdhkarCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف القسم بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
    }
  }

  Future<void> _manageCategory(AdhkarCategory category) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DhikrListManagement(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة الأذكار والأحاديث', style: TextStyle(color: Colors.white)),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'بحث في الأقسام...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
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
                    final allCategories = snapshot.data ?? [];
                    final categories = allCategories.where((c) => 
                      c.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                      c.description.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();

                    if (categories.isEmpty) {
                      return Center(child: Text(_searchQuery.isEmpty ? 'لا يوجد أقسام مضافة بعد.' : 'لا توجد نتائج للبحث.', style: const TextStyle(color: Colors.white)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(cat.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
                            subtitle: Text(cat.description, style: const TextStyle(color: Colors.white70), textDirection: TextDirection.rtl),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  onPressed: () => _addCategoryDialog(existingCategory: cat),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteCategory(cat),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                            onTap: () => _manageCategory(cat),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _addCategoryDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة قسم جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: regsin,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              const AppFooter(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class DhikrListManagement extends StatefulWidget {
  final AdhkarCategory category;
  const DhikrListManagement({super.key, required this.category});

  @override
  State<DhikrListManagement> createState() => _DhikrListManagementState();
}

class _DhikrListManagementState extends State<DhikrListManagement> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Dhikr> _adhkar = [];

  @override
  void initState() {
    super.initState();
    _loadAdhkar();
  }

  Future<void> _loadAdhkar() async {
    setState(() => _isLoading = true);
    try {
      final adhkar = await _supabase.loadAdhkarForCategory(widget.category.id);
      setState(() {
        _adhkar = adhkar;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحميل: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addDhikrDialog({Dhikr? existingDhikr}) async {
    final textController = TextEditingController(text: existingDhikr?.text);
    final sourceController = TextEditingController(text: existingDhikr?.source);
    final virtueController = TextEditingController(text: existingDhikr?.virtue);
    int count = existingDhikr?.count ?? 1;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(existingDhikr == null ? 'إضافة ذكر/حديث' : 'تعديل المحتوى', textDirection: TextDirection.rtl),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: textController,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'النص'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: virtueController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'الفضل (اختياري)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sourceController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'المصدر (اختياري)'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                if (count > 1) setStateDialog(() => count--);
                              },
                            ),
                            Text('$count', style: const TextStyle(fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setStateDialog(() => count++),
                            ),
                          ],
                        ),
                        const Text(':عدد المرات', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (textController.text.isEmpty) return;

                    final dhikr = Dhikr(
                      id: existingDhikr?.id ?? '',
                      categoryId: widget.category.id,
                      text: textController.text,
                      source: sourceController.text.isEmpty ? null : sourceController.text,
                      virtue: virtueController.text.isEmpty ? null : virtueController.text,
                      count: count,
                      createdAt: existingDhikr?.createdAt ?? DateTime.now(),
                    );

                    Navigator.pop(context);
                    try {
                      await _supabase.addDhikr(dhikr);
                      if(mounted){
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existingDhikr == null ? 'تم الإضافة بنجاح' : 'تم التعديل بنجاح')));
                      }
                    } catch (e) {
                      if(mounted){
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                  child: Text(existingDhikr == null ? 'إضافة' : 'حفظ'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _deleteDhikr(Dhikr dhikr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: const Text('هل أنت متأكد من حذف هذا المحتوى؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.deleteDhikr(dhikr.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'بحث في المحتوى...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Dhikr>>(
                  stream: _supabase.subscribeToAdhkarForCategory(widget.category.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    final allAdhkar = snapshot.data ?? [];
                    final adhkar = allAdhkar.where((a) => 
                      a.text.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                      (a.virtue?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                      (a.source?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
                    ).toList();

                    if (adhkar.isEmpty) {
                      return Center(child: Text(_searchQuery.isEmpty ? 'لا يوجد محتوى مضاف.' : 'لا توجد نتائج للبحث.', style: const TextStyle(color: Colors.white)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: adhkar.length,
                      itemBuilder: (context, index) {
                        final item = adhkar[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                          onPressed: () => _addDhikrDialog(existingDhikr: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteDhikr(item),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.menu_book, color: Colors.white54, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                ),
                                if (item.virtue != null) ...[
                                  const SizedBox(height: 8),
                                  Text('فضله: ${item.virtue}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14), textDirection: TextDirection.rtl),
                                ],
                                if (item.source != null) ...[
                                  const SizedBox(height: 8),
                                  Text('المصدر: ${item.source}', style: const TextStyle(color: Colors.white70, fontSize: 12), textDirection: TextDirection.rtl),
                                ],
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: regsin,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('${item.count} مرات', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _addDhikrDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة محتوى للقسم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: regsin,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
