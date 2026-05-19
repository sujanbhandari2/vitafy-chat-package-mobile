import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/utils/messenger_media_url.dart';

void main() {
  test('messengerAbsoluteMediaUrl joins relative paths', () {
    expect(
      messengerAbsoluteMediaUrl(
        '/api/upload/file/abc.png',
        baseOrigin: 'https://api.example.com/',
      ),
      'https://api.example.com/api/upload/file/abc.png',
    );
    expect(
      messengerAbsoluteMediaUrl(
        'https://cdn.example/x.png',
        baseOrigin: 'https://api.example.com',
      ),
      'https://cdn.example/x.png',
    );
  });
}
