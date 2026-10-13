import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/utils/messenger_composer_attachments.dart';
import 'package:health_messenger_ui/lib/src/widgets/messenger_media_send_orchestrator.dart';

void main() {
  group('buildAttachmentSendBatches', () {
    test('splits non-image attachments into separate batches', () {
      final pending = [
        MessengerPickedMedia(
          file: File('a.pdf'),
          messageType: MessageType.file,
          displayName: 'a.pdf',
        ),
        MessengerPickedMedia(
          file: File('b.mp4'),
          messageType: MessageType.video,
          displayName: 'b.mp4',
        ),
      ];
      final batches = buildAttachmentSendBatches(pending, '');
      expect(batches.length, 2);
      expect(batches[0].pendingIndices, [0]);
      expect(batches[0].messageType, MessageType.file);
      expect(batches[1].pendingIndices, [1]);
      expect(batches[1].messageType, MessageType.video);
    });

    test('puts caption only on final batch', () {
      final pending = [
        MessengerPickedMedia(
          file: File('a.jpg'),
          messageType: MessageType.image,
          displayName: 'a.jpg',
        ),
        MessengerPickedMedia(
          file: File('doc.pdf'),
          messageType: MessageType.file,
          displayName: 'doc.pdf',
        ),
      ];
      final batches = buildAttachmentSendBatches(pending, '  hello  ');
      expect(batches.length, 2);
      expect(batches[0].includeCaption, isFalse);
      expect(batches[1].includeCaption, isTrue);
    });

    test('returns empty list for empty pending', () {
      expect(buildAttachmentSendBatches(const [], 'x'), isEmpty);
    });
  });

  group('pendingAttachmentsOverLimit', () {
    test('returns false under 25 MB combined', () async {
      final dir = await Directory.systemTemp.createTemp('attach-limit');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/small.bin');
      await file.writeAsBytes(List<int>.filled(1024, 0));
      final pending = [
        MessengerPickedMedia(
          file: file,
          messageType: MessageType.file,
          displayName: 'small.bin',
        ),
      ];
      expect(pendingAttachmentsOverLimit(pending), isFalse);
    });
  });
}
