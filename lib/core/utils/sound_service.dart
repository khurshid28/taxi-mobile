import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;

  // Load sound settings from storage
  Future<void> initialize() async {
    // You can load settings from SharedPreferences here
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  bool get isSoundEnabled => _soundEnabled;

  // Play notification sound for new order
  Future<void> playNewOrderSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/new_order.ogg'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Play notification sound for order accepted
  Future<void> playOrderAcceptedSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/order_accepted.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Play notification sound for arriving at destination
  Future<void> playArrivingSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/arriving.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Play success sound for completed trip
  Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
