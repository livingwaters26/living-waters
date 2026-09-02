import 'dart:convert';
import 'dart:io';

import 'bible_text_service.dart';

/// One suggested emphasis or pause point, anchored to an exact substring of
/// text that's already there - never new or changed wording. See
/// [EmphasisService.analyze] for how that's actually enforced, not just
/// assumed.
class EmphasisMark {
  final int chunkIndex; // index into the verses/chunks list passed in
  final String phrase; // an exact substring of that chunk's original text
  final String type; // 'emphasis' or 'pause'

  EmphasisMark({required this.chunkIndex, required this.phrase, required this.type});
}

/// Optional, AI-assisted delivery help for the teleprompter: given text
/// you're already about to read verbatim (scripture or your own notes),
/// asks Claude to point out words worth emphasizing and natural places to
/// pause - never to rewrite, correct, paraphrase, or add anything. This is
/// a delivery aid, not an editor - it never gets to decide what you say,
/// only how you might say it.
///
/// Requires an internet connection and an Anthropic API key (entered once,
/// stored via SettingsService) - deliberately NOT wired into anything else
/// in the app, which stays fully offline otherwise. Only runs when you
/// explicitly tap "Analyze for Emphasis" before recording, never
/// automatically and never while actually recording/scrolling.
class EmphasisService {
  static const _model = 'claude-haiku-4-5';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Sends the given text chunks to Claude and returns only the marks that
  /// pass verification - every returned "phrase" is checked against the
  /// ORIGINAL chunk text it claims to come from, and anything that isn't an
  /// exact, verbatim, case-sensitive substring is silently dropped. This is
  /// what actually guarantees the wording on screen can never be changed,
  /// added to, or "corrected" by this feature - the AI's response is only
  /// ever used to decide where to add visual styling around text you
  /// already have, never to replace any of it.
  Future<List<EmphasisMark>> analyze({
    required List<BibleVerse> chunks,
    required String apiKey,
  }) async {
    if (chunks.isEmpty) return [];

    final numbered = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      numbered.writeln('[$i] ${chunks[i].text}');
    }

    const systemPrompt =
        'You help someone read text aloud more naturally. You will be given '
        'numbered chunks of text that will be read exactly as written - you '
        'must NEVER change, correct, paraphrase, translate, summarize, or '
        'add to the wording in any way, even if it looks unusual or contains '
        'an apparent error. Your only job is to suggest, for each chunk: (1) '
        'short words or phrases worth vocal emphasis when spoken aloud, and '
        '(2) short phrases after which a brief pause would help a listener. '
        'Respond with ONLY a JSON array (no other text, no markdown fences) '
        'of objects shaped exactly like {"chunk": <chunk number>, "phrase": '
        '"<exact text copied verbatim from that chunk>", "type": "emphasis" '
        'or "pause"}. Every "phrase" value MUST be an exact, character-for-'
        'character substring of the numbered chunk it references - copy it, '
        'do not retype or paraphrase it. Keep phrases short (a few words at '
        'most). Suggest emphasis/pauses sparingly - only the points that '
        'would genuinely help a reader, not every sentence.';

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': numbered.toString()},
      ],
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.set('content-type', 'application/json');
      request.headers.set('x-api-key', apiKey);
      request.headers.set('anthropic-version', '2023-06-01');
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('AI request failed (HTTP ${response.statusCode}): $responseBody');
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>?;
      final text = (content == null || content.isEmpty)
          ? ''
          : ((content.first as Map<String, dynamic>)['text'] as String? ?? '');

      final marksRaw = _extractJsonArray(text);
      if (marksRaw == null) return [];

      final marks = <EmphasisMark>[];
      for (final item in marksRaw) {
        if (item is! Map) continue;
        final chunkIndex = item['chunk'];
        final phrase = item['phrase'];
        final type = item['type'];
        if (chunkIndex is! int || phrase is! String || type is! String) continue;
        if (chunkIndex < 0 || chunkIndex >= chunks.length) continue;
        if (type != 'emphasis' && type != 'pause') continue;
        if (phrase.trim().isEmpty) continue;
        // The actual safety check: reject anything that isn't a verbatim
        // substring of the original text for that chunk.
        if (!chunks[chunkIndex].text.contains(phrase)) continue;
        marks.add(EmphasisMark(chunkIndex: chunkIndex, phrase: phrase, type: type));
      }
      return marks;
    } finally {
      client.close();
    }
  }

  /// Claude is asked for JSON-only output, but this guards against it
  /// wrapping the array in stray text or a code fence anyway.
  List<dynamic>? _extractJsonArray(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end < start) return null;
    try {
      final parsed = jsonDecode(text.substring(start, end + 1));
      return parsed is List ? parsed : null;
    } catch (_) {
      return null;
    }
  }
}
