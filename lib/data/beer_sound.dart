import 'package:flutter/services.dart';

/// Must match `BeerSound.CHANNEL` in Kotlin.
const String kSoundChannel = 'com.shakedash.beercount/sound';

/// Plays the "beer logged" sound. The rotation lives on the Kotlin side so
/// the app and the home-screen widget advance the same cursor.
abstract interface class BeerSound {
  Future<void> play();
}

class NoopBeerSound implements BeerSound {
  const NoopBeerSound();

  @override
  Future<void> play() async {}
}

class PlatformBeerSound implements BeerSound {
  const PlatformBeerSound();

  static const MethodChannel _channel = MethodChannel(kSoundChannel);

  /// A missing or broken sound must never stop a beer from being logged.
  @override
  Future<void> play() async {
    try {
      await _channel.invokeMethod<void>('play');
    } on Object {
      // Stay silent.
    }
  }
}
