// import 'package:flutter/material.dart';
// import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
// import 'package:yaman/models/student.dart';
// import 'package:yaman/services/storage_service.dart';
// import 'package:yaman/widget/variable.dart';
// import 'dart:math' as math;

// class LeaderboardScreen extends StatefulWidget {
//   final String currentStudentId;

//   const LeaderboardScreen({super.key, required this.currentStudentId});

//   @override
//   State<LeaderboardScreen> createState() => _LeaderboardScreenState();
// }

// class _LeaderboardScreenState extends State<LeaderboardScreen> {
//   final StorageService _storage = StorageService();
//   late Future<List<Student>> _studentsFuture;

//   @override
//   void initState() {
//     super.initState();
//     _studentsFuture = _loadAndSortStudents();
//   }

//   Future<List<Student>> _loadAndSortStudents() async {
//     final students = await _storage.loadStudents();
//     // Sort students by points in descending order
//     students.sort((a, b) => b.points.compareTo(a.points));
//     return students;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backcolor,
//       appBar: AppBar(
//         title: const Text(
//           'لوحة الصدارة',
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: backcolor,
//         centerTitle: true,
//         elevation: 0,
//       ),
//       body: FutureBuilder<List<Student>>(
//         future: _studentsFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator(color: regsin));
//           }

//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//               child: Text(
//                 'لا يوجد طلاب لعرضهم',
//                 style: TextStyle(color: Colors.white70, fontSize: 18),
//               ),
//             );
//           }

//           final students = snapshot.data!;
//           final topThree = students.take(3).toList();
//           final rest = students.length > 3 ? students.sublist(3) : <Student>[];

//           // Find current user's rank
//           final currentUserRank =
//               students.indexWhere((s) => s.id == widget.currentStudentId) + 1;
//           final currentUser = currentUserRank > 0
//               ? students[currentUserRank - 1]
//               : null;

//           return Stack(
//             children: [
//               CustomScrollView(
//                 slivers: [
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 20.0),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           if (topThree.length > 1)
//                             _TopPlayerCard(student: topThree[1], rank: 2),
//                           if (topThree.isNotEmpty)
//                             _TopPlayerCard(student: topThree[0], rank: 1),
//                           if (topThree.length > 2)
//                             _TopPlayerCard(student: topThree[2], rank: 3),
//                         ],
//                       ),
//                     ),
//                   ),
//                   SliverList(
//                     delegate: SliverChildBuilderDelegate((context, index) {
//                       final student = rest[index];
//                       final rank = index + 4;
//                       return AnimationConfiguration.staggeredList(
//                         position: index,
//                         duration: const Duration(milliseconds: 375),
//                         child: SlideAnimation(
//                           verticalOffset: 50.0,
//                           child: FadeInAnimation(
//                             child: _PlayerTile(
//                               student: student,
//                               rank: rank,
//                               isCurrentUser:
//                                   student.id == widget.currentStudentId,
//                             ),
//                           ),
//                         ),
//                       );
//                     }, childCount: rest.length),
//                   ),
//                   const SliverToBoxAdapter(child: SizedBox(height: 100)),
//                 ],
//               ),
//               if (currentUser != null)
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   right: 0,
//                   child: _CurrentUserBanner(
//                     student: currentUser,
//                     rank: currentUserRank,
//                   ),
//                 ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }

// class _TopPlayerCard extends StatelessWidget {
//   final Student student;
//   final int rank;

//   const _TopPlayerCard({required this.student, required this.rank});

//   @override
//   Widget build(BuildContext context) {
//     final colors = [
//       Colors.amber, // 1st
//       Colors.grey.shade400, // 2nd
//       const Color(0xFFCD7F32), // 3rd
//     ];
//     final double height = rank == 1 ? 150 : 130;

//     return Container(
//       width: 110,
//       height: height,
//       margin: const EdgeInsets.symmetric(horizontal: 4),
//       decoration: BoxDecoration(
//         color: textcolor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: colors[rank - 1], width: 2.5),
//         boxShadow: [
//           BoxShadow(
//             color: colors[rank - 1].withOpacity(0.5),
//             blurRadius: 12,
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (rank == 1) Text('👑', style: TextStyle(fontSize: 24)),
//           CircleAvatar(
//             radius: rank == 1 ? 28 : 24,
//             backgroundColor: colors[rank - 1].withOpacity(0.3),
//             child: Text(
//               student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
//               style: TextStyle(
//                 fontSize: rank == 1 ? 24 : 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             student.name,
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//           Text(
//             '${student.points} نقطة',
//             style: TextStyle(color: colors[rank - 1], fontSize: 12),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _PlayerTile extends StatelessWidget {
//   final Student student;
//   final int rank;
//   final bool isCurrentUser;

//   const _PlayerTile({
//     required this.student,
//     required this.rank,
//     this.isCurrentUser = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: isCurrentUser
//             ? regsin.withOpacity(0.3)
//             : textcolor.withOpacity(0.7),
//         borderRadius: BorderRadius.circular(12),
//         border: isCurrentUser ? Border.all(color: regsin, width: 1.5) : null,
//       ),
//       child: Row(
//         children: [
//           Text(
//             '$rank',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(width: 16),
//           CircleAvatar(
//             radius: 20,
//             backgroundColor: Colors.white24,
//             child: Text(
//               student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               student.name,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           Text(
//             '${student.points} نقطة',
//             style: const TextStyle(
//               color: Colors.amber,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _CurrentUserBanner extends StatelessWidget {
//   final Student student;
//   final int rank;

//   const _CurrentUserBanner({required this.student, required this.rank});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16).copyWith(bottom: 24),
//       decoration: BoxDecoration(
//         color: textcolor,
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.5),
//             blurRadius: 15,
//             spreadRadius: -5,
//           ),
//         ],
//       ),
//       child: _PlayerTile(student: student, rank: rank, isCurrentUser: true),
//     );
//   }
// }
