enum ArcVisualAssetType { png, rive, glb }

class ArcVisualAsset {
  const ArcVisualAsset({
    required this.type,
    required this.path,
    required this.semanticLabel,
  });

  final ArcVisualAssetType type;
  final String path;
  final String semanticLabel;

  bool get isPng => type == ArcVisualAssetType.png;
}
