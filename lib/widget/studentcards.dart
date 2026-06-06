import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';

class CardStudent extends StatelessWidget {
  const CardStudent({
    super.key,
    required this.name,
    required this.phone,
    required this.points,
    required this.teacherName,
    required this.onpressed,
    required this.onTransfer,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final String phone;
  final int points;
  final String teacherName;
  final VoidCallback onpressed;
  final VoidCallback onTransfer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                color: Colors.black.withOpacity(0.15),
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
                      textcolor.withOpacity(0.8),
                      textcolor.withOpacity(0.5),
                      Colors.blueAccent.withOpacity(0.2),
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
                                child: _buildInfoColumn(isSmall),
                              ),
                              _buildPointsBadge(isSmall),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               _buildTeacherInfo(isSmall),
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
      width: isSmall ? 44 : 50,
      height: isSmall ? 44 : 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(
        Icons.face_rounded,
        color: Colors.white,
        size: isSmall ? 22 : 26,
      ),
    );
  }

  Widget _buildInfoColumn(bool isSmall) {
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
              fontSize: isSmall ? 17 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone_iphone_rounded, color: Colors.white70, size: isSmall ? 13 : 15),
              const SizedBox(width: 4),
              Text(
                phone,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmall ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsBadge(bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: regsin.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "$points ن",
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmall ? 11 : 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTeacherInfo(bool isSmall) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, color: Colors.white60, size: isSmall ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            teacherName,
            style: TextStyle(
              color: Colors.white60,
              fontSize: isSmall ? 11 : 13,
              fontStyle: FontStyle.italic,
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
          icon: Icons.swap_horiz_rounded,
          color: Colors.amberAccent,
          onTap: onTransfer,
          isSmall: isSmall,
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          icon: Icons.edit_rounded,
          color: Colors.blueAccent,
          onTap: onEdit,
          isSmall: isSmall,
        ),
        const SizedBox(width: 6),
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
    required VoidCallback onTap,
    required bool isSmall,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 6 : 8),
          child: Icon(
            icon,
            color: color,
            size: isSmall ? 18 : 20,
          ),
        ),
      ),
    );
  }
}
