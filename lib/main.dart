
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences';
import 'package:lottie/lottie.dart';
import 'package:animations/animations.dart';
import 'dart:math';

import 'package:aura_music_player/audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

// For overlay window (if needed, might require platform-specific setup)
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioPlayer = AudioPlayer();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.aura_music_player.channel.audio',
      androidNotificationChannelName: 'Aura Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const AuraMusicPlayerApp());
}

class AuraMusicPlayerApp extends StatelessWidget {
  const AuraMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Music Player',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color _backgroundColor = Colors.black;
  final List<Color> _backgroundColors = [
    Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal
  ];
  int _currentColorIndex = 0;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    audioPlayer.playerStateStream.map((state) => state.playing).distinct().listen((playing) {
      if (playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
    audioPlayer.positionStream.listen((position) {
      // Simple beat sync: change color every 5 seconds of playback
      if (position.inSeconds % 5 == 0 && position.inSeconds != 0) {
        setState(() {
          _currentColorIndex = (_currentColorIndex + 1) % _backgroundColors.length;
          _backgroundColor = _backgroundColors[_currentColorIndex];
        });
      }
    });
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // For Android 13 and above, you can use Permission.audio
    // For older Android versions, use Permission.storage
    PermissionStatus status;
    if (Theme.of(context).platform == TargetPlatform.android && await Permission.audio.isGranted) {
      status = PermissionStatus.granted;
    } else {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
      _loadSongs();
    } else if (status.isDenied) {
      // Handle denied case
      _showPermissionDeniedDialog();
    } else if (status.isPermanentlyDenied) {
      // Handle permanently denied case
      openAppSettings();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permission Denied"),
          content: const Text("This app needs storage permission to play music. Please grant the permission in settings."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSongs() async {
    if (_hasPermission) {
      List<SongModel> songs = await _audioQuery.querySongs(sortType: null, orderType: OrderType.ASC, uriType: UriType.EXTERNAL);
      setState(() {
        _songs = songs;
      });
    }
  }

  void _playSong(SongModel song) async {
    try {
      await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      audioPlayer.play();
      audioHandler.customAction(
        'setMediaItem',
        {
          'mediaItem': {
            'id': song.id.toString(),
            'album': song.album,
            'title': song.title,
            'artist': song.artist,
            'duration': song.duration,
            'artUri': song.albumArtwork != null ? Uri.file(song.albumArtwork!).toString() : null,
          },
        },
      );
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Aura Music Player'),
      ),
      body: _hasPermission
          ? (_songs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<SequenceState?>(
                        stream: audioPlayer.sequenceStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          if (state?.currentSource == null) {
                            return const Center(child: Text("No song playing"));
                          }
                          final mediaItem = state!.currentSource!.tag as MediaItem;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RotationTransition(
                                turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                                  parent: _controller,
                                  curve: Curves.linear,
                                )),
                                child: QueryArtworkWidget(
                                  id: int.parse(mediaItem.id),
                                  type: ArtworkType.AUDIO,
                                  nullArtworkWidget: const Icon(Icons.music_note, size: 150),
                                  size: 250,
                                  artworkBorder: BorderRadius.circular(150),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(mediaItem.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text(mediaItem.artist ?? "Unknown Artist", style: const TextStyle(fontSize: 18)),
                            ],
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _songs.length,
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          return ListTile(
                            leading: QueryArtworkWidget(
                              id: song.id,
                              type: ArtworkType.AUDIO,
                              nullArtworkWidget: const Icon(Icons.music_note),
                            ),
                            title: Text(song.title),
                            subtitle: Text(song.artist ?? "Unknown Artist"),
                            onTap: () => _playSong(song),
                          );
                        },
                      ),
                    ),
                  ],
                ))
          : const Center(
              child: Text("Please grant storage permission to play music."),
            ),
      floatingActionButton: StreamBuilder<PlayerState>(
        stream: audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final processingState = playerState?.processingState;
          final playing = playerState?.playing;
          if (processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering) {
            return const CircularProgressIndicator();
          } else if (playing != true) {
            return FloatingActionButton(
              onPressed: audioPlayer.play,
              child: const Icon(Icons.play_arrow),
            );
          } else {
            return FloatingActionButton(
              onPressed: audioPlayer.pause,
              child: const Icon(Icons.pause),
            );
          }
        },
      ),
    );
  }
}
