import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/chat_repository.dart';
import 'package:health_messenger_ui/lib/src/client/presence/remote_presence_store.dart';

void main() {
  group('RemotePresenceStore', () {
    test('tracks user_online / user_offline and ignores self', () {
      final store = RemotePresenceStore(currentUserId: 'me');

      store.applyUserOnline(
        const ChatPresenceEvent(userId: 'other', tenantId: 't'),
      );
      expect(store.onlineByUserId.value, {'other': true});

      store.applyUserOffline(
        const ChatPresenceEvent(userId: 'other', tenantId: 't'),
      );
      expect(store.onlineByUserId.value, {'other': false});

      store.applyUserOffline(
        const ChatPresenceEvent(userId: 'me', tenantId: 't'),
      );
      expect(store.onlineByUserId.value, {'other': false});

      store.dispose();
    });

    test('applyPresenceStateMap removes self', () {
      final store = RemotePresenceStore(currentUserId: 'me');

      store.applyPresenceStateMap(<String, bool>{
        'me': true,
        'other': true,
      });

      expect(store.onlineByUserId.value, {'other': true});

      store.dispose();
    });
  });
}

