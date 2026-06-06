import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yaman/models/lesson.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/app_footer.dart';

class LessonManagement extends StatefulWidget {
  const LessonManagement({super.key});

  @override
  State<LessonManagement> createState() => _LessonManagementState();
}

class _LessonManagementState extends State<LessonManagement> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Lesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final lessons = await _supabase.loadLessons();
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الدروس: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', textDirection: TextDirection.rtl),
        content: Text('هل أنت متأكد من حذف درس "${lesson.title}"؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.deleteLesson(lesson.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الدرس بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
        }
      }
    }
  }

  Future<void> _downloadLesson(Lesson lesson) async {
    bool isDownloading = false;
    double downloadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!isDownloading) {
            isDownloading = true;
            _supabase.downloadVideo(
              lesson.link,
              '${lesson.title.replaceAll(' ', '_')}.mp4',
              (progress) => setDialogState(() => downloadProgress = progress),
            ).then((_) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الفيديو في الاستوديو بنجاح')));
            }).catchError((e) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التنزيل: $e')));
            });
          }

          return AlertDialog(
            title: const Text('جاري التنزيل...', textDirection: TextDirection.rtl),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: downloadProgress, color: regsin),
                const SizedBox(height: 10),
                Text('${(downloadProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addLessonDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final linkController = TextEditingController();
    File? selectedVideo;
    bool isUploading = false;
    double uploadProgress = 0.0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة درس جديد', textDirection: TextDirection.rtl),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'عنوان الدرس'),
                      enabled: !isUploading,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'وصف الدرس (اختياري)'),
                      enabled: !isUploading,
                    ),
                    const SizedBox(height: 15),
                    const Text('أو قم باختيار فيديو من الجهاز:', textDirection: TextDirection.rtl),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: isUploading
                          ? null
                          : () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.video,
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                setDialogState(() {
                                  selectedVideo = File(result.files.single.path!);
                                  linkController.clear();
                                });
                              }
                            },
                      icon: const Icon(Icons.video_library),
                      label: Text(selectedVideo != null
                          ? 'تم اختيار: ${selectedVideo!.path.split(Platform.pathSeparator).last}'
                          : 'اختيار فيديو'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedVideo != null ? Colors.green : regsin,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text('أو أدخل رابطاً يدوياً:', textDirection: TextDirection.rtl),
                    TextField(
                      controller: linkController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'الرابط (يوتيوب، الخ)'),
                      enabled: !isUploading && selectedVideo == null,
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: uploadProgress > 0 ? uploadProgress : null,
                        color: regsin,
                        backgroundColor: regsin.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        uploadProgress > 0 
                          ? 'جاري الرفع: ${(uploadProgress * 100).toInt()}%'
                          : 'جاري التحضير للرفع...',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (titleController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يجب إدخال عنوان الدرس')));
                            return;
                          }
                          if (linkController.text.isEmpty && selectedVideo == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يجب إدخال الرابط أو اختيار فيديو')));
                            return;
                          }

                          setDialogState(() {
                            isUploading = true;
                            uploadProgress = 0.05; // Starting
                          });

                          try {
                            String finalLink = linkController.text;
                            String? thumbnailUrl;

                            if (selectedVideo != null) {
                              final fileName = selectedVideo!.path.split(Platform.pathSeparator).last;
                              final uploadResults = await _supabase.uploadLessonVideoWithThumbnail(selectedVideo!, fileName);
                              
                              finalLink = uploadResults['videoUrl']!;
                              thumbnailUrl = uploadResults['thumbnailUrl'];
                              
                              setDialogState(() => uploadProgress = 1.0);
                              await Future.delayed(const Duration(milliseconds: 300));
                            }

                            final lesson = Lesson(
                              id: '', // Will be generated as UUID in service
                              title: titleController.text,
                              description: descController.text,
                              link: finalLink,
                              thumbnailUrl: thumbnailUrl,
                              createdAt: DateTime.now(),
                            );

                            await _supabase.addLesson(lesson);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم إضافة الدرس بنجاح')));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('خطأ: $e')));
                            }
                            setDialogState(() => isUploading = false);
                          }
                        },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة الدروس', style: TextStyle(color: Colors.white)),
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
                    hintText: 'بحث في الدروس...',
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
                child: StreamBuilder<List<Lesson>>(
                  stream: _supabase.subscribeToLessons(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    final allLessons = snapshot.data ?? [];
                    final lessons = allLessons.where((l) => 
                      l.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                      l.description.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();

                    if (lessons.isEmpty) {
                      return Center(child: Text(_searchQuery.isEmpty ? 'لا يوجد دروس مضافة بعد.' : 'لا توجد نتائج للبحث.', style: const TextStyle(color: Colors.white)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Column(
                              children: [
                                if (lesson.thumbnailUrl != null && lesson.thumbnailUrl!.isNotEmpty)
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.network(
                                        lesson.thumbnailUrl!,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Container(height: 150, color: Colors.black26, child: const Icon(Icons.broken_image, color: Colors.white54)),
                                      ),
                                      const Icon(Icons.play_circle_outline, color: Colors.white70, size: 50),
                                    ],
                                  )
                                else
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.black26,
                                    child: const Icon(Icons.video_library, color: Colors.white24, size: 50),
                                  ),
                                ListTile(
                                  title: Text(lesson.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (lesson.description.isNotEmpty) Text(lesson.description, style: const TextStyle(color: Colors.white70), textDirection: TextDirection.rtl),
                                      Text(lesson.link, style: const TextStyle(color: Colors.blueAccent, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.greenAccent, size: 20),
                                        onPressed: () => _downloadLesson(lesson),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteLesson(lesson),
                                      ),
                                    ],
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
                  onPressed: _addLessonDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة درس جديد'),
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
