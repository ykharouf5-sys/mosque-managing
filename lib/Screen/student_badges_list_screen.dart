import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/providers/students_provider.dart';
import 'package:yaman/services/badge_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/utils/responsive_helper.dart';

class StudentBadgesListScreen extends ConsumerWidget {
  const StudentBadgesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 أوسمة الطلاب'),
        backgroundColor: backcolor,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: backcolor,
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد بيانات طلاب',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // ترتيب الطلاب حسب عدد الأوسمة المفتوحة (الأعلى أولاً)
          final sortedStudents = List<Student>.from(students);
          sortedStudents.sort((a, b) {
            final badgesA = BadgeService.getUnlockedBadges(a).length;
            final badgesB = BadgeService.getUnlockedBadges(b).length;
            return badgesB.compareTo(badgesA); // ترتيب تنازلي
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sortedStudents.length,
            itemBuilder: (context, index) {
              final student = sortedStudents[index];
              final unlockedBadges = BadgeService.getUnlockedBadges(student);
              final nearbyBadges = BadgeService.getNearbyBadges(student);

              return _buildStudentBadgeCard(
                context,
                student,
                unlockedBadges,
                nearbyBadges,
                rankNumber: index + 1,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'خطأ: $error',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentBadgeCard(
    BuildContext context,
    Student student,
    List<Badge> unlockedBadges,
    List<BadgeProgress> nearbyBadges, {
    required int rankNumber,
  }) {
    final responsive = context.responsive;

    return Card(
      margin: EdgeInsets.symmetric(vertical: responsive.verticalSpace() / 2),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.borderRadius()),
        side: BorderSide(
          color: rankNumber == 1
              ? Colors.amber
              : rankNumber == 2
              ? Colors.grey[400]!
              : rankNumber == 3
              ? Colors.orange[700]!
              : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: Padding(
        padding: responsive.padding(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة: الترتيب والاسم
            Row(
              children: [
                // الرقم الترتيبي مع ميدالية
                Container(
                  width: responsive.fontSize(40),
                  height: responsive.fontSize(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rankNumber == 1
                        ? Colors.amber
                        : rankNumber == 2
                        ? Colors.grey[400]
                        : rankNumber == 3
                        ? Colors.orange[700]
                        : Colors.grey[700],
                  ),
                  child: Center(
                    child: Text(
                      '$rankNumber',
                      style: TextStyle(
                        fontSize: responsive.fontSize(18),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: responsive.horizontalSpace()),

                // الاسم والمعلم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: responsive.fontSize(16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'المعلم: ${student.teacherName}',
                        style: TextStyle(
                          fontSize: responsive.fontSize(12),
                          color: Colors.grey[400],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // عدد الأوسمة المفتوحة
                Column(
                  children: [
                    Text(
                      '${unlockedBadges.length}',
                      style: TextStyle(
                        fontSize: responsive.fontSize(24),
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      'وسام',
                      style: TextStyle(
                        fontSize: responsive.fontSize(12),
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: responsive.verticalSpace()),

            // الأوسمة المفتوحة
            if (unlockedBadges.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ الأوسمة المفتوحة (${unlockedBadges.length})',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  SizedBox(height: responsive.verticalSpace() / 2),
                  Wrap(
                    spacing: responsive.horizontalSpace() / 2,
                    runSpacing: responsive.verticalSpace() / 2,
                    children: unlockedBadges
                        .map(
                          (badge) => Tooltip(
                            message: badge.description,
                            child: Container(
                              padding: EdgeInsets.all(responsive.fontSize(6)),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(
                                  responsive.borderRadius() / 2,
                                ),
                              ),
                              child: Text(
                                badge.icon,
                                style: TextStyle(
                                  fontSize: responsive.fontSize(18),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: responsive.verticalSpace()),
                ],
              ),

            // الأوسمة القريبة
            if (nearbyBadges.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 الأوسمة القريبة (${nearbyBadges.length})',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan,
                    ),
                  ),
                  SizedBox(height: responsive.verticalSpace() / 2),
                  ...nearbyBadges
                      .take(3)
                      .map(
                        (badgeProgress) => Padding(
                          padding: EdgeInsets.only(
                            bottom: responsive.verticalSpace() / 2,
                          ),
                          child: Row(
                            children: [
                              Text(
                                badgeProgress.badge.icon,
                                style: TextStyle(
                                  fontSize: responsive.fontSize(16),
                                ),
                              ),
                              SizedBox(width: responsive.horizontalSpace() / 2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      badgeProgress.badge.name,
                                      style: TextStyle(
                                        fontSize: responsive.fontSize(12),
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 4,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: badgeProgress.progress,
                                          backgroundColor: Colors.grey[700],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                badgeProgress.progress >= 0.75
                                                    ? Colors.green
                                                    : badgeProgress.progress >=
                                                          0.5
                                                    ? Colors.amber
                                                    : Colors.orange,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: responsive.horizontalSpace() / 2),
                              Text(
                                '${badgeProgress.percentComplete}%',
                                style: TextStyle(
                                  fontSize: responsive.fontSize(11),
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
