import 'package:flutter/material.dart';
import 'package:yaman/models/lesson.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaman/widget/app_footer.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final SupabaseService _supabase = SupabaseService();
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
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحميل: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط. الرجاء التأكد من صحته.')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الدروس', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                child: StreamBuilder<List<Lesson>>(
                  stream: _supabase.subscribeToLessons(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    }
                    final lessons = snapshot.data ?? [];
                    if (lessons.isEmpty) {
                      return const Center(child: Text('لا يوجد دروس متاحة.', style: TextStyle(color: Colors.white)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: () => _launchURL(lesson.link),
                              child: Column(
                                children: [
                                  if (lesson.thumbnailUrl != null && lesson.thumbnailUrl!.isNotEmpty)
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.network(
                                          lesson.thumbnailUrl!,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(height: 180, color: Colors.black26, child: const Icon(Icons.broken_image, color: Colors.white54)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: Colors.black26,
                                      child: const Icon(Icons.video_library, color: Colors.white24, size: 50),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                                          onPressed: () => _downloadLesson(lesson),
                                          tooltip: 'تنزيل الفيديو',
                                        ),
                                        const Spacer(),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                lesson.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textDirection: TextDirection.rtl,
                                              ),
                                              if (lesson.description.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  lesson.description,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                    fontSize: 14,
                                                  ),
                                                  textDirection: TextDirection.rtl,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
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
}
