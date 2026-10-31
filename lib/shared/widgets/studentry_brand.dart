import 'package:flutter/material.dart';

/// The original artwork stays unchanged; a fine silhouette defines its pale areas.
class StudentryBrandImage extends StatelessWidget {
  const StudentryBrandImage({super.key, this.asset = 'assets/image/logo.png'});
  final String asset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final offset in const [
        Offset(-.65, 0),
        Offset(.65, 0),
        Offset(0, -.65),
        Offset(0, .65),
      ])
        Transform.translate(
          offset: offset,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            color: const Color(0x660D5660),
            colorBlendMode: BlendMode.srcIn,
            excludeFromSemantics: true,
          ),
        ),
      Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    ],
  );
}

class StudentryBrandMark extends StatelessWidget {
  const StudentryBrandMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .09),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * .27),
      border: Border.all(color: const Color(0xFFA8C9CF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140D5660),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: const StudentryBrandImage(),
  );
}
