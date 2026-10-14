import 'errors.dart';

/// Result of checking a pasted or shared piece of text.
sealed class LinkCheck {
  const LinkCheck();
}

class ValidLink extends LinkCheck {
  const ValidLink(this.url);
  final String url;
}

class InvalidLink extends LinkCheck {
  const InvalidLink(this.reason);
  final Problem reason;
}

final _instaUrl = RegExp(
  r'https?://(?:www\.|m\.)?(?:instagram\.com|instagr\.am)/[^\s]+',
  caseSensitive: false,
);

// Stories always need a signed-in session; the download error offers sign-in when missing.
const _supportedPaths = ['reel', 'reels', 'p', 'tv', 'share', 'stories'];

/// Finds the Instagram link inside [text] (share text can include extra words)
/// and strips tracking parameters like `?igsh=`.
LinkCheck checkLink(String text) {
  final match = _instaUrl.firstMatch(text.trim());
  if (match == null) return const InvalidLink(Problem.notInstagram);

  final uri = Uri.tryParse(match.group(0)!);
  if (uri == null || uri.pathSegments.isEmpty) return const InvalidLink(Problem.notInstagram);

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final first = segments.first.toLowerCase();

  if (!_supportedPaths.contains(first) || segments.length < 2) {
    return const InvalidLink(Problem.notReel);
  }

  return ValidLink(Uri(scheme: 'https', host: uri.host, path: uri.path).toString());
}
