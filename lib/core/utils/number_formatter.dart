class NumberFormatter {
  static String formatPrice(num price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        )
        .trim();
  }

  static String formatPriceWithCurrency(num price) {
    return '${formatPrice(price)} so\'m';
  }

  static String formatDistance(double distance) {
    return distance.toStringAsFixed(2);
  }
}
