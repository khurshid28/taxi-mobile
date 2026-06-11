import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _initialized = false;

  // Load sound settings from storage
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // lowLatency (Android'da SoundPool) — qisqa ovozlar uchun yengil va
      // tez. MediaPlayer'dan farqli ravishda UI'ni qotirib qo'ymaydi.
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      _initialized = true;
    } catch (_) {}
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  bool get isSoundEnabled => _soundEnabled;

  // Umumiy yengil ijro: stop()+play() o'rniga to'g'ridan-to'g'ri play().
  // lowLatency rejimida play() har safar ovozni boshidan ijro etadi.
  Future<void> _play(String asset) async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource(asset));
    } catch (e) {
      // ignore: avoid_print
      print('Error playing sound: $e');
    }
  }

  // Play notification sound for new order
  Future<void> playNewOrderSound() => _play('sounds/new_order.ogg');

  // Play notification sound for order accepted
  Future<void> playOrderAcceptedSound() => _play('sounds/order_accepted.mp3');

  // Play notification sound for arriving at destination
  Future<void> playArrivingSound() => _play('sounds/arriving.mp3');

  // Play success sound for completed trip
  Future<void> playSuccessSound() => _play('sounds/success.mp3');

  void dispose() {
    _audioPlayer.dispose();
  }
}
