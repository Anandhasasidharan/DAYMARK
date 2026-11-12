import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

Future<bool> saveTextFile(String contents, String name) async {
  if (!Platform.isWindows)
    throw UnsupportedError('Use clipboard export on this device.');
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    Uint8List.fromList(utf8.encode(contents)),
    name: name,
  ).saveTo(location.path);
  return true;
}

Future<String?> openBackupFile() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'LifeOS backup', extensions: ['json']),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 25 * 1024 * 1024)
    throw const FormatException('Backup exceeds 25 MB.');
  return file.readAsString();
}

/// Store a small local thumbnail rather than retaining a large original image.
Future<String?> selectPhotoThumbnail() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Photo', extensions: ['png', 'jpg', 'jpeg', 'webp']),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 10 * 1024 * 1024)
    throw const FormatException('Choose an image smaller than 10 MB.');
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final largest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final ratio = largest > 320 ? 320 / largest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * ratio).round().clamp(1, 320).toInt(),
        targetHeight: (descriptor.height * ratio).round().clamp(1, 320).toInt(),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null || data.lengthInBytes > 420000)
            throw const FormatException('Could not create a small photo.');
          return base64Encode(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
