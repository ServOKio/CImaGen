import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
class AnalysisResult {
  final double duration;
  final double bpm;
  final List<double> beatTimes;
  final List<double> percussiveOnsets;
  final List<double> harmonicOnsets;
  final Map<String, List<Event>> eventsByType;
  final List<double> sections;
  final List<double> loudnessTimeline;
  final List<double> chromaSummary;
  final Map<String, dynamic> diagnostics;
  AnalysisResult({
    required this.duration,
    required this.bpm,
    required this.beatTimes,
    required this.percussiveOnsets,
    required this.harmonicOnsets,
    required this.eventsByType,
    required this.sections,
    required this.loudnessTimeline,
    required this.chromaSummary,
    required this.diagnostics,
  });
}
class Event {
  final double time;
  final String label;
  final double confidence;
  final Map<String, dynamic> features;
  Event({
    required this.time,
    required this.label,
    required this.confidence,
    required this.features,
  });
}
class AudioInspector {
  final int sampleRate;
  final SoLoud soloud;
  AudioInspector({this.sampleRate = 44100, required this.soloud});
  Future<AnalysisResult> analyzeFile(String path, {int fftSize = 2048, int hopSize = 512, bool verbose = false}) async {
    final dur = soloud.getLength(await soloud.loadFile(path, mode: LoadMode.disk));
    final durationSec = dur.inMilliseconds / 1000.0;
    final totalSamples = (durationSec * sampleRate).round();
    final pcm = await soloud.readSamplesFromFile(path, totalSamples, startTime: 0, endTime: -1, average: true);
    final samples = pcm.toList();
    final int N = fftSize;
    final int H = hopSize;
    final int numFrames = ((samples.length - N) ~/ H) + 1;
    if (numFrames <= 0) {
      throw Exception('file too short or incorrect sampleRate/fftSize');
    }
    final window = _hannWindow(N);
    final FFT fft = FFT(N);
    final int bins = N ~/ 2 + 1;
    final spec = List.generate(numFrames, (_) => List<double>.filled(bins, 0.0));
    final phases = List.generate(numFrames, (_) => List<double>.filled(bins, 0.0));
    for (int f = 0; f < numFrames; f++) {
      final start = f * H;
      final chunk = Float64List(N);
      final end = math.min(start + N, samples.length);
      final slice = samples.sublist(start, end);
      for (int i = 0; i < slice.length; i++) chunk[i] = slice[i] * window[i];
      final spectrum = fft.realFft(chunk);
      final mag = spectrum.magnitudes();
      final ph = spectrum.phases();
      for (int b = 0; b < bins; b++) {
        spec[f][b] = mag[b];
        phases[f][b] = ph[b];
      }
    }
    final int harmonicMedianTime = (sampleRate / H * 0.2).round().clamp(3, 101);
    final int percussiveMedianFreq = (bins * 0.02).round().clamp(3, 101);
    final harmonicSpec = _medianFilterTime(spec, harmonicMedianTime);
    final percussiveSpec = _medianFilterFreq(spec, percussiveMedianFreq);
    final eps = 1e-8;
    final harmonicMask = List.generate(numFrames, (f) => List<double>.filled(bins, 0.0));
    final percussiveMask = List.generate(numFrames, (f) => List<double>.filled(bins, 0.0));
    final power = 1.0;
    for (int f = 0; f < numFrames; f++) {
      for (int b = 0; b < bins; b++) {
        final h = harmonicSpec[f][b];
        final p = percussiveSpec[f][b];
        final denom = (math.pow(h, power) + math.pow(p, power) + eps);
        harmonicMask[f][b] = math.pow(h, power) / denom;
        percussiveMask[f][b] = math.pow(p, power) / denom;
      }
    }
    final harmonicWeighted = List.generate(numFrames, (f) => List<double>.filled(bins, 0.0));
    final percussiveWeighted = List.generate(numFrames, (f) => List<double>.filled(bins, 0.0));
    for (int f = 0; f < numFrames; f++) {
      for (int b = 0; b < bins; b++) {
        harmonicWeighted[f][b] = spec[f][b] * harmonicMask[f][b];
        percussiveWeighted[f][b] = spec[f][b] * percussiveMask[f][b];
      }
    }
    final percussiveNovelty = _computeNoveltyCurve(percussiveWeighted, emphasizeHigh: true);
    final harmonicNovelty = _computeNoveltyCurve(harmonicWeighted, emphasizeHigh: false);
    final percussiveSmooth = _movingAverage(percussiveNovelty, 3);
    final harmonicSmooth = _movingAverage(harmonicNovelty, 3);
    final percussiveOnsets = _pickPeaksAdaptive(percussiveSmooth, numFrames, H, sampleRate,
        localWindow: 32, multiplier: 1.6, minIntervalSec: 0.05);
    final harmonicOnsets = _pickPeaksAdaptive(harmonicSmooth, numFrames, H, sampleRate,
        localWindow: 64, multiplier: 1.8, minIntervalSec: 0.08);
    final bpmEstimate = _estimateBpmFromSamples(samples, sampleRate);
    final beatTimes = _computeBeatGridFromBpmAndOnsets(bpmEstimate, percussiveOnsets, durationSec);
    final nyquist = sampleRate / 2;
    final binFreq = nyquist / (bins - 1);
    final lowNovelty = List<double>.filled(numFrames, 0.0);
    final midNovelty = List<double>.filled(numFrames, 0.0);
    final highNovelty = List<double>.filled(numFrames, 0.0);
    List<double> prevFrame = List<double>.filled(bins, 0.0);
    for (int f = 0; f < numFrames; f++) {
      for (int b = 0; b < bins; b++) {
        final diff = math.max(0.0, spec[f][b] - prevFrame[b]);
        final freq = b * binFreq;
        if (freq < 180) {
          lowNovelty[f] += diff;
        } else if (freq < 4000) {
          midNovelty[f] += diff;
        } else {
          highNovelty[f] += diff;
        }
        prevFrame[b] = spec[f][b];
      }
    }
    List<double> _zNorm(List<double> x) {
      if (x.isEmpty) return [];
      final mean = x.reduce((a, b) => a + b) / x.length;
      double vari = 0.0;
      for (final v in x) {
        vari += (v - mean) * (v - mean);
      }
      final std = math.sqrt(vari / x.length) + 1e-8;
      return x.map((v) => (v - mean) / std).toList();
    }
    final lowZ = _zNorm(lowNovelty);
    final midZ = _zNorm(midNovelty);
    final highZ = _zNorm(highNovelty);
    List<int> _pickPeaksZ(List<double> curve, double threshold, int minDistFrames) {
      final peaks = <int>[];
      int last = -9999;
      for (int i = 1; i < curve.length - 1; i++) {
        if (curve[i] > threshold && curve[i] > curve[i - 1] && curve[i] > curve[i + 1]) {
          if (i - last > minDistFrames) {
            peaks.add(i);
            last = i;
          }
        }
      }
      return peaks;
    }
    final minDistFrames = (0.08 * sampleRate / H).round();
    final kickFrames = _pickPeaksZ(lowZ, 1.2, minDistFrames);
    final snareFrames = _pickPeaksZ(midZ, 1.0, minDistFrames);
    final hatFrames = _pickPeaksZ(highZ, 1.3, (0.05 * sampleRate / H).round());
    bool _nearBeat(double time, List<double> beats, double tol) {
      for (final b in beats) {
        if ((b - time).abs() < tol) return true;
      }
      return false;
    }
    final eventsByType = <String, List<Event>>{
      'Kick/Bass': [],
      'Snare/Clap': [],
      'Hi-hat/Cymbal': [],
      'Melodic': [],
    };
    double _frameToSec(int f) => f * H / sampleRate.toDouble();
    double lastKick = -999;
    for (final fIdx in kickFrames) {
      final t = _frameToSec(fIdx);
      if (t - lastKick < 0.12) continue;
      lastKick = t;
      final conf = (lowZ[fIdx] + 3.0) / 4.0;
      eventsByType['Kick/Bass']!.add(Event(time: t, label: 'Kick/Bass', confidence: conf, features: {'z': lowZ[fIdx]}));
    }
    double lastSnare = -999;
    for (final fIdx in snareFrames) {
      final t = _frameToSec(fIdx);
      if (t - lastSnare < 0.12) continue;
      lastSnare = t;
      final conf = (midZ[fIdx] + 2.0) / 3.0;
      eventsByType['Snare/Clap']!.add(Event(time: t, label: 'Snare/Clap', confidence: conf, features: {'z': midZ[fIdx]}));
    }
    double lastHat = -999;
    final hatBeatTol = 0.09;
    for (final fIdx in hatFrames) {
      final t = _frameToSec(fIdx);
      if (!_nearBeat(t, beatTimes, hatBeatTol)) continue;
      if (t - lastHat < 0.06) continue;
      lastHat = t;
      final conf = (highZ[fIdx] + 2.0) / 4.0;
      eventsByType['Hi-hat/Cymbal']!.add(Event(time: t, label: 'Hi-hat/Cymbal', confidence: conf, features: {'z': highZ[fIdx]}));
    }
    final chromaPerFrame = _computeChromaFromSpectrogram(harmonicWeighted, sampleRate, bins);
    final avgChroma = List<double>.filled(12, 0.0);
    for (int f = 0; f < numFrames; f++) {
      for (int c = 0; c < 12; c++) avgChroma[c] += chromaPerFrame[f][c];
    }
    for (int c = 0; c < 12; c++) avgChroma[c] /= numFrames;
    if (chromaPerFrame.isEmpty) {
    } else {
      final smoothChroma = List.generate(numFrames, (_) => List<double>.filled(12, 0.0));
      final int smoothHalf = 1;
      for (int f = 0; f < numFrames; f++) {
        int start = math.max(0, f - smoothHalf);
        int end = math.min(numFrames - 1, f + smoothHalf);
        final count = (end - start + 1).toDouble();
        for (int c = 0; c < 12; c++) {
          double sum = 0.0;
          for (int k = start; k <= end; k++) sum += chromaPerFrame[k][c];
          smoothChroma[f][c] = sum / count;
        }
      }
      final chromaNovelty = List<double>.filled(numFrames, 0.0);
      for (int f = 1; f < numFrames; f++) {
        double nov = 0.0;
        for (int c = 0; c < 12; c++) {
          nov += math.max(0.0, smoothChroma[f][c] - smoothChroma[f - 1][c]);
        }
        chromaNovelty[f] = nov;
      }
      final chromaZ = _zNorm(chromaNovelty);
      final minDistFramesMelodic = (0.12 * sampleRate / H).round().clamp(1, 9999);
      final melodicFrames = _pickPeaksZ(chromaZ, 1.0, minDistFramesMelodic);
      final noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
      double lastMelodicTime = -9999.0;
      final melodicMinInterval = 0.10;
      for (final fIdx in melodicFrames) {
        final t = _frameToSec(fIdx);
        if (t - lastMelodicTime < melodicMinInterval) continue;
        final chromaVec = smoothChroma[fIdx];
        double maxCh = chromaVec.reduce(math.max);
        final harmonicEnergy = harmonicWeighted[fIdx].fold(0.0, (a, b) => a + b);
        final percussiveEnergy = percussiveWeighted[fIdx].fold(0.0, (a, b) => a + b);
        final harmonicity = harmonicEnergy / (harmonicEnergy + percussiveEnergy + eps);
        if (maxCh < 0.08 || harmonicity < 0.25) {
          continue;
        }
        double conf = (0.55 * (maxCh.clamp(0.0, 1.0)) + 0.45 * harmonicity);
        conf = (conf * 0.75) + 0.25;
        conf = conf.clamp(0.0, 1.0);
        int pc = 0;
        double best = -1.0;
        for (int c = 0; c < 12; c++) {
          if (chromaVec[c] > best) {
            best = chromaVec[c];
            pc = c;
          }
        }
        final pitchLabel = noteNames[pc];
        eventsByType['Melodic']!.add(Event(
          time: t,
          label: 'Melodic',
          confidence: conf,
          features: {
            'maxChroma': maxCh,
            'harmonicity': harmonicity,
            'pitchClass': pc,
            'pitchLabel': pitchLabel,
            'chromaZ': chromaZ[fIdx],
          },
        ));
        lastMelodicTime = t;
      }
    }
    final sections = detectSectionsSpectral(samples, sampleRate, frameSec: 4);
    final loudness = List<double>.filled(numFrames, 0.0);
    for (int f = 0; f < numFrames; f++) {
      double sum = 0;
      final start = f * H;
      final end = math.min(start + N, samples.length);
      final count = end - start;
      if (count <= 0) continue;
      for (int i = start; i < end; i++) {
        final v = samples[i];
        sum += v * v;
      }
      loudness[f] = math.sqrt(sum / (count + 1e-10));
    }
    final chromaSummary = avgChroma;
    final diagnostics = {
      'numFrames': numFrames,
      'fftSize': N,
      'hopSize': H,
      'bins': bins,
      'harmonicMedianTime': harmonicMedianTime,
      'percussiveMedianFreq': percussiveMedianFreq,
      'bpm': bpmEstimate,
    };
    return AnalysisResult(
      duration: durationSec,
      bpm: bpmEstimate,
      beatTimes: beatTimes,
      percussiveOnsets: percussiveOnsets,
      harmonicOnsets: harmonicOnsets,
      eventsByType: eventsByType,
      sections: sections,
      loudnessTimeline: loudness,
      chromaSummary: chromaSummary,
      diagnostics: diagnostics,
    );
  }
  List<double> _hannWindow(int N) {
    final w = List<double>.filled(N, 0.0);
    for (int n = 0; n < N; n++) {
      w[n] = 0.5 * (1 - math.cos(2 * math.pi * n / (N - 1)));
    }
    return w;
  }
  List<List<double>> _medianFilterTime(List<List<double>> spec, int timeRadius) {
    final F = spec.length;
    final B = spec[0].length;
    final out = List.generate(F, (_) => List<double>.filled(B, 0.0));
    final window = timeRadius;
    for (int b = 0; b < B; b++) {
      final column = List<double>.generate(F, (f) => spec[f][b]);
      for (int f = 0; f < F; f++) {
        int start = math.max(0, f - window);
        int end = math.min(F, f + window + 1);
        final slice = column.sublist(start, end)..sort();
        out[f][b] = slice[slice.length ~/ 2];
      }
    }
    return out;
  }
  List<List<double>> _medianFilterFreq(List<List<double>> spec, int freqRadius) {
    final F = spec.length;
    final B = spec[0].length;
    final out = List.generate(F, (_) => List<double>.filled(B, 0.0));
    final window = freqRadius;
    for (int f = 0; f < F; f++) {
      final row = spec[f];
      for (int b = 0; b < B; b++) {
        int start = math.max(0, b - window);
        int end = math.min(B, b + window + 1);
        final slice = row.sublist(start, end)..sort();
        out[f][b] = slice[slice.length ~/ 2];
      }
    }
    return out;
  }
  List<double> _computeNoveltyCurve(List<List<double>> weightedSpec, {bool emphasizeHigh = false}) {
    final F = weightedSpec.length;
    final B = weightedSpec[0].length;
    final ny = List<double>.filled(F, 0.0);
    List<double>? prevLog;
    for (int f = 0; f < F; f++) {
      final logmag = List<double>.filled(B, 0.0);
      for (int b = 0; b < B; b++) {
        logmag[b] = math.log(1 + weightedSpec[f][b]);
      }
      if (prevLog == null) {
        prevLog = logmag;
        ny[f] = 0.0;
        continue;
      }
      double acc = 0;
      for (int b = 0; b < B; b++) {
        final d = logmag[b] - prevLog[b];
        if (d > 0) {
          final w = emphasizeHigh ? (1.0 + b / B) : (1.0 + (B - b) / B * 0.5);
          acc += w * d;
        }
      }
      ny[f] = acc;
      prevLog = logmag;
    }
    return ny;
  }
  List<double> _movingAverage(List<double> data, int window) {
    if (window <= 1) return List<double>.from(data);
    final out = List<double>.filled(data.length, 0.0);
    final half = window ~/ 2;
    for (int i = 0; i < data.length; i++) {
      int start = math.max(0, i - half);
      int end = math.min(data.length, start + window);
      start = math.max(0, end - window);
      double sum = 0;
      for (int j = start; j < end; j++) sum += data[j];
      out[i] = sum / (end - start);
    }
    return out;
  }
  List<double> _pickPeaksAdaptive(List<double> novelty, int numFrames, int hopSize, int sr,
      {int localWindow = 32, double multiplier = 1.6, double minIntervalSec = 0.05}) {
    final n = novelty.length;
    final medianArr = List<double>.filled(n, 0.0);
    final madArr = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      int start = math.max(0, i - localWindow);
      int end = math.min(n, i + localWindow + 1);
      final slice = novelty.sublist(start, end)..sort();
      final med = slice[slice.length ~/ 2];
      medianArr[i] = med;
      final devs = slice.map((v) => (v - med).abs()).toList()..sort();
      madArr[i] = devs[devs.length ~/ 2];
    }
    final threshold = List<double>.generate(n, (i) => medianArr[i] + multiplier * madArr[i] * 1.4826);
    final minFrames = (minIntervalSec * sr / hopSize).round();
    final peaks = <double>[];
    int lastFrame = -99999;
    for (int i = 1; i < n - 1; i++) {
      if (novelty[i] > threshold[i] && novelty[i] > novelty[i - 1] && novelty[i] > novelty[i + 1]) {
        if (i - lastFrame >= minFrames) {
          peaks.add(i * hopSize / sr.toDouble());
          lastFrame = i;
        }
      }
    }
    return peaks;
  }
  List<List<double>> _computeChromaFromSpectrogram(List<List<double>> harmonicSpec, int sr, int bins) {
    final F = harmonicSpec.length;
    final chromaPerFrame = List.generate(F, (_) => List<double>.filled(12, 0.0));
    final nyquist = sr / 2;
    final binFreq = nyquist / (bins - 1);
    for (int f = 0; f < F; f++) {
      for (int b = 0; b < bins; b++) {
        final freq = b * binFreq;
        if (freq < 40.0) continue;
        final mag = harmonicSpec[f][b];
        final midi = 69 + 12 * (math.log(freq / 440.0) / math.log(2));
        final pc = (midi.round()) % 12;
        if (pc >= 0 && pc < 12) chromaPerFrame[f][pc] += mag;
      }
      final sum = chromaPerFrame[f].reduce((a, b) => a + b) + 1e-10;
      for (int c = 0; c < 12; c++) chromaPerFrame[f][c] = chromaPerFrame[f][c] / sum;
    }
    return chromaPerFrame;
  }
  double _estimateBpmFromEnvelope(List<double> envelope, int hopSize, int sr, {int minBpm = 60, int maxBpm = 180}) {
    final n = envelope.length;
    final mean = envelope.reduce((a, b) => a + b) / n;
    final centered = envelope.map((e) => e - mean).toList();
    final minLag = (60.0 * sr / (maxBpm * hopSize)).round();
    final maxLag = (60.0 * sr / (minBpm * hopSize)).round().clamp(minLag + 1, n - 1);
    double bestCorr = double.negativeInfinity;
    int bestLag = minLag;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double c = 0;
      for (int i = 0; i < n - lag; i++) c += centered[i] * centered[i + lag];
      if (c > bestCorr) {
        bestCorr = c;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return 120.0;
    final bpm = 60.0 * sr / (bestLag * hopSize);
    double bp = bpm;
    while (bp < 60) bp *= 2;
    while (bp > 180) bp /= 2;
    return bp;
  }
  double _estimateBpmFromSamples(
      List<double> samples,
      int sampleRate, {
        int frameSize = 1024,
        int hopSize = 512,
        int minBpm = 60,
        int maxBpm = 200,
      }) {
    final energy = <double>[];
    for (int i = 0; i + frameSize < samples.length; i += hopSize) {
      double sum = 0.0;
      for (int j = 0; j < frameSize; j++) {
        final s = samples[i + j];
        sum += s * s;
      }
      energy.add(math.sqrt(sum / frameSize));
    }
    if (energy.length < 20) return 120.0;
    final mean = energy.reduce((a, b) => a + b) / energy.length;
    for (int i = 0; i < energy.length; i++) {
      energy[i] -= mean;
    }
    final minLag = (60.0 * sampleRate / (maxBpm * hopSize)).round();
    final maxLag = (60.0 * sampleRate / (minBpm * hopSize))
        .round()
        .clamp(minLag + 1, energy.length - 1);
    double bestCorr = double.negativeInfinity;
    int bestLag = 0;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double corr = 0.0;
      for (int i = 0; i < energy.length - lag; i++) {
        corr += energy[i] * energy[i + lag];
      }
      corr /= (energy.length - lag);
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return 120.0;
    double bpm = 60.0 * sampleRate / (bestLag * hopSize);
    while (bpm < 70) bpm *= 2;
    while (bpm > 200) bpm /= 2;
    return bpm;
  }
  List<double> _computeBeatGridFromBpmAndOnsets(double bpm, List<double> onsets, double duration) {
    if (bpm <= 0) return [];
    final beatSec = 60.0 / bpm;
    if (onsets.isEmpty) {
      final beats = <double>[];
      for (double t = 0; t < duration; t += beatSec) beats.add(t);
      return beats;
    }
    final anchor = onsets.first;
    final phase = anchor % beatSec;
    final start = anchor - phase;
    final beats = <double>[];
    for (double t = start; t < duration + beatSec; t += beatSec) {
      if (t >= 0 && t <= duration) beats.add(t);
    }
    return beats;
  }
  List<double> _computeSpectralContrastNovelty(List<List<double>> harmonicSpec, int sr, int bins) {
    final frames = harmonicSpec.length;
    final bands = 6;
    final contrast = List<double>.filled(frames, 0.0);
    for (int f = 0; f < frames; f++) {
      final energies = List<double>.filled(bands, 0.0);
      for (int b = 0; b < bins; b++) {
        final bandIdx = ((b / bins) * bands).floor().clamp(0, bands - 1);
        energies[bandIdx] += harmonicSpec[f][b];
      }
      final mx = energies.reduce(math.max);
      final mn = energies.reduce(math.min);
      contrast[f] = (mx - mn);
    }
    final novelty = List<double>.filled(frames, 0.0);
    for (int f = 1; f < frames; f++) {
      final d = contrast[f] - contrast[f - 1];
      novelty[f] = d > 0 ? d : 0.0;
    }
    return novelty;
  }
  List<double> _detectSectionsFromNovelty(List<double> novelty, int numFrames, int hopSize, int sr, {int localWindow = 32, double multiplier = 2.0, double minSectionSec = 8.0}) {
    final peaks = _pickPeaksAdaptive(novelty, numFrames, hopSize, sr, localWindow: localWindow, multiplier: multiplier, minIntervalSec: 4.0);
    final secs = <double>[0.0];
    final minSec = minSectionSec;
    double last = 0.0;
    for (final p in peaks) {
      if (p - last >= minSec) {
        secs.add(p);
        last = p;
      }
    }
    secs.add((numFrames * hopSize / sr.toDouble()));
    return secs;
  }
  List<double> detectSectionsSpectral(
      List<double> samples,
      int sr, {
        double frameSec = 2.0,
        double hopSec = 1.0,
        double smoothSec = 4.0,
        double thresholdK = 1.0,
        double minSectionSec = 8.0,
        double eps = 1e-12,
      }) {
    final duration = samples.length / sr;
    if (samples.isEmpty || duration <= 0.0) return [0.0, duration];
    final frameLen = math.max(1, (frameSec * sr).round());
    final hopLen = math.max(1, (hopSec * sr).round());
    final rms = <double>[];
    for (int i = 0; i + frameLen <= samples.length; i += hopLen) {
      double sum = 0.0;
      for (int j = 0; j < frameLen; j++) {
        final s = samples[i + j];
        sum += s * s;
      }
      rms.add(math.sqrt(sum / frameLen));
    }
    if (rms.length < 3) return [0.0, duration];
    final ln10 = math.log(10);
    List<double> db = rms.map((r) => 20.0 * (math.log(r + eps) / ln10)).toList();
    final smoothFrames = math.max(1, (smoothSec / hopSec).round());
    final sm = movingAverage(db, smoothFrames);
    final deriv = <double>[];
    for (int i = 1; i < sm.length; i++) {
      deriv.add(sm[i] - sm[i - 1]);
    }
    if (deriv.isEmpty) return [0.0, duration];
    final med = median(deriv);
    final madVal = mad(deriv, med);
    final approxStd = madVal * 1.4826;
    final thresh = med + thresholdK * approxStd;
    final detectedFrameIndices = <int>[];
    for (int i = 0; i < deriv.length; i++) {
      if (deriv[i] > thresh) {
        detectedFrameIndices.add(i + 1);
      }
    }
    final minSeparationFrames = math.max(1, (minSectionSec / hopSec).round());
    final secs = <double>[0.0];
    int? lastFrame;
    for (final f in detectedFrameIndices) {
      if (lastFrame == null || (f - lastFrame) >= minSeparationFrames) {
        final t = (f * hopLen) / sr;
        if (t > 0.0 && t < duration) secs.add(t);
        lastFrame = f;
      } else {
        lastFrame = f;
      }
    }
    secs.add(duration);
    final clean = <double>[];
    for (var t in secs) {
      var tt = t.clamp(0.0, duration);
      if (clean.isEmpty || (tt - clean.last) > 0.01) clean.add(tt);
    }
    return clean;
  }
  List<double> movingAverage(List<double> data, int window) {
    if (window <= 1) return List<double>.from(data);
    final out = <double>[];
    final half = window ~/ 2;
    for (int i = 0; i < data.length; i++) {
      int start = math.max(0, i - half);
      int end = math.min(data.length, start + window);
      start = math.max(0, end - window);
      double sum = 0.0;
      for (int j = start; j < end; j++) sum += data[j];
      out.add(sum / (end - start));
    }
    return out;
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
}
extension ComplexListExtensions on Float64x2List {
  List<double> powerSpectrum() {
    final out = List<double>.filled(length, 0.0);
    for (int i = 0; i < length; i++) {
      final re = this[i].x;
      final im = this[i].y;
      out[i] = re * re + im * im;
    }
    return out;
  }
  List<double> phases() {
    final out = List<double>.filled(length, 0.0);
    for (int i = 0; i < length; i++) {
      final re = this[i].x;
      final im = this[i].y;
      out[i] = math.atan2(im, re);
    }
    return out;
  }
}