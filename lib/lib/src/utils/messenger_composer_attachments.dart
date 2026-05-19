import '../client/models/chat_message.dart';
import '../widgets/messenger_media_send_orchestrator.dart';

/// Max combined size for queued composer attachments (25 MB, matches web).
const int kMessengerComposerPendingAttachmentsMaxTotalBytes =
    25 * 1024 * 1024;

/// One REST message: one or more pending files (images are grouped in a run).
class MessengerAttachmentSendBatch {
  const MessengerAttachmentSendBatch({
    required this.pendingIndices,
    required this.messageType,
    required this.includeCaption,
  });

  final List<int> pendingIndices;
  final MessageType messageType;
  final bool includeCaption;
}

/// Build send batches: consecutive IMAGE files → one message; each other type → its own message.
/// Caption attaches to the last batch when non-empty.
List<MessengerAttachmentSendBatch> buildAttachmentSendBatches(
  List<MessengerPickedMedia> pending,
  String caption,
) {
  if (pending.isEmpty) {
    return const [];
  }
  final hasCaption = caption.trim().isNotEmpty;
  final batches = <MessengerAttachmentSendBatch>[];
  var imageRun = <int>[];

  void flushImageRun() {
    if (imageRun.isEmpty) {
      return;
    }
    batches.add(
      MessengerAttachmentSendBatch(
        pendingIndices: List<int>.from(imageRun),
        messageType: MessageType.image,
        includeCaption: false,
      ),
    );
    imageRun = [];
  }

  for (var i = 0; i < pending.length; i++) {
    final att = pending[i];
    if (att.messageType == MessageType.image) {
      imageRun.add(i);
    } else {
      flushImageRun();
      batches.add(
        MessengerAttachmentSendBatch(
          pendingIndices: [i],
          messageType: att.messageType,
          includeCaption: false,
        ),
      );
    }
  }
  flushImageRun();

  if (hasCaption && batches.isNotEmpty) {
    final last = batches.last;
    batches[batches.length - 1] = MessengerAttachmentSendBatch(
      pendingIndices: last.pendingIndices,
      messageType: last.messageType,
      includeCaption: true,
    );
  }
  return batches;
}

int pendingAttachmentsTotalBytes(List<MessengerPickedMedia> pending) {
  var total = 0;
  for (final att in pending) {
    try {
      total += att.file.lengthSync();
    } catch (_) {}
  }
  return total;
}

bool pendingAttachmentsOverLimit(List<MessengerPickedMedia> pending) {
  return pendingAttachmentsTotalBytes(pending) >
      kMessengerComposerPendingAttachmentsMaxTotalBytes;
}

class MessengerSendPendingAttachmentsResult {
  const MessengerSendPendingAttachmentsResult._({
    required this.ok,
    required this.sentPendingCount,
    this.lastMessage,
    this.error,
  });

  final bool ok;
  final int sentPendingCount;
  final ChatMessage? lastMessage;
  final String? error;

  factory MessengerSendPendingAttachmentsResult.success({
    required ChatMessage lastMessage,
    required int sentPendingCount,
  }) {
    return MessengerSendPendingAttachmentsResult._(
      ok: true,
      sentPendingCount: sentPendingCount,
      lastMessage: lastMessage,
    );
  }

  factory MessengerSendPendingAttachmentsResult.failure({
    required int sentPendingCount,
    ChatMessage? lastMessage,
    required String error,
  }) {
    return MessengerSendPendingAttachmentsResult._(
      ok: false,
      sentPendingCount: sentPendingCount,
      lastMessage: lastMessage,
      error: error,
    );
  }
}
