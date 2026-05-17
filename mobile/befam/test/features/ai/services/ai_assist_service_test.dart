import 'package:befam/features/ai/services/ai_assist_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant reply accepts routable shell and workspace destinations', () {
    for (final destination in [
      'home',
      'tree',
      'events',
      'funds',
      'billing',
      'profile',
    ]) {
      final reply = AppAssistantReply.fromMap({
        'answer': 'Open $destination',
        'suggestedDestination': destination,
      });

      expect(reply.suggestedDestination, destination);
    }
  });

  test('assistant reply drops unknown suggested destination', () {
    final reply = AppAssistantReply.fromMap({
      'answer': 'Open unsafe place',
      'suggestedDestination': 'admin_secret',
    });

    expect(reply.suggestedDestination, isNull);
  });
}
