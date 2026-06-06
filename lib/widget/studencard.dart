import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';

class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.names,
    required this.numbers,
    required this.onpressed,
    this.onEdit,
    this.onDelete,
    this.studentCounth,
  });

  final String names;
  final String numbers;
  final VoidCallback onpressed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int? studentCounth;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: textcolor.withOpacity(0.5), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onpressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.lightBlue.withAlpha(40),
          highlightColor: Colors.lightBlue.withAlpha(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  textcolor.withOpacity(0.9),
                  const Color.fromARGB(255, 45, 75, 65)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                  child: Text(
                    names.isNotEmpty ? names[0] : 'S',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "رقم الموبايل: $numbers",
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      if (studentCounth != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.amberAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "حضور: $studentCounth أيام",
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      if (onEdit != null)
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
