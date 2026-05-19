import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/utils/messenger_media_url.dart';

void main() {
  test('messengerMediaSourceIsNetwork detects http and https', () {
    expect(messengerMediaSourceIsNetwork('https://example.com/a.png'), isTrue);
    expect(messengerMediaSourceIsNetwork('http://cdn.test/x'), isTrue);
    expect(messengerMediaSourceIsNetwork('/tmp/a.png'), isFalse);
    expect(messengerMediaSourceIsNetwork(''), isFalse);
  });
}
