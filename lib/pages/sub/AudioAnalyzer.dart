import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../utils/AudioInspector.dart';

class AudioAnalyzer extends StatefulWidget {
  @override
  _AudioAnalyzerState createState() => _AudioAnalyzerState();
}

class _AudioAnalyzerState extends State<AudioAnalyzer> with SingleTickerProviderStateMixin {
  final String _audioPath = 'W:/ZØMB - HOTLINE (SLOWED) (2).wav';
  double? _bpm;
  List<double> _sections = [];
  double _duration = 0.0;
  double _currentPosition = 0.0;
  bool _isAnalyzing = false;
  bool _isPlaying = false;
  String _status = 'Ready';
  final int _sampleRate = 44100;
  final soloud = SoLoud.instance;
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _positionTimer;

  AnalysisResult? _analysis;

  List<double> _beatTimes = [];
  List<double> _percussiveOnsets = [];
  List<double> _harmonicOnsets = [];

  Map<String, List<Event>> _eventsByType = {};

  List<double> _minWave = [];
  List<double> _maxWave = [];


  Map<String, List<double>> _soundEvents = {};

  late AnimationController _beatAnimController;
  late Animation<double> _beatScale;
  late Animation<double> _beatOpacity;

  @override
  void initState() {
    super.initState();
    _beatAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _beatScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _beatAnimController, curve: Curves.easeOut),
    );

    _beatOpacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _beatAnimController, curve: Curves.easeOut),
    );

    _initializeSoloud();
  }

  Future<void> _initializeSoloud() async {
    //await soloud.init(sampleRate: _sampleRate);
  }

  Future<void> _analyzeAndLoad() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Load source so playback works
      _source = await soloud.loadFile(_audioPath, mode: LoadMode.disk);

      final inspector = AudioInspector(
        sampleRate: _sampleRate,
        soloud: SoLoud.instance,
      );

      final result = await inspector.analyzeFile(
        _audioPath,
        fftSize: 2048,
        hopSize: 512,
      );

      final totalSamples = (_sampleRate * result.duration).round();

      final pcm = await SoLoud.instance.readSamplesFromFile(
        _audioPath,
        totalSamples,
        startTime: 0,
        endTime: -1,
        average: true,
      );

      final samples = pcm.toList();
      final waveform = _downsampleForWaveform(samples, 2000);

      setState(() {
        _analysis = result;

        _duration = result.duration;
        _bpm = result.bpm;
        _sections = result.sections;

        _beatTimes = result.beatTimes;
        _percussiveOnsets = result.percussiveOnsets;
        _harmonicOnsets = result.harmonicOnsets;

        _eventsByType = result.eventsByType;

        _minWave = waveform['min']!;
        _maxWave = waveform['max']!;

        _soundEvents = {
          for (final entry in _eventsByType.entries)
            entry.key: entry.value.map((e) => e.time).toList()
        };

        _status = 'Ready – BPM: ${_bpm?.toStringAsFixed(1)} • ${_duration.toStringAsFixed(1)} s';

        _isAnalyzing = false;
      });

    } catch (e, stack) {
      debugPrint('Analysis failed: $e');
      debugPrint(stack.toString());

      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _togglePlayback() async {
    if (_source == null) return;

    if (!_isPlaying) {
      if (_handle == null) {
        _handle = await soloud.play(_source!);
      } else {
        soloud.setPause(_handle!, false);
      }
      _startPositionTimer();
      setState(() => _isPlaying = true);
    } else {
      soloud.setPause(_handle!, true);
      _stopPositionTimer();
      setState(() => _isPlaying = false);
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 33), (_) async {
      if (_handle == null || !_isPlaying) return;

      final posDur = await soloud.getPosition(_handle!);
      final newPos = posDur.inMilliseconds / 1000.0;

      if (_shouldTriggerBeatFlash(_currentPosition, newPos)) {
        _beatAnimController.forward(from: 0.0);
      }

      setState(() => _currentPosition = newPos);

      if (_currentPosition >= _duration - 0.1) {
        _stopPlayback();
      }
    });
  }

  bool _shouldTriggerBeatFlash(double oldPos, double newPos) {
    if (_bpm == null || _bpm! < 40) return false;
    final beatInterval = 60 / _bpm!;
    final oldBeat = (oldPos / beatInterval).floor();
    final newBeat = (newPos / beatInterval).floor();
    return newBeat > oldBeat;
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _stopPlayback() async {
    if (_handle != null) {
      await soloud.stop(_handle!);
      _handle = null;
    }
    _stopPositionTimer();
    setState(() {
      _currentPosition = 0.0;
      _isPlaying = false;
    });
  }

  Future<void> _seekTo(double seconds) async {
    if (_handle == null || seconds < 0 || seconds > _duration) return;

    final dur = Duration(milliseconds: (seconds * 1000).round());
    soloud.seek(_handle!, dur);
    setState(() => _currentPosition = seconds);
  }

  double median(List<double> xs) {
    final copy = List<double>.from(xs)..sort();
    final n = copy.length;
    if (n == 0) return 0.0;
    if (n % 2 == 1) return copy[n ~/ 2];
    return 0.5 * (copy[n ~/ 2 - 1] + copy[n ~/ 2]);
  }

  double mad(List<double> xs, [double? xsMedian]) {
    if (xs.isEmpty) return 0.0;
    xsMedian ??= median(xs);
    final dev = xs.map((x) => (x - xsMedian!).abs()).toList();
    return median(dev);
  }

  Map<String, List<double>> _downsampleForWaveform(
      List<double> samples,
      int points,
      ) {
    if (samples.isEmpty || points <= 0) {
      return {'min': [], 'max': []};
    }

    final blockSize = samples.length / points;

    final minW = <double>[];
    final maxW = <double>[];

    for (int i = 0; i < points; i++) {
      final start = (i * blockSize).floor();
      final end = ((i + 1) * blockSize).floor().clamp(0, samples.length);

      if (start >= end) {
        minW.add(0);
        maxW.add(0);
        continue;
      }

      double peakMin = double.infinity;
      double peakMax = double.negativeInfinity;
      double rmsSum = 0;

      for (int j = start; j < end; j++) {
        final v = samples[j];
        peakMin = math.min(peakMin, v);
        peakMax = math.max(peakMax, v);
        rmsSum += v * v;
      }

      final rms = math.sqrt(rmsSum / (end - start));

      final blendedMax = 0.7 * rms + 0.3 * peakMax.abs();
      final blendedMin = -blendedMax;

      final shaped = math.log(1 + 9 * blendedMax) / math.log(10);

      minW.add(-shaped);
      maxW.add(shaped);
    }

    _smoothInPlace(minW, 2);
    _smoothInPlace(maxW, 2);

    return {'min': minW, 'max': maxW};
  }

  void _smoothInPlace(List<double> data, int radius) {
    if (data.length < 3) return;

    final copy = List<double>.from(data);
    for (int i = 0; i < data.length; i++) {
      double sum = 0;
      int count = 0;

      for (int r = -radius; r <= radius; r++) {
        final idx = i + r;
        if (idx >= 0 && idx < data.length) {
          sum += copy[idx];
          count++;
        }
      }

      data[i] = sum / count;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Analyzer + Beat Flash')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isAnalyzing || _source != null ? null : _analyzeAndLoad,
                  child: const Text('Load & Analyze'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _source == null ? null : _togglePlayback,
                  child: Text(_isPlaying ? 'Pause' : 'Play'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_status, style: const TextStyle(fontSize: 16)),
          ),
          if (_minWave.isNotEmpty)
            SizedBox(
              height: 150,
              child: GestureDetector(
                onTapDown: (d) {
                  final w = context.size!.width;
                  final sec = (d.localPosition.dx / w) * _duration;
                  _seekTo(sec);
                },
                child: AnimatedBuilder(
                  animation: _beatAnimController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WaveformPainter(
                        minWave: _minWave,
                        maxWave: _maxWave,
                        sections: _sections,
                        bpm: _bpm ?? 120,
                        duration: _duration,
                        position: _currentPosition,
                        beatScale: _beatScale.value,
                        beatOpacity: _beatOpacity.value,
                        soundEvents: _soundEvents,
                        eventsByType: _eventsByType
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          if (_sections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sections: ${_sections.map((s) => s.toStringAsFixed(1)).join(', ')} s',
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _beatAnimController.dispose();
    if (_handle != null) soloud.stop(_handle!);
    if (_source != null) soloud.disposeSource(_source!);
    _stopPositionTimer();
    soloud.deinit();
    super.dispose();
  }
}

enum WaveformStyle { filled, bars }

class WaveformPainter extends CustomPainter {
  final List<double> minWave;
  final List<double> maxWave;
  final List<double> sections;
  final double bpm;
  final double duration;
  final double position;
  final double beatScale;
  final double beatOpacity;
  final WaveformStyle style;
  final Color primaryColor;
  final Color accentColor;
  final bool showCenterLine;
  final bool showTimeRuler;
  final int timeRulerStepSec;
  final int subdivisions;

  final Map<String, List<double>> soundEvents;
  final Map<String, List<Event>> eventsByType;

  WaveformPainter({
    required this.minWave,
    required this.maxWave,
    required this.sections,
    required this.bpm,
    required this.duration,
    required this.position,
    required this.beatScale,
    required this.beatOpacity,
    this.style = WaveformStyle.filled,
    this.primaryColor = const Color(0xFF4A90E2),
    this.accentColor = const Color(0xFFFF6B6B),
    this.showCenterLine = true,
    this.showTimeRuler = true,
    this.timeRulerStepSec = 10,
    this.subdivisions = 0,
    this.soundEvents = const {},
    this.eventsByType = const {}
  }) : assert(minWave.length == maxWave.length,
  'minWave and maxWave must have same length');

  @override
  void paint(Canvas canvas, Size size) {
    if (minWave.isEmpty || maxWave.isEmpty) return;

    final devicePixelRatio = (WidgetsBinding.instance.window.devicePixelRatio);
    canvas.save();
    canvas.scale(1 / devicePixelRatio);

    final w = size.width * devicePixelRatio;
    final h = size.height * devicePixelRatio;
    final centerY = h / 2;

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.02);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final int points = minWave.length;
    final double step = math.max(1.0, points / w);
    final int displayedPoints = (points / step).ceil();

    final topPoints = <Offset>[];
    final bottomPoints = <Offset>[];

    for (int i = 0; i < displayedPoints; i++) {
      final idx = (i * step).floor().clamp(0, points - 1);
      final x = (i / (displayedPoints - 1).clamp(1, double.infinity)) * w;
      final maxv = maxWave[idx].clamp(-1.0, 1.0);
      final minv = minWave[idx].clamp(-1.0, 1.0);
      final yTop = centerY - (maxv * (h / 2));
      final yBottom = centerY - (minv * (h / 2));
      topPoints.add(Offset(x, yTop));
      bottomPoints.add(Offset(x, yBottom));
    }

    final grad = LinearGradient(
      colors: [
        primaryColor.withOpacity(0.95),
        primaryColor.withOpacity(0.6),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final waveformPaint = Paint()
      ..shader = grad.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = style == WaveformStyle.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.0 * devicePixelRatio
      ..isAntiAlias = true;

    if (style == WaveformStyle.filled) {
      final path = Path();
      if (topPoints.isNotEmpty) {
        path.moveTo(topPoints.first.dx, topPoints.first.dy);
        for (int i = 0; i < topPoints.length - 1; i++) {
          final p0 = topPoints[i];
          final p1 = topPoints[i + 1];
          final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
        final lastTop = topPoints.last;
        path.lineTo(lastTop.dx, lastTop.dy);
      }

      if (bottomPoints.isNotEmpty) {
        for (int i = bottomPoints.length - 1; i >= 0; i--) {
          final p = bottomPoints[i];
          path.lineTo(p.dx, p.dy);
        }
      }

      path.close();
      canvas.drawPath(path, waveformPaint);

      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 * devicePixelRatio
        ..color = primaryColor.withOpacity(0.9);
      canvas.drawPath(path, outline);
    } else {
      final barPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = primaryColor.withOpacity(0.9);
      final barWidth = math.max(1.0, w / displayedPoints * 0.7);
      for (int i = 0; i < topPoints.length; i++) {
        final x = topPoints[i].dx;
        final topY = topPoints[i].dy;
        final bottomY = bottomPoints[i].dy;
        canvas.drawRect(Rect.fromLTRB(x - barWidth / 2, topY, x + barWidth / 2, bottomY), barPaint);
      }
    }

    if (showCenterLine) {
      final centerPaint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..strokeWidth = 1.0 * devicePixelRatio;
      canvas.drawLine(Offset(0, centerY), Offset(w, centerY), centerPaint);
    }

    final sectionLinePaint = Paint()
      ..color = accentColor.withOpacity(0.9)
      ..strokeWidth = 1.2 * devicePixelRatio;

    for (int i = 0; i < sections.length; i++) {
      final s = sections[i];
      if (s <= 0 || s >= duration) continue;
      final x = (s / duration) * w;
      canvas.drawLine(Offset(x, 0), Offset(x, h), sectionLinePaint);
      final textPainter = TextPainter(
          text: TextSpan(
              text: _formatTime(s),
              style: TextStyle(fontSize: 10 * devicePixelRatio, color: accentColor.withOpacity(0.9))),
          textDirection: TextDirection.ltr)
        ..layout();
      textPainter.paint(canvas, Offset(x + 4, 4));
    }

    if (bpm > 0 && duration > 0) {
      final double beatSec = 60.0 / bpm;
      final tickPaint = Paint()
        ..color = Colors.white.withAlpha(25)
        ..strokeWidth = 1.0 * devicePixelRatio;

      for (double t = 0.0; t < duration; t += beatSec / (subdivisions + 1)) {
        final x = (t / duration) * w;
        canvas.drawLine(Offset(x, h * 0.02), Offset(x, h * 0.98), tickPaint);
      }
    }

    if (position >= 0 && position <= duration) {
      final x = (position / duration) * w;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withOpacity(0.18 * beatOpacity),
            primaryColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, centerY), radius: 60 * beatScale * devicePixelRatio))
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(x, centerY), 60 * beatScale * devicePixelRatio, glowPaint);

      double sW = 2.2 * beatScale * devicePixelRatio;
      final playheadPaint = Paint()
        ..color = primaryColor.withOpacity(0.98)
        ..strokeWidth = 2.2 * beatScale * devicePixelRatio
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - sW/2, 0), Offset(x - sW/2, h), playheadPaint);
    }

    final colors = {
      'Kick/Bass': Colors.red,
      'Snare/Clap': Colors.orange,
      'Hi-hat/Cymbal': Colors.cyan,
      'Melodic': Colors.green,
    };
    final yPositions = List<double>.generate(soundEvents.length, (i) => h * (i + 1) / (soundEvents.length + 1));

    int idx = 0;
    soundEvents.forEach((label, times) {
      final color = colors[label] ?? Colors.grey;
      double yPos = yPositions[idx++];
      _drawSoundMarkers(canvas, w, h, times, color, yPos, eventsByType[label]!);
    });

    canvas.restore();
  }

  void _drawSoundMarkers(Canvas canvas, double w, double h, List<double> times, Color color, double yPos, List<Event> events) {
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final radiusBase = 4.0;
    final pulseDuration = 0.2;

    for (var i = 0; i < times.length; i++) {
      var t = times[i];
      if (t < 0 || t > duration) continue;
      final x = (t / duration) * w;

      final distance = position - t;
      double scale = 1.0;
      double glowOpacity = 0.0;
      double glowRadius = 0.0;

      if (distance >= 0 && distance <= pulseDuration) {
        final progress = distance / pulseDuration;
        scale = 1.0 + 0.6 * (1.0 - progress);
        glowOpacity = (1.0 - progress) * 0.4;
        glowRadius = radiusBase * (1.0 + 3 * (1.0 - progress));
      }

      Event e = events[i];
      double mult = 0;
      if (e.label == 'Melodic') {
        final pc = e.features['pitchClass'] ?? 0;
        mult = (pc*3).toDouble();
      }

      if (glowOpacity > 0) {
        final glowPaint = Paint()
          ..color = color.withOpacity(glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(x, yPos + mult), glowRadius, glowPaint);
      }

      final radius = radiusBase * scale;
      canvas.drawCircle(Offset(x, yPos + mult), radius, markerPaint);
    }
  }

  String _formatTime(double seconds) {
    final s = seconds.round();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.minWave != minWave ||
        oldDelegate.maxWave != maxWave ||
        oldDelegate.sections != sections ||
        oldDelegate.bpm != bpm ||
        oldDelegate.duration != duration ||
        oldDelegate.position != position ||
        oldDelegate.beatScale != beatScale ||
        oldDelegate.beatOpacity != beatOpacity ||
        oldDelegate.style != style ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showCenterLine != showCenterLine ||
        oldDelegate.showTimeRuler != showTimeRuler ||
        oldDelegate.timeRulerStepSec != timeRulerStepSec ||
        oldDelegate.subdivisions != subdivisions ||
        oldDelegate.soundEvents != soundEvents;
  }
}