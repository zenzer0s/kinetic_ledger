import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'sentiment.dart';

/// Sentiment classification result from Cerebras LLM
class LlmSentiment {
  final Sentiment sentiment;
  final String reason;
  const LlmSentiment({required this.sentiment, required this.reason});
}

class CerebrasSentimentService {
  static const _key = 'csk-h6d54d8yrpfeycdfd5vwyvwx24388fxn3vejdyke9crrd9kc';
  static const _url = 'https://api.cerebras.ai/v1/chat/completions';
  static const _model = 'llama3.1-8b';
  static const _prefixKey = 'cerebras_cache_v1_';

  // ── In-memory cache (session) ──────────────────────────────────────────────
  static final Map<String, LlmSentiment> _memCache = {};

  // ── Strict JSON Schema ─────────────────────────────────────────────────────
  static const _schema = {
    'type': 'object',
    'properties': {
      'results': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'i': {'type': 'integer'},
            's': {
              'type': 'string',
              'enum': ['BULLISH', 'BEARISH', 'NEUTRAL'],
            },
            'r': {'type': 'string'},
          },
          'required': ['i', 's', 'r'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['results'],
    'additionalProperties': false,
  };

  // ── Cache key: first 60 chars of headline, lowercased ─────────────────────
  static String _cacheKey(String headline) {
    final normalized = headline
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _prefixKey + normalized.substring(0, normalized.length.clamp(0, 60));
  }

  // ── Read from persistent cache ─────────────────────────────────────────────
  static Future<LlmSentiment?> _readCache(String headline) async {
    final k = _cacheKey(headline);
    // In-memory first
    if (_memCache.containsKey(k)) return _memCache[k];
    // Then SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(k);
      if (raw != null) {
        final parts = raw.split('|');
        if (parts.length >= 2) {
          final s = _parseSentiment(parts[0]);
          final r = parts.sublist(1).join('|'); // reason may contain |
          final result = LlmSentiment(sentiment: s, reason: r);
          _memCache[k] = result; // promote to memory
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Write to both caches ────────────────────────────────────────────────────
  static Future<void> _writeCache(String headline, LlmSentiment result) async {
    final k = _cacheKey(headline);
    _memCache[k] = result;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentStr = result.sentiment.name.toUpperCase();
      await prefs.setString(k, '$sentStr|${result.reason}');
    } catch (_) {}
  }

  // ── Public: batch classify top 10 ─────────────────────────────────────────
  Future<List<LlmSentiment>> classifyBatch(List<String> headlines) async {
    if (headlines.isEmpty) return [];

    final batch = headlines.take(10).toList();
    final result = List<LlmSentiment>.filled(headlines.length, _neutral());

    // Check cache for each headline first
    final uncachedIndices = <int>[];
    for (int i = 0; i < batch.length; i++) {
      final cached = await _readCache(batch[i]);
      if (cached != null) {
        debugPrint(
          '[Cache] HIT for "${batch[i].substring(0, batch[i].length.clamp(0, 30))}..."',
        );
        result[i] = cached;
      } else {
        uncachedIndices.add(i);
      }
    }

    if (uncachedIndices.isEmpty) {
      debugPrint('[Cache] All ${batch.length} headlines served from cache!');
      return result;
    }

    // Only call API for uncached headlines
    final uncachedHeadlines = uncachedIndices.map((i) => batch[i]).toList();
    debugPrint(
      '[Cerebras] Fetching ${uncachedHeadlines.length}/${batch.length} (rest cached)',
    );
    final apiResults = await _callApi(uncachedHeadlines);

    // Map back to original positions and write to cache
    for (int j = 0; j < uncachedIndices.length; j++) {
      final origIdx = uncachedIndices[j];
      final r = j < apiResults.length ? apiResults[j] : _neutral();
      result[origIdx] = r;
      await _writeCache(batch[origIdx], r);
    }

    return result;
  }

  // ── Public: single on-demand classify ─────────────────────────────────────
  Future<LlmSentiment> classifySingle(String headline) async {
    // Check cache first
    final cached = await _readCache(headline);
    if (cached != null) {
      debugPrint(
        '[Cache] HIT (single) for "${headline.substring(0, headline.length.clamp(0, 30))}..."',
      );
      return cached;
    }

    final results = await _callApi([headline]);
    final r = results.isNotEmpty ? results[0] : _neutral();
    await _writeCache(headline, r);
    return r;
  }

  // ── Public: "what happened" news summary for an economic event ────────────
  /// Returns a 2-3 sentence AI summary of what was announced/the outcome of
  /// this event, with a focus on Gold/USD market reaction.
  Future<String> getEventNewsSummary({
    required String eventName,
    required String country,
    required bool isPast,
    String? actual,
    String? estimate,
    String? previous,
    required String dateLabel,
  }) async {
    final cacheKey =
        '${_prefixKey}summary_${'$country|$eventName|${actual ?? ""}'.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    // Memory cache
    if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey]!.reason;

    // Persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _memCache[cacheKey] = LlmSentiment(
          sentiment: Sentiment.neutral,
          reason: cached,
        );
        return cached;
      }
    } catch (_) {}

    // Build prompt based on past vs future
    final String prompt;
    if (isPast) {
      final parts = <String>[
        '$country $eventName ($dateLabel)',
        if (actual != null) 'Actual: $actual',
        if (estimate != null) 'Forecast: $estimate',
        if (previous != null) 'Previous: $previous',
      ];
      prompt =
          'Summarize what happened when ${parts.join(", ")} was released. '
          'Was it a beat or miss? How did Gold (XAU/USD) likely react? '
          'Keep it to 2 sentences, be specific and analytical.';
    } else {
      final parts = <String>[
        '$country $eventName (upcoming $dateLabel)',
        if (estimate != null) 'Forecast: $estimate',
        if (previous != null) 'Previous: $previous',
      ];
      prompt =
          'What should traders watch for in the upcoming ${parts.join(", ")}? '
          'What are the key scenarios and expected Gold (XAU/USD) reaction? '
          '2 sentences, specific and actionable.';
    }

    try {
      debugPrint('[Cerebras] Getting news summary for: $eventName');
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a professional forex market analyst. Be concise, specific, '
                      'and focused on actionable Gold (XAU/USD) and USD market insights.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.3,
              'max_completion_tokens': 150,
            }),
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (body['choices'][0]['message']['content'] as String? ?? '')
            .trim();
        _memCache[cacheKey] = LlmSentiment(
          sentiment: Sentiment.neutral,
          reason: text,
        );
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, text);
        } catch (_) {}
        return text;
      }
    } catch (e) {
      debugPrint('[Cerebras] Summary error: $e');
    }
    return '';
  }

  // ── Public: analyze a single economic event ───────────────────────────────
  Future<String> analyzeCalendarEvent({
    required String eventName,
    required String country,
    required String impact,
    String? estimate,
    String? previous,
  }) async {
    final cacheKey =
        '${_prefixKey}cal_${'$country|$eventName'.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    // Check caches first
    if (_memCache.containsKey(cacheKey)) {
      return _memCache[cacheKey]!.reason;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        _memCache[cacheKey] = LlmSentiment(
          sentiment: Sentiment.neutral,
          reason: cached,
        );
        return cached;
      }
    } catch (_) {}

    // Build context string
    final context = StringBuffer('$country $eventName ($impact impact)');
    if (estimate != null) context.write(', estimate: $estimate');
    if (previous != null) context.write(', previous: $previous');

    try {
      debugPrint('[Cerebras] Analyzing calendar event: $eventName');
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a professional forex trader analyst specializing in Gold (XAU/USD) and USD/INR. '
                      'Answer in 1 concise sentence (max 15 words). Focus on Gold price impact.',
                },
                {
                  'role': 'user',
                  'content':
                      'What is the likely impact on Gold price for: $context?',
                },
              ],
              'temperature': 0.2,
              'max_completion_tokens': 80,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (body['choices'][0]['message']['content'] as String? ?? '')
            .trim();
        // Cache it
        _memCache[cacheKey] = LlmSentiment(
          sentiment: Sentiment.neutral,
          reason: text,
        );
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, text);
        } catch (_) {}
        return text;
      }
    } catch (e) {
      debugPrint('[Cerebras] Calendar event analysis error: $e');
    }
    return '';
  }

  // ── Internal API call ──────────────────────────────────────────────────────
  Future<List<LlmSentiment>> _callApi(List<String> headlines) async {
    final numbered = headlines
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. "${e.value}"')
        .join('\n');

    const systemPrompt =
        'You are a professional forex and financial market analyst. '
        'Classify each news headline as BULLISH, BEARISH, or NEUTRAL '
        'from a USD/INR/Gold forex perspective. '
        'Return a JSON object with a "results" array. '
        'Each item: i=headline number, s=BULLISH|BEARISH|NEUTRAL, r=reason (max 10 words).';

    final userPrompt = 'Classify:\n$numbered';

    try {
      debugPrint('[Cerebras] Sending ${headlines.length} headlines...');

      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'sentiment_response',
                  'strict': true,
                  'schema': _schema,
                },
              },
              'temperature': 0.1,
              'max_completion_tokens': 800,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('[Cerebras] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            body['choices'][0]['message']['content'] as String? ?? '';
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        final items = parsed['results'] as List? ?? [];

        debugPrint('[Cerebras] Got ${items.length} classifications');

        final result = List<LlmSentiment>.filled(headlines.length, _neutral());
        for (final item in items) {
          if (item is! Map) continue;
          final idx = ((item['i'] as num?) ?? 0).toInt() - 1;
          if (idx < 0 || idx >= headlines.length) continue;
          final s = (item['s'] as String? ?? 'NEUTRAL').toUpperCase();
          final r = item['r'] as String? ?? '';
          result[idx] = LlmSentiment(sentiment: _parseSentiment(s), reason: r);
        }
        return result;
      } else {
        debugPrint('[Cerebras] Error body: ${response.body}');
      }
    } catch (e, st) {
      debugPrint('[Cerebras] Exception: $e\n$st');
    }

    return List.filled(headlines.length, _neutral());
  }

  static Sentiment _parseSentiment(String s) {
    if (s == 'BULLISH') return Sentiment.bullish;
    if (s == 'BEARISH') return Sentiment.bearish;
    return Sentiment.neutral;
  }

  static LlmSentiment _neutral() =>
      const LlmSentiment(sentiment: Sentiment.neutral, reason: '');

  // ── Clear all caches ────────────────────────────────────────────────────────
  static Future<void> clearAllCaches() async {
    _memCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    for (final k in allKeys) {
      if (k.startsWith(_prefixKey)) {
        await prefs.remove(k);
      }
    }
    debugPrint('[Cerebras] All caches cleared');
  }
}
