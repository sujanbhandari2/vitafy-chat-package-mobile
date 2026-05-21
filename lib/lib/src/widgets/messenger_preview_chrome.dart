import 'package:flutter/material.dart';

/// Shows a snackbar above the preview overlay (not behind the dialog route).
void showMessengerPreviewSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}

/// Shared top bar for full-screen media/document preview dialogs.
class MessengerPreviewChrome extends StatelessWidget {
  const MessengerPreviewChrome({
    super.key,
    required this.title,
    required this.onClose,
    required this.onDownload,
    this.isDownloading = false,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Close',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: isDownloading ? null : onDownload,
              icon: isDownloading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              tooltip: isDownloading ? 'Downloading' : 'Download',
            ),
          ),
        ],
      ),
    );
  }
}
