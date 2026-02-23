
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart'; // Required for MediaItem.artUri to be Uri.file

// Define a global audio player instance
late AudioPlayer audioPlayer;

// Define a global AudioHandler for background playback
late AudioHandler audioHandler;

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  static final _item = MediaItem(
    id: 'audio_id',
    album: 'Unknown Album',
    title: 'Unknown Title',
    artist: 'Unknown Artist',
    duration: Duration.zero,
  );

  MyAudioHandler() {
    audioPlayer.playerStateStream.listen((playerState) {
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
        updatePosition: audioPlayer.position,
        bufferedPosition: audioPlayer.bufferedPosition,
        speed: audioPlayer.speed,
        queueIndex: audioPlayer.currentIndex,
      ));
    });
    audioPlayer.sequenceStateStream.listen((sequenceState) {
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
  Future<void> play() => audioPlayer.play();

  @override
  Future<void> pause() => audioPlayer.pause();

  @override
  Future<void> stop() async {
    await audioPlayer.stop();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  @override
  Future<void> setSpeed(double speed) => audioPlayer.setSpeed(speed);

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
