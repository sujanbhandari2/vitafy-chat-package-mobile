import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  test('startConversationGroupName uses trimmed name when provided', () {
    const request = MessengerGroupCreateRequest(
      selectedUsers: [],
      groupName: '  Clinical Team  ',
    );
    expect(request.startConversationGroupName(), 'Clinical Team');
  });

  test('startConversationGroupName uses fallback when empty', () {
    const request = MessengerGroupCreateRequest(
      selectedUsers: [],
      groupName: '',
    );
    expect(request.startConversationGroupName(), 'Group');
    expect(request.startConversationGroupName(fallback: 'Care pod'), 'Care pod');
  });
}
