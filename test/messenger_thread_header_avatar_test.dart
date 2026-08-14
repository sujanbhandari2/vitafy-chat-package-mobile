import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  group('conversationListItemInitials', () {
    test('uses first and last name letters', () {
      expect(conversationListItemInitials('Alice Jones'), 'AJ');
      expect(conversationListItemInitials('Alice Bob Charlie'), 'AC');
    });

    test('uses first two letters for single token names', () {
      expect(conversationListItemInitials('Alice'), 'AL');
    });
  });

  group('messengerThreadHeaderAvatarLabel', () {
    test('derives initials from conversation title', () {
      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Alice Jones',
        subtitle: 'Hello',
        avatarLabel: 'X',
        createdAt: DateTime.utc(2026),
      );

      expect(messengerThreadHeaderAvatarLabel(conversation), 'AJ');
    });

    test('falls back to avatarLabel when title is empty', () {
      final conversation = MessengerConversation(
        id: 'c1',
        title: '',
        subtitle: 'Hello',
        avatarLabel: 'XY',
        createdAt: DateTime.utc(2026),
      );

      expect(messengerThreadHeaderAvatarLabel(conversation), 'XY');
    });
  });

  group('messengerThreadHeaderAvatarUrl', () {
    test('prefers conversation avatarUrl', () {
      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Alice Jones',
        subtitle: 'Hello',
        avatarLabel: 'AJ',
        avatarUrl: 'https://example.com/alice.jpg',
        createdAt: DateTime.utc(2026),
        peerUsers: const [
          MessengerUser(
            id: 'peer',
            username: 'alice',
            avatarUrl: 'https://example.com/peer.jpg',
          ),
        ],
      );

      expect(
        messengerThreadHeaderAvatarUrl(conversation),
        'https://example.com/alice.jpg',
      );
    });

    test('falls back to direct peer avatarUrl', () {
      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Alice Jones',
        subtitle: 'Hello',
        avatarLabel: 'AJ',
        createdAt: DateTime.utc(2026),
        peerUsers: const [
          MessengerUser(
            id: 'peer',
            username: 'alice',
            avatarUrl: 'https://example.com/peer.jpg',
          ),
        ],
      );

      expect(
        messengerThreadHeaderAvatarUrl(conversation),
        'https://example.com/peer.jpg',
      );
    });
  });
}
