import 'dart:async';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_request_queue.dart';

// Do not expose provider descriptions, tokens, email addresses, or server payloads.
String googleSignInFailureMessage(Object error) {
  if (error is GoogleSignInException) {
    final description = (error.description ?? '').toLowerCase();
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError ||
        description.contains('not registered to use oauth') ||
        description.contains('developer_error') ||
        description.contains('apiexception: 10')) {
      return 'تسجيل الدخول بـ Google غير متاح لهذا الإصدار حالياً. استخدم البريد الإلكتروني مؤقتاً.';
    }
    if (description.contains('network')) {
      return 'تحقق من اتصال الإنترنت وحاول مجدداً.';
    }
    // Android may report a configuration failure as canceled after account selection.
    // Do not blame the user or silently swallow that result.
    if (error.code == GoogleSignInExceptionCode.canceled ||
        error.code == GoogleSignInExceptionCode.interrupted) {
      return 'لم يكتمل تسجيل الدخول بـ Google. أعد المحاولة أو استخدم البريد الإلكتروني.';
    }
  }
  if (error is SocketException || error is TimeoutException) {
    return 'تحقق من اتصال الإنترنت وحاول مجدداً.';
  }
  if (error is ApiException) {
    if (error.statusCode == 429) {
      return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
    }
    if (error.statusCode >= 500) {
      return 'تعذر الاتصال بخادم Studentry. حاول مجدداً بعد قليل.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'تعذر التحقق من دخول Google. حاول مجدداً أو استخدم البريد الإلكتروني.';
    }
  }
  return 'تعذر إكمال تسجيل الدخول بـ Google. حاول مجدداً أو استخدم البريد الإلكتروني.';
}
