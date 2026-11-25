import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';

/// Asks whether to use the gallery or the camera, then returns the chosen
/// photos (empty if the person backed out).
Future<List<XFile>> pickPhotos(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return [];

  final picker = ImagePicker();
  if (source == ImageSource.camera) {
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    return shot == null ? [] : [shot];
  }
  return picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
}
