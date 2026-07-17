import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/messenger_composer_attachments.dart';
import '../widgets/messenger_media_send_orchestrator.dart';
import 'messenger_attachment.dart';
import 'messenger_conversation.dart';
import 'messenger_message.dart';
import 'messenger_message_attachment.dart';

/// Resolved payload kind for per-type message content builders.
enum MessengerMessageContentKind {
  deleted,
  uploading,
  text,
  image,
  video,
  voice,
  file,
  mixedAttachments,
}

/// Maps a [MessengerChatMessage] to a [MessengerMessageContentKind] for builder
/// dispatch. Matches the default bubble rendering branches.
MessengerMessageContentKind messengerResolveMessageContentKind(
  MessengerChatMessage message,
) {
  if (message.isDeleted) {
    return MessengerMessageContentKind.deleted;
  }
  if (message.isUploading) {
    return MessengerMessageContentKind.uploading;
  }
  if (message.attachments.isNotEmpty) {
    final kinds = message.attachments.map((a) => a.kind).toSet();
    if (kinds.length > 1 ||
        (kinds.length == 1 &&
            kinds.first != MessengerMessageAttachmentKind.image)) {
      return MessengerMessageContentKind.mixedAttachments;
    }
    final onlyImages = message.attachments.every(
      (a) => a.kind == MessengerMessageAttachmentKind.image,
    );
    if (onlyImages) {
      return MessengerMessageContentKind.image;
    }
    return MessengerMessageContentKind.mixedAttachments;
  }
  switch (message.type) {
    case MessengerMessageType.image:
      return MessengerMessageContentKind.image;
    case MessengerMessageType.video:
      return MessengerMessageContentKind.video;
    case MessengerMessageType.voice:
      return MessengerMessageContentKind.voice;
    case MessengerMessageType.file:
      return MessengerMessageContentKind.file;
    case MessengerMessageType.text:
      return MessengerMessageContentKind.text;
  }
}

/// Data for a custom conversation thread header.
class MessengerThreadHeaderData {
  const MessengerThreadHeaderData({
    required this.conversation,
    required this.isMobile,
    this.onBack,
    this.onEditGroupConversation,
    this.onAddPeopleToGroupConversation,
    this.onDeleteConversation,
    this.onDismissMobileThreadAfterConversationDelete,
    this.packageDialogTheme,
  });

  final MessengerConversation? conversation;
  final bool isMobile;
  final VoidCallback? onBack;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onEditGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onAddPeopleToGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onDeleteConversation;
  final VoidCallback? onDismissMobileThreadAfterConversationDelete;
  final ThemeData? packageDialogTheme;
}

typedef MessengerThreadHeaderBuilder = Widget Function(
  BuildContext context,
  MessengerThreadHeaderData data,
);

/// Context for replacing an entire message bubble row in the thread list.
class MessengerMessageBubbleContext {
  const MessengerMessageBubbleContext({
    required this.message,
    required this.isMine,
    this.currentUserId,
    this.canDelete = false,
    this.canEdit = false,
    this.onReact,
    this.onRemoveReaction,
    this.onDelete,
    this.onEdit,
    this.onMarkSeen,
    this.onRetryUpload,
    this.onSwipeToReply,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.showDeliveryStatus = true,
    this.attachmentCaptionTextStyle,
    this.packageDialogTheme,
  });

  final MessengerChatMessage message;
  final bool isMine;
  final String? currentUserId;
  final bool canDelete;
  final bool canEdit;
  final ValueChanged<String>? onReact;
  final Future<void> Function(String messageId, String reactionType)?
      onRemoveReaction;
  final FutureOr<void> Function()? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onMarkSeen;
  final VoidCallback? onRetryUpload;
  final ValueChanged<MessengerChatMessage>? onSwipeToReply;
  final bool enableReactions;
  final List<String> reactionOptions;
  final bool showDeliveryStatus;
  final TextStyle? attachmentCaptionTextStyle;
  final ThemeData? packageDialogTheme;
}

typedef MessengerMessageBubbleBuilder = Widget Function(
  BuildContext context,
  MessengerMessageBubbleContext contextData,
);

/// Data passed to per-type message content builders inside a bubble.
class MessengerMessageContentData {
  const MessengerMessageContentData({
    required this.message,
    required this.isMine,
    required this.contentKind,
    required this.textColor,
    required this.mutedColor,
    required this.attachmentCaptionStyle,
    required this.openImageGallery,
    required this.openFilePreview,
    this.packageDialogTheme,
    this.onRetryUpload,
  });

  final MessengerChatMessage message;
  final bool isMine;
  final MessengerMessageContentKind contentKind;
  final Color textColor;
  final Color mutedColor;
  final TextStyle attachmentCaptionStyle;
  final ThemeData? packageDialogTheme;
  final VoidCallback? onRetryUpload;

  /// Opens the package image lightbox for [urls] starting at [initialIndex].
  final void Function(List<String> urls, int initialIndex) openImageGallery;

  /// Opens the package document preview dialog.
  final void Function({
    required String source,
    String? fileName,
    String? mimeType,
  }) openFilePreview;
}

typedef MessengerMessageContentBuilder = Widget Function(
  BuildContext context,
  MessengerMessageContentData data,
);

/// Optional per-type overrides for message bubble inner content.
class MessengerMessageContentBuilders {
  const MessengerMessageContentBuilders({
    this.textBuilder,
    this.imageBuilder,
    this.videoBuilder,
    this.voiceBuilder,
    this.fileBuilder,
    this.deletedBuilder,
    this.uploadingBuilder,
    this.mixedAttachmentsBuilder,
  });

  final MessengerMessageContentBuilder? textBuilder;
  final MessengerMessageContentBuilder? imageBuilder;
  final MessengerMessageContentBuilder? videoBuilder;
  final MessengerMessageContentBuilder? voiceBuilder;
  final MessengerMessageContentBuilder? fileBuilder;
  final MessengerMessageContentBuilder? deletedBuilder;
  final MessengerMessageContentBuilder? uploadingBuilder;
  final MessengerMessageContentBuilder? mixedAttachmentsBuilder;

  MessengerMessageContentBuilder? builderForKind(
    MessengerMessageContentKind kind,
  ) {
    switch (kind) {
      case MessengerMessageContentKind.deleted:
        return deletedBuilder;
      case MessengerMessageContentKind.uploading:
        return uploadingBuilder;
      case MessengerMessageContentKind.text:
        return textBuilder;
      case MessengerMessageContentKind.image:
        return imageBuilder;
      case MessengerMessageContentKind.video:
        return videoBuilder;
      case MessengerMessageContentKind.voice:
        return voiceBuilder;
      case MessengerMessageContentKind.file:
        return fileBuilder;
      case MessengerMessageContentKind.mixedAttachments:
        return mixedAttachmentsBuilder;
    }
  }
}

/// Data for replacing the conversation composer bar.
class MessengerComposerData {
  const MessengerComposerData({
    required this.controller,
    required this.isRecording,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onToggleRecording,
    this.onStartRecording,
    this.onFinishRecording,
    this.onCancelRecording,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickVideo,
    this.hintText = 'Type your message...',
    this.inputTextStyle,
    this.hintTextStyle,
    this.fieldBackgroundColor,
    this.fieldContentPadding,
    this.attachmentSheetTitle = 'Attachments',
    this.attachmentOptions,
    this.attachmentOptionTextStyle,
    this.typingConversationId,
    this.onTypingStart,
    this.onTypingStop,
    this.pendingAttachments = const [],
    this.onRemovePendingAttachment,
    this.onClearAllPendingAttachments,
    this.replyDraft,
    this.onCancelReplyDraft,
    this.textFieldFocusNode,
  });

  final TextEditingController controller;
  final bool isRecording;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback? onStartRecording;
  final VoidCallback? onFinishRecording;
  final VoidCallback? onCancelRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickVideo;
  final String hintText;
  final TextStyle? inputTextStyle;
  final TextStyle? hintTextStyle;
  final Color? fieldBackgroundColor;
  final EdgeInsetsGeometry? fieldContentPadding;
  final String attachmentSheetTitle;
  final List<MessengerAttachmentOption>? attachmentOptions;
  final TextStyle? attachmentOptionTextStyle;
  final String? typingConversationId;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;
  final List<MessengerPickedMedia> pendingAttachments;
  final ValueChanged<int>? onRemovePendingAttachment;
  final VoidCallback? onClearAllPendingAttachments;
  final MessengerComposerReplyDraft? replyDraft;
  final VoidCallback? onCancelReplyDraft;
  final FocusNode? textFieldFocusNode;
}

typedef MessengerComposerBuilder = Widget Function(
  BuildContext context,
  MessengerComposerData data,
);

/// Data for a floating overlay in the conversation message viewport.
class MessengerThreadOverlayData {
  const MessengerThreadOverlayData({
    required this.conversation,
    required this.bounds,
    this.defaultTopOffset = 5,
  });

  final MessengerConversation? conversation;
  final Size bounds;
  final double defaultTopOffset;
}

typedef MessengerThreadOverlayBuilder = Widget Function(
  BuildContext context,
  MessengerThreadOverlayData data,
);

/// Optional overrides for conversation thread UI pieces.
///
/// When every field is null, the package renders its built-in defaults.
class MessengerThreadViewOverrides {
  const MessengerThreadViewOverrides({
    this.headerBuilder,
    this.messageBubbleBuilder,
    this.messageContentBuilders,
    this.composerBuilder,
    this.threadOverlayBuilder,
    this.threadOverlayTopOffset = 5,
  });

  final MessengerThreadHeaderBuilder? headerBuilder;
  final MessengerMessageBubbleBuilder? messageBubbleBuilder;
  final MessengerMessageContentBuilders? messageContentBuilders;
  final MessengerComposerBuilder? composerBuilder;
  final MessengerThreadOverlayBuilder? threadOverlayBuilder;
  final double threadOverlayTopOffset;
}
