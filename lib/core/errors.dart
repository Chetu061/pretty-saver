import 'package:flutter/services.dart';

/// What went wrong, independent of language; `S.problem` turns it into text.
enum Problem {
  notInstagram,
  notReel,
  unsupported,
  publicOnly,
  needsSignIn,
  noInternet,
  noSpace,
  cancelled,
  noVideo,
  busy,
  storagePermission,
}

/// Instagram hides the post from logged-out clients; signing in fixes these.
bool needsSignIn(Object error) {
  final text = errorDetails(error).toLowerCase();
  return text.contains('empty media response') ||
      text.contains('login required') ||
      text.contains('--cookies') ||
      text.contains('not granting access');
}

/// Maps raw yt-dlp error output to something a person can act on.
Problem classifyError(Object error) {
  final text = errorDetails(error).toLowerCase();

  if (text.contains('unable to download webpage') ||
      text.contains('failed to resolve') ||
      text.contains('network is unreachable') ||
      text.contains('timed out')) {
    return Problem.noInternet;
  }
  if (text.contains('no space left')) return Problem.noSpace;
  if (text.contains('canceled') || text.contains('cancelled')) return Problem.cancelled;
  if (text.contains('no video found') || text.contains('no video formats')) return Problem.noVideo;
  if (text.contains('unsupported url')) return Problem.unsupported;
  // yt-dlp says "rate-limit reached or login required" for private reels too.
  if (text.contains('login required')) return Problem.publicOnly;
  if (text.contains('rate-limit') || text.contains('rate limit') || text.contains('429')) return Problem.busy;
  // Private, deleted, login-walled or anything else Instagram refused.
  return Problem.publicOnly;
}

/// The raw engine output behind an error, for the "Details" section and bug reports.
String errorDetails(Object error) {
  if (error is PlatformException) {
    final message = error.message?.trim();
    return message == null || message.isEmpty ? '${error.code} (no message)' : message;
  }
  return error.toString();
}
