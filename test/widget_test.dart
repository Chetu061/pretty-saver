import 'package:flutter_test/flutter_test.dart';
import 'package:insta_story_app/core/errors.dart';
import 'package:insta_story_app/core/links.dart';
import 'package:insta_story_app/l10n/strings.dart';

void main() {
  group('checkLink', () {
    test('accepts reel link and strips tracking params', () {
      final result = checkLink('https://www.instagram.com/reel/C1a2B3c4D5e/?igsh=abc123');
      expect(result, isA<ValidLink>());
      expect((result as ValidLink).url, 'https://www.instagram.com/reel/C1a2B3c4D5e/');
    });

    test('finds link inside share text', () {
      final result = checkLink('Check this out! https://instagram.com/p/XYZ123/ wow');
      expect((result as ValidLink).url, 'https://instagram.com/p/XYZ123/');
    });

    test('accepts story links', () {
      final result = checkLink('https://www.instagram.com/stories/someone/123456/?utm_source=ig_story_item_share');
      expect((result as ValidLink).url, 'https://www.instagram.com/stories/someone/123456/');
    });

    test('rejects profiles and non-instagram links', () {
      expect((checkLink('https://www.instagram.com/someone/') as InvalidLink).reason, Problem.notReel);
      expect((checkLink('https://youtube.com/watch?v=1') as InvalidLink).reason, Problem.notInstagram);
      expect((checkLink('') as InvalidLink).reason, Problem.notInstagram);
    });
  });

  test('classifyError treats login-required as public-only', () {
    final problem = classifyError('ERROR: [Instagram] abc: Requested content is not available, rate-limit reached or login required');
    expect(problem, Problem.publicOnly);
  });

  test('needsSignIn detects the empty media response', () {
    expect(needsSignIn('ERROR: [Instagram] CWq: Instagram sent an empty media response. Check if this post is accessible'), isTrue);
    expect(needsSignIn('ERROR: Unable to download webpage: timed out'), isFalse);
  });

  test('every problem has text in all three languages', () {
    for (final code in S.languages.keys) {
      for (final problem in Problem.values) {
        expect(S(code).problem(problem), isNotEmpty);
      }
    }
    expect(const S('hi').download, 'डाउनलोड');
    expect(const S('mr').clearHistoryBody, contains('गॅलरीतून डिलीट होणार नाहीत'));
  });
}
