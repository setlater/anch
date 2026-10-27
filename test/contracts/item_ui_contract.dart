class ItemUIContract {
  final String title;
  final String subtitle;
  final bool hasBadges;
  final bool hasHighlight;
  final bool hasEmptyState;
  final String emptyStateType;

  const ItemUIContract({
    required this.title,
    required this.subtitle,
    required this.hasBadges,
    required this.hasHighlight,
    required this.hasEmptyState,
    required this.emptyStateType,
  });
}
