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

  test('messengerMediaServerOrigin strips trailing /api', () {
    expect(
      messengerMediaServerOrigin('https://api.example.com/api/'),
      'https://api.example.com',
    );
    expect(
      messengerMediaServerOrigin('https://api.example.com'),
      'https://api.example.com',
    );
  });

  test('messengerHeadersForMediaUrl drops auth for public CDN hosts', () {
    const headers = {
      'Authorization': 'Bearer jwt',
      'X-Api-Key': 'key:secret',
    };
    expect(
      messengerHeadersForMediaUrl(
        'https://cdn.example.com/chat/photo.jpg',
        headers: headers,
        mediaBaseOrigin: 'https://api.example.com',
      ),
      isEmpty,
    );
    expect(
      messengerHeadersForMediaUrl(
        'https://api.example.com/uploads/photo.jpg',
        headers: headers,
        mediaBaseOrigin: 'https://api.example.com',
      ),
      headers,
    );
  });

  test('messengerMediaUrlIsSameOrigin compares hosts only', () {
    expect(
      messengerMediaUrlIsSameOrigin(
        'https://api.example.com/path/a.png',
        mediaBaseOrigin: 'https://api.example.com/api',
      ),
      isTrue,
    );
    expect(
      messengerMediaUrlIsSameOrigin(
        'https://bucket.s3.amazonaws.com/a.png',
        mediaBaseOrigin: 'https://api.example.com',
      ),
      isFalse,
    );
  });
}
