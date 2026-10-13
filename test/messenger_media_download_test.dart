import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  tearDown(() {
    messengerDownloadsDirectoryOverride = null;
  });

  test('copies a local file into the downloads directory', () async {
    final sourceDir = await Directory.systemTemp.createTemp('messenger_src_');
    final targetDir = await Directory.systemTemp.createTemp('messenger_dst_');
    final source = File('${sourceDir.path}/sample.txt');
    await source.writeAsString('download me');

    messengerDownloadsDirectoryOverride = () => targetDir;

    addTearDown(() async {
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
    });

    final result = await messengerDownloadMedia(
      context: _FakeDownloadContext(),
      source: source.path,
      fileName: 'sample.txt',
    );

    expect(result.success, isTrue);
    expect(result.savedPath, isNotEmpty);
    expect(File(result.savedPath!).readAsStringSync(), 'download me');
  });
}

class _FakeDownloadContext extends FakeBuildContext {}

class FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
