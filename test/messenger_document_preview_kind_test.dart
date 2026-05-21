import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  group('messengerDocumentPreviewKind', () {
    test('detects pdf from mime and extension', () {
      expect(
        messengerDocumentPreviewKind(mimeType: 'application/pdf'),
        MessengerDocumentPreviewKind.pdf,
      );
      expect(
        messengerDocumentPreviewKind(fileName: 'report.pdf'),
        MessengerDocumentPreviewKind.pdf,
      );
    });

    test('detects text from mime and extension', () {
      expect(
        messengerDocumentPreviewKind(mimeType: 'text/plain'),
        MessengerDocumentPreviewKind.text,
      );
      expect(
        messengerDocumentPreviewKind(fileName: 'notes.txt'),
        MessengerDocumentPreviewKind.text,
      );
      expect(
        messengerDocumentPreviewKind(fileName: 'data.json'),
        MessengerDocumentPreviewKind.text,
      );
    });

    test('detects pdf from octet-stream when filename ends with .pdf', () {
      expect(
        messengerDocumentPreviewKind(
          mimeType: 'application/octet-stream',
          fileName: 'report.pdf',
        ),
        MessengerDocumentPreviewKind.pdf,
      );
    });

    test('marks office formats as unsupported', () {
      expect(
        messengerDocumentPreviewKind(fileName: 'budget.xlsx'),
        MessengerDocumentPreviewKind.unsupported,
      );
      expect(
        messengerDocumentPreviewKind(fileName: 'brief.docx'),
        MessengerDocumentPreviewKind.unsupported,
      );
    });
  });

  group('messengerBytesLookLikePdf', () {
    test('detects PDF magic header', () {
      expect(
        messengerBytesLookLikePdf([0x25, 0x50, 0x44, 0x46, 0x2D]),
        isTrue,
      );
      expect(
        messengerSniffPreviewKindFromBytes([0x25, 0x50, 0x44, 0x46]),
        MessengerDocumentPreviewKind.pdf,
      );
      expect(
        messengerBytesLookLikePdf('<html'.codeUnits),
        isFalse,
      );
    });
  });

  group('messengerIsImageMedia', () {
    test('detects images by mime and extension', () {
      expect(
        messengerIsImageMedia(
          mimeType: 'image/png',
          source: 'https://cdn.example.com/x',
        ),
        isTrue,
      );
      expect(
        messengerIsImageMedia(
          source: 'https://cdn.example.com/photo.jpeg',
        ),
        isTrue,
      );
      expect(
        messengerIsImageMedia(
          source: 'https://cdn.example.com/report.pdf',
        ),
        isFalse,
      );
    });
  });

  group('messengerMediaDownloadFileName', () {
    test('prefers explicit file name', () {
      expect(
        messengerMediaDownloadFileName(
          fileName: ' Lab Report.pdf ',
          source: 'https://cdn.example.com/x',
        ),
        'Lab Report.pdf',
      );
    });

    test('falls back to url segment', () {
      expect(
        messengerMediaDownloadFileName(
          source: 'https://cdn.example.com/uploads/report.pdf',
        ),
        'report.pdf',
      );
    });
  });
}
