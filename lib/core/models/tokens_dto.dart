class TokensDto {
  final String accessToken;
  final String refreshToken;

  /// Mercure hub uchun alohida subscriber token (agar backend qaytarsa).
  /// API access token Mercure'ni ochmaydi - hub boshqa kalit bilan tekshiradi.
  final String? mercureToken;

  const TokensDto({
    required this.accessToken,
    required this.refreshToken,
    this.mercureToken,
  });

  factory TokensDto.fromJson(Map<String, dynamic> json) => TokensDto(
        accessToken: (json['accessToken'] ?? '') as String,
        refreshToken: (json['refreshToken'] ?? '') as String,
        mercureToken: (json['mercureToken'] ??
                json['mercure'] ??
                json['mercureAuthorization'] ??
                json['hubToken'])
            ?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'mercureToken': mercureToken,
      };
}
