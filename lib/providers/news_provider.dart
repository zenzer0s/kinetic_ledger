import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/news_service.dart';
import '../services/cerebras_service.dart';
import '../services/notification_service.dart';
import '../services/sentiment.dart';


final newsServiceProvider = Provider((ref) => NewsService());
final cerebrasProvider = Provider((ref) => CerebrasSentimentService());

// ── News with LLM sentiment ───────────────────────────────────────────────────
class EnrichedArticle {
  final NewsArticle article;
  final LlmSentiment llmSentiment;

  const EnrichedArticle({required this.article, required this.llmSentiment});

  Sentiment get sentiment => llmSentiment.sentiment;
  String get reason => llmSentiment.reason;
}

final newsProvider =
    FutureProvider.autoDispose<List<EnrichedArticle>>((ref) async {
  // Keep alive for 60s so tab switches don't re-trigger the LLM call
  final link = ref.keepAlive();
  Future.delayed(const Duration(seconds: 60), link.close);

  final articles = await ref.read(newsServiceProvider).fetchNews();
  if (articles.isEmpty) return [];

  final headlines = articles.map((a) => a.headline).toList();
  final sentiments =
      await ref.read(cerebrasProvider).classifyBatch(headlines);

  return List.generate(articles.length, (i) {
    return EnrichedArticle(
      article: articles[i],
      llmSentiment: i < sentiments.length
          ? sentiments[i]
          : LlmSentiment(sentiment: Sentiment.neutral, reason: ''),
    );
  });
});

// ── Calendar ──────────────────────────────────────────────────────────────────
// Normal loads use the persistent cache. Pull-to-refresh clears cache then
// invalidates this provider, forcing a fresh network fetch.
final calendarProvider =
    FutureProvider.autoDispose<List<EconomicEvent>>((ref) async {
  final events = await ref.read(newsServiceProvider).fetchCalendar();

  // Schedule Tier-1 notifications from fresh data (fire-and-forget)
  if (events.isNotEmpty) {
    final ns = NotificationService();
    ns.scheduleCalendarAlerts(events);
    ns.scheduleDailyDigest(events);
  }

  return events;
});
