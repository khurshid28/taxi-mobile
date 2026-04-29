class TokensDto {
  final String accessToken;
  final String refreshToken;

  const TokensDto({
    required this.accessToken,
    required this.refreshToken,
  });

  factory TokensDto.fromJson(Map<String, dynamic> json) => TokensDto(
        accessToken: (json['accessToken'] ?? '') as String,
        refreshToken: (json['refreshToken'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}
