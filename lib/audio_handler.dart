
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart'; // Required for MediaItem.artUri to be Uri.file

// Define a global audio player instance
late AudioPlayer _audioPlayer;

// Define a global AudioHandler for background playback
late AudioHandler _audioHandler;

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  static final _item = MediaItem(
    id: 'audio_id',
    album: 'Unknown Album',
    title: 'Unknown Title',
    artist: 'Unknown Artist',
    duration: Duration.zero,
  );

  MyAudioHandler() {
    _audioPlayer.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _getAudioProcessingState(playerState.processingState),
        playing: playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
        speed: _audioPlayer.speed,
        queueIndex: _audioPlayer.currentIndex,
      ));
    });
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null) {
        mediaItem.add(sequenceState.currentSource?.tag as MediaItem?);
      }
    });
  }

  AudioProcessingState _getAudioProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() => _audioPlayer.play();

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  @override
  Future<void> setSpeed(double speed) => _audioPlayer.setSpeed(speed);

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'setMediaItem') {
      final mediaItemMap = extras!['mediaItem'] as Map<String, dynamic>;
      final mediaItem = MediaItem(
        id: mediaItemMap['id'] as String,
        album: mediaItemMap['album'] as String?,
        title: mediaItemMap['title'] as String,
        artist: mediaItemMap['artist'] as String?,
        duration: Duration(milliseconds: mediaItemMap['duration'] as int),
        artUri: mediaItemMap['artUri'] != null ? Uri.parse(mediaItemMap['artUri'] as String) : null,
      );
      this.mediaItem.add(mediaItem);
    }
  }
}
