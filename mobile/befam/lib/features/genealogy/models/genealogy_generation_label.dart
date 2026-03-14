class GenealogyGenerationLabel {
  const GenealogyGenerationLabel({
    required this.absoluteGeneration,
    this.relativeLevel,
  });

  final int absoluteGeneration;
  final int? relativeLevel;

  String get compactLabel {
    if (relativeLevel == null) {
      return 'G$absoluteGeneration';
    }

    final signedRelative = relativeLevel! >= 0
        ? '+$relativeLevel'
        : '$relativeLevel';
    return 'G$absoluteGeneration • R$signedRelative';
  }
}
