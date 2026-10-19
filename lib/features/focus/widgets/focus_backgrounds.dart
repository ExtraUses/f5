import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/widgets/focus_video_scene.dart';
import 'package:streak/features/focus/widgets/linux_video_scene.dart';

const focusSceneAssets = <String>[
  'assets/backgrounds/night_city.jpg',
  'assets/backgrounds/street_lamp.jpg',
  'assets/backgrounds/lantern_tree.jpg',
  'assets/backgrounds/frog_pond.jpg',
  'assets/backgrounds/valley_river.jpg',
  'assets/backgrounds/forest_cabin.jpg',
];

const focusSceneCount = 7;
const kCustomScene = focusSceneCount;
const kFirstVideoScene = focusSceneCount + 1;

int get defaultFocusScene => hasVideoScenes ? kFirstVideoScene : 3;

int videoSceneIndex(int scene) {
  final index = scene - kFirstVideoScene;
  if (!hasVideoScenes || index < 0 || index >= focusVideoScenes.length) {
    return -1;
  }
  return index;
}

class FocusBackground extends StatelessWidget {
  const FocusBackground({
    super.key,
    required this.scene,
    required this.imagePath,
    required this.child,
    this.thumbnail = false,
  });

  final int scene;
  final String imagePath;
  final Widget child;
  final bool thumbnail;

  ImageProvider _sized(BuildContext context, ImageProvider image) {
    final media = MediaQuery.of(context);
    final side = thumbnail
        ? 320
        : (media.size.longestSide * media.devicePixelRatio * 1.35).round();
    return ResizeImage(
      image,
      width: side,
      height: side,
      policy: ResizeImagePolicy.fit,
    );
  }

  Widget _video(File file, Widget poster) => Platform.isLinux
      ? LinuxVideoScene(file: file, poster: poster)
      : FocusVideoScene(file: file, poster: poster);

  @override
  Widget build(BuildContext context) {
    final hasImage = scene == kCustomScene &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync();

    if (hasImage && isFocusVideo(imagePath)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail)
            const FocusVideoTile()
          else
            _video(File(imagePath), const ColoredBox(color: Colors.black)),
          ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          child,
        ],
      );
    }

    if (hasImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: _sized(context, FileImage(File(imagePath))),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          child,
        ],
      );
    }

    final video = videoSceneIndex(scene);
    if (video >= 0) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _video(
            focusVideoFile(focusVideoScenes[video]),
            FocusVideoPoster(name: focusVideoScenes[video]),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          child,
        ],
      );
    }

    final index = scene - 1;
    if (index < 0 || index >= focusSceneAssets.length) {
      return ColoredBox(color: Colors.black, child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: _sized(context, AssetImage(focusSceneAssets[index])),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
        child,
      ],
    );
  }
}

class FocusScenePreview extends StatelessWidget {
  const FocusScenePreview({
    super.key,
    required this.scene,
    required this.imagePath,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final int scene;
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final video = videoSceneIndex(scene);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.app_background,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedScale(
          scale: selected ? 1 : 0.94,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AspectRatio(
          aspectRatio: 0.78,
          child: Container(
            padding: EdgeInsets.all(selected ? 2.5 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : scene == 0
                  ? Border.all(color: Colors.white.withValues(alpha: 0.18))
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 12 : 14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video >= 0) ...[
                    FocusVideoPoster(name: focusVideoScenes[video]),
                    ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
                  ] else
                    FocusBackground(
                      scene: scene,
                      imagePath: imagePath,
                      thumbnail: true,
                      child: const SizedBox.expand(),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class FocusVideoTile extends StatelessWidget {
  const FocusVideoTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1C1C22),
      child: Center(
        child: Icon(LucideIcons.clapperboard, size: 22, color: Colors.white70),
      ),
    );
  }
}
