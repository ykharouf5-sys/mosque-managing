import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
                children: [
                  const TextSpan(text: ' جميع الحقوق محفوظة لدى '),
                  TextSpan(
                    text: ' مسجد العمري ',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse('https://www.facebook.com/profile.php?id=100072367901125&mibextid=ZbWKwL'),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: ' • '),
                  TextSpan(
                    text: ' يمان خاروف ',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse('https://www.instagram.com/yaman_5arouf?igsh=MWw5d2IycW5yMXkwdg=='),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copyright_outlined, color: Colors.white70, size: 14),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
