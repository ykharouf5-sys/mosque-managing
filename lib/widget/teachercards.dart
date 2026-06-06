import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';

class CardTeacher extends StatelessWidget {
  const CardTeacher({
    super.key,
    required this.name,
    required this.number,
    required this.onpressed,
    this.onEdit,
    this.onDelete,
    this.studentCount,
  });
  
  final String name;
  final String number;
  final VoidCallback onpressed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int? studentCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isSmall = width < 350;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      textcolor.withOpacity(0.85),
                      textcolor.withOpacity(0.6),
                      regsin.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onpressed,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: isSmall ? 12 : 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildProfileIcon(isSmall),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoColumn(context, isSmall),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStudentCountBadge(isSmall),
                              _buildActionButtons(isSmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileIcon(bool isSmall) {
    return Container(
      width: isSmall ? 48 : 56,
      height: isSmall ? 48 : 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: isSmall ? 24 : 28,
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, bool isSmall) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmall ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone_rounded, color: Colors.white70, size: isSmall ? 14 : 16),
              const SizedBox(width: 6),
              Text(
                number,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmall ? 13 : 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCountBadge(bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: regsin.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: regsin.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded, color: Colors.white, size: isSmall ? 14 : 16),
          const SizedBox(width: 6),
          Text(
            "الطلاب: ${studentCount ?? 0}",
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isSmall) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.edit_rounded,
          color: Colors.blueAccent,
          onTap: onEdit,
          isSmall: isSmall,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.delete_outline_rounded,
          color: Colors.redAccent.shade100,
          onTap: onDelete,
          isSmall: isSmall,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isSmall,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 6 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(
            icon,
            color: color,
            size: isSmall ? 20 : 22,
          ),
        ),
      ),
    );
  }
}
