import 'package:flutter/services.dart';

/// Must match `DocumentFiles.CHANNEL` in Kotlin.
const String kFilesChannel = 'com.shakedash.beercount/files';

/// Android's system file dialogs, so a backup can be saved to and read from
/// anywhere the user picks (Downloads, Drive) without a storage permission.
abstract interface class DocumentFiles {
  /// Returns false when the user backs out of the dialog.
  Future<bool> save(String fileName, String contents);

  /// Returns null when the user backs out of the dialog.
  Future<String?> open();
}

class PlatformDocumentFiles implements DocumentFiles {
  const PlatformDocumentFiles();

  static const MethodChannel _channel = MethodChannel(kFilesChannel);

  @override
  Future<bool> save(String fileName, String contents) async =>
      await _channel.invokeMethod<bool>(
        'save',
        <String, String>{'name': fileName, 'contents': contents},
      ) ??
      false;

  @override
  Future<String?> open() => _channel.invokeMethod<String>('open');
}
