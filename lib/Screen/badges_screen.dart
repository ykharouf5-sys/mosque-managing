import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/badge_service.dart';
import 'package:yaman/widget/variable.dart';

class BadgesScreen extends ConsumerWidget {
  final Student student;

  const BadgesScreen({required this.student, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedBadges = BadgeService.getUnlockedBadges(student);
    final nearbyBadges = BadgeService.getNearbyBadges(student);
    final lockedBadges = BadgeService.availableBadges
        .where((b) => !unlockedBadges.any((u) => u.id == b.id))
        .toList();

    final sw = MediaQuery.of(context).size.width;

    int gridCountForWidth(double width) {
      if (width < 420) return 2;
      if (width < 800) return 3;
      return 4;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: backcolor,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.amber[600],
                child: Center(
                  child: Text(
                    student.name.isNotEmpty ? student.name[0] : 'S',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏆 الأوسمة والإنجازات',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${unlockedBadges.length} مفتوحة',
                    style: const TextStyle(fontSize: 15,color: Colors.white),
                 ),
                  Text(
                    '${lockedBadges.length} مقفلة',
                    style: const TextStyle(fontSize: 15,color: Colors.white),
               ),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: '✨ المفتوحة'),
              Tab(text: '🎯 قريبة'),
              Tab(text: '🔒 مقفلة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // الأوسمة المفتوحة
            _buildBadgesGrid(
              unlockedBadges,
              isUnlocked: true,
              crossAxisCount: gridCountForWidth(sw),
            ),

            // الأوسمة القريبة
            _buildNearbyBadgesList(nearbyBadges),

            // الأوسمة المقفلة
            _buildBadgesGrid(
              lockedBadges,
              isUnlocked: false,
              crossAxisCount: gridCountForWidth(sw),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid(
    List<Badge> badges, {
    required bool isUnlocked,
    int crossAxisCount = 3,
  }) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isUnlocked
                  ? '🔒 لا توجد أوسمة مفتوحة بعد'
                  : '✨ جميع الأوسمة مفتوحة!',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold,color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              isUnlocked
                  ? 'استمر في الالتزام لفتح أوسمة جديدة'
                  : 'مبروك! أنت محقق استثنائي',
              style: TextStyle(fontSize: 25,color: Colors.white),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return _buildBadgeCard(badges[index], isUnlocked: isUnlocked);
      },
    );
  }

  Widget _buildBadgeCard(Badge badge, {required bool isUnlocked}) {
    return InkWell(
      onTap: () => _showBadgeDetails(null, badge),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked ? Colors.amber : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isUnlocked
                  ? Colors.amber[100]
                  : Colors.grey[200],
              child: Text(badge.icon, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 10),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isUnlocked ? Colors.black87 : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (!isUnlocked)
              Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyBadgesList(List<BadgeProgress> badges) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🎊 لا توجد أوسمة قريبة'),
            SizedBox(height: 8),
            Text('واصل الالتزام لفتح أوسمة جديدة'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return _buildNearbyBadgeCard(badges[index]);
      },
    );
  }

  Widget _buildNearbyBadgeCard(BadgeProgress badgeProgress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                badgeProgress.badge.icon,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badgeProgress.badge.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      badgeProgress.badge.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${badgeProgress.percentComplete}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: badgeProgress.progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(badgeProgress.progress),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${badgeProgress.current} / ${badgeProgress.required}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.75) return Colors.green;
    if (progress >= 0.5) return Colors.amber;
    return Colors.orange;
  }

  void _showBadgeDetails(BuildContext? context, Badge badge) {
    final dialogContext = context;
    if (dialogContext == null) {
      print('Cannot show badge details: context is null');
      return;
    }

    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Text(badge.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(badge.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏷️ '),
                  const SizedBox(width: 8),
                  Text(
                    _getCategoryName(badge.category),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'streak':
        return '🗓️ الالتزام والاستمرارية';
      case 'performance':
        return '📊 الأداء';
      case 'attendance':
        return '✅ الحضور';
      case 'special':
        return '⭐ خاص';
      default:
        return category;
    }
  }

  BuildContext? get scaffoldContext => null;
  BuildContext? get _defaultContext => null;
}
