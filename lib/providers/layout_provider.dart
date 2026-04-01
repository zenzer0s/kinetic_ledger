import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ResultLayoutType {
  glowingDefault,
  glassCard,
  splitMinimal,
  conversionFlow,
}

class ResultLayoutNotifier extends Notifier<ResultLayoutType> {
  @override
  ResultLayoutType build() => ResultLayoutType.glowingDefault;

  void setLayout(ResultLayoutType type) {
    state = type;
  }
}

final resultLayoutProvider =
    NotifierProvider<ResultLayoutNotifier, ResultLayoutType>(
      ResultLayoutNotifier.new,
    );
