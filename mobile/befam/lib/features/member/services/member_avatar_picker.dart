import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedMemberAvatar {
  const PickedMemberAvatar({
    required this.bytes,
    required this.fileName,
    this.contentType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

abstract interface class MemberAvatarPicker {
  Future<PickedMemberAvatar?> pickAvatar();
}

class ImagePickerMemberAvatarPicker implements MemberAvatarPicker {
  ImagePickerMemberAvatarPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedMemberAvatar?> pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (file == null) {
      return null;
    }

    return PickedMemberAvatar(
      bytes: await file.readAsBytes(),
      fileName: file.name,
      contentType: file.mimeType ?? 'image/jpeg',
    );
  }
}

MemberAvatarPicker createDefaultMemberAvatarPicker() {
  return ImagePickerMemberAvatarPicker();
}
