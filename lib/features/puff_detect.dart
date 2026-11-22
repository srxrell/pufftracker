import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:record/record.dart';
import 'package:untitled/services/device_service.dart';
import 'package:untitled/services/locale_service.dart';

class PuffDetector {
  PoseDetector? _poseDetector;
  PoseDetector get _pose => _poseDetector ??= PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  FaceDetector? _faceDetector;
  FaceDetector get _face => _faceDetector ??= FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  AudioRecorder? _audioRecorder;
  bool _audioAvailable = false;
  double _currentAmplitude = -160.0;
  double _baselineNoise = -50.0;
  bool _isListeningAudio = false;

  bool _isProcessing = false;
  DateTime? _inhaleStartTime;
  DateTime? _lastPuffTime;
  DateTime? _handDepartedTime;
  bool _puffTriggered = false;
  double _strengthMultiplier = 2.5;

  double _baselineLuma = -1;
  double _baselineStdDev = -1;
  bool _deviceSeenInInhale = false;

  String currentStatus = "Ready...";
  bool isPuffing = false;

  set strengthMultiplier(double value) => _strengthMultiplier = value;

  Future<void> startAudioListening() async {
    try {
      _audioRecorder ??= AudioRecorder();
      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) return;
      if (await _audioRecorder!.isRecording()) return;

      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/puff_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _isListeningAudio = true;
      _audioAvailable = true;

      _audioRecorder!.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        _currentAmplitude = amp.current;
        if (_currentAmplitude > -120) {
          _baselineNoise = _baselineNoise * 0.95 + _currentAmplitude * 0.05;
        }
      });
    } catch (_) {
      _audioAvailable = false;
      _isListeningAudio = false;
    }
  }

  Future<void> stopAudioListening() async {
    try {
      if (_audioRecorder != null && _isListeningAudio) {
        await _audioRecorder!.stop();
        _isListeningAudio = false;
      }
    } catch (_) {}
  }

  Future<double?> processCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final now = DateTime.now();

      if (_lastPuffTime != null && now.difference(_lastPuffTime!).inMilliseconds < 1800) {
        currentStatus = tr("Cooldown between puffs...", "Пауза между затяжками...");
        isPuffing = false;
        return null;
      }

      final inputImage = _inputImageFromCameraImage(image, camera, deviceOrientation);
      if (inputImage == null) return null;

      final poses = await _pose.processImage(inputImage);
      final activeDevice = DeviceService.activeDevice.value;

      bool handNearMouth = false;
      bool deviceDetected = false;
      double mouthX = 0;
      double mouthY = 0;
      double handX = 0;
      double handY = 0;
      double scale = 0;

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final res = _evaluateHandAndMouth(pose, image.width.toDouble());
        handNearMouth = res['near'] as bool;
        mouthX = res['mouthX'] as double;
        mouthY = res['mouthY'] as double;
        handX = res['handX'] as double;
        handY = res['handY'] as double;
        scale = res['scale'] as double;

        if (handNearMouth) {
          deviceDetected = _detectDeviceObject(
            image: image,
            mouthX: mouthX,
            mouthY: mouthY,
            handX: handX,
            handY: handY,
            deviceType: activeDevice.type,
          );
        }
      }

      if (_handDepartedTime != null && now.difference(_handDepartedTime!).inMilliseconds < 2500) {
        final smokeDetected = _detectSmokePlume(
          image: image,
          mouthX: mouthX > 0 ? mouthX : image.width / 2.0,
          mouthY: mouthY > 0 ? mouthY : image.height / 2.0,
          scale: scale > 0 ? scale : image.width * 0.25,
        );

        if (smokeDetected) {
          _handDepartedTime = null;
          _lastPuffTime = now;
          _inhaleStartTime = null;
          _deviceSeenInInhale = false;
          _puffTriggered = false;
          isPuffing = false;
          currentStatus = tr("Vapor cloud detected! 💨", "Облако пара зафиксировано! 💨");
          return 2.5;
        }
      }

      final soundInhale = _checkAudioInhale();
      final validPuffContact = handNearMouth && (deviceDetected || _deviceSeenInInhale);

      isPuffing = validPuffContact;

      if (isPuffing) {
        if (deviceDetected) {
          _deviceSeenInInhale = true;
        }
        _inhaleStartTime ??= now;
        _handDepartedTime = null;

        final durationSec = now.difference(_inhaleStartTime!).inMilliseconds / 1000.0;
        final devLabel = _formatDeviceLabel(activeDevice.type);
        final soundTag = soundInhale && _audioAvailable ? " 🎙️" : "";

        currentStatus = tr(
          "Inhaling ($devLabel): ${durationSec.toStringAsFixed(1)}s$soundTag",
          "Тяга $devLabel: ${durationSec.toStringAsFixed(1)}с$soundTag",
        );

        if (durationSec >= 2.2 && !_puffTriggered) {
          _puffTriggered = true;
          _lastPuffTime = now;
          _deviceSeenInInhale = false;
          currentStatus = tr(
            "Puff counted! (${durationSec.toStringAsFixed(1)}s)! Cloud master! 💨",
            "Затяжка засчитана! (${durationSec.toStringAsFixed(1)}с)! Паровоз! 💨",
          );
          return durationSec;
        }
      } else {
        if (handNearMouth && !deviceDetected && !_deviceSeenInInhale) {
          currentStatus = tr("Hand near mouth (scanning device...)", "Рука у рта (поиск девайса...)");
        }

        if (_inhaleStartTime != null) {
          final durationSec = now.difference(_inhaleStartTime!).inMilliseconds / 1000.0;
          _inhaleStartTime = null;
          _handDepartedTime = now;

          if (!_puffTriggered && durationSec >= 0.6 && durationSec <= 5.5 && _deviceSeenInInhale) {
            _lastPuffTime = now;
            _puffTriggered = false;
            _deviceSeenInInhale = false;
            currentStatus = tr(
              "Puff recorded! (${durationSec.toStringAsFixed(1)}s) 💨",
              "Затяжка зафиксирована! (${durationSec.toStringAsFixed(1)}с) 💨",
            );
            return durationSec;
          }
        }

        _puffTriggered = false;
        if (!handNearMouth && _handDepartedTime == null) {
          currentStatus = poses.isNotEmpty
              ? tr("In frame (waiting for puff)", "В кадре (ожидание затяжки)")
              : tr("Scanning pose / face...", "Поиск позы / лица...");
        }
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }

    return null;
  }

  String _formatDeviceLabel(String type) {
    switch (type) {
      case 'hookah':
        return tr('hookah', 'кальяна');
      case 'cigarettes':
        return tr('classic', 'сигареты');
      case 'vape':
      default:
        return tr('pod', 'ашки');
    }
  }

  bool _checkAudioInhale() {
    if (!_audioAvailable) return true;
    final dbJump = _currentAmplitude - _baselineNoise;
    return dbJump > 6.0 || _currentAmplitude > -36.0;
  }

  Map<String, dynamic> _evaluateHandAndMouth(Pose pose, double imageWidth) {
    final mouthL = pose.landmarks[PoseLandmarkType.leftMouth];
    final mouthR = pose.landmarks[PoseLandmarkType.rightMouth];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    double mouthX = 0;
    double mouthY = 0;
    bool hasTarget = false;

    if (mouthL != null && mouthR != null && mouthL.likelihood > 0.25 && mouthR.likelihood > 0.25) {
      mouthX = (mouthL.x + mouthR.x) / 2.0;
      mouthY = (mouthL.y + mouthR.y) / 2.0;
      hasTarget = true;
    } else if (nose != null && nose.likelihood > 0.25) {
      mouthX = nose.x;
      hasTarget = true;
    }

    if (!hasTarget) {
      return {'near': false, 'mouthX': 0.0, 'mouthY': 0.0, 'handX': 0.0, 'handY': 0.0, 'scale': 0.0};
    }

    double scale = 0.0;
    final sL = pose.landmarks[PoseLandmarkType.leftShoulder];
    final sR = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (sL != null && sR != null && sL.likelihood > 0.25 && sR.likelihood > 0.25) {
      final sDist = sqrt(pow(sL.x - sR.x, 2) + pow(sL.y - sR.y, 2));
      if (sDist > 20) scale = sDist * 0.45;
    }

    if (scale == 0.0) {
      final eL = pose.landmarks[PoseLandmarkType.leftEar];
      final eR = pose.landmarks[PoseLandmarkType.rightEar];
      if (eL != null && eR != null && eL.likelihood > 0.25 && eR.likelihood > 0.25) {
        scale = sqrt(pow(eL.x - eR.x, 2) + pow(eL.y - eR.y, 2));
      }
    }

    if (scale < 30.0) scale = imageWidth * 0.25;

    if (mouthL == null || mouthR == null || mouthL.likelihood <= 0.25 || mouthR.likelihood <= 0.25) {
      mouthY = nose!.y + (scale * 0.35);
    }

    final hands = [
      pose.landmarks[PoseLandmarkType.leftIndex],
      pose.landmarks[PoseLandmarkType.rightIndex],
      pose.landmarks[PoseLandmarkType.leftThumb],
      pose.landmarks[PoseLandmarkType.rightThumb],
      pose.landmarks[PoseLandmarkType.leftWrist],
      pose.landmarks[PoseLandmarkType.rightWrist],
    ];

    double closestDist = double.infinity;
    double bestHandX = 0;
    double bestHandY = 0;

    for (final pt in hands) {
      if (pt != null && pt.likelihood > 0.20) {
        final d = sqrt(pow(pt.x - mouthX, 2) + pow(pt.y - mouthY, 2));
        if (d < closestDist) {
          closestDist = d;
          bestHandX = pt.x;
          bestHandY = pt.y;
        }
      }
    }

    final isNear = closestDist <= (scale * 0.85);

    return {
      'near': isNear,
      'mouthX': mouthX,
      'mouthY': mouthY,
      'handX': bestHandX,
      'handY': bestHandY,
      'scale': scale,
    };
  }

  bool _detectDeviceObject({
    required CameraImage image,
    required double mouthX,
    required double mouthY,
    required double handX,
    required double handY,
    required String deviceType,
  }) {
    if (image.planes.isEmpty) return false;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final width = image.width;
    final height = image.height;
    if (yBytes.isEmpty || width <= 0 || height <= 0) return false;

    final minX = max(0, min(mouthX, handX).toInt() - 25);
    final maxX = min(width - 1, max(mouthX, handX).toInt() + 25);
    final minY = max(0, min(mouthY, handY).toInt() - 25);
    final maxY = min(height - 1, max(mouthY, handY).toInt() + 25);

    final boxW = maxX - minX;
    final boxH = maxY - minY;
    if (boxW < 8 || boxH < 8) return false;

    int totalSamples = 0;
    int darkPixels = 0;
    int brightPixels = 0;
    double lumaSum = 0;

    final bytesPerRow = yPlane.bytesPerRow;
    final step = max(2, min(boxW, boxH) ~/ 18);

    for (int y = minY; y <= maxY; y += step) {
      final rowOffset = y * bytesPerRow;
      for (int x = minX; x <= maxX; x += step) {
        if (rowOffset + x < yBytes.length) {
          final luma = yBytes[rowOffset + x];
          lumaSum += luma;
          totalSamples++;

          if (luma < 60) {
            darkPixels++;
          } else if (luma > 200) {
            brightPixels++;
          }
        }
      }
    }

    if (totalSamples == 0) return false;
    final avgLuma = lumaSum / totalSamples;

    if (deviceType == 'hookah') {
      final isElongated = boxH > (boxW * 1.15) || boxW > (boxH * 1.15);
      final hasTubeContrast = (darkPixels / totalSamples > 0.12) || (brightPixels / totalSamples > 0.12);
      return isElongated || hasTubeContrast;
    } else if (deviceType == 'cigarettes') {
      final hasCigaretteWhite = (brightPixels / totalSamples > 0.08) || (darkPixels / totalSamples > 0.16);
      return hasCigaretteWhite;
    } else {
      final hasVapeBody = (darkPixels / totalSamples > 0.10) ||
          (brightPixels / totalSamples > 0.10) ||
          (avgLuma < 75 || avgLuma > 185);
      return hasVapeBody;
    }
  }

  bool _detectSmokePlume({
    required CameraImage image,
    required double mouthX,
    required double mouthY,
    required double scale,
  }) {
    if (image.planes.isEmpty) return false;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final width = image.width;
    final height = image.height;
    if (yBytes.isEmpty || width <= 0 || height <= 0) return false;

    final plumeW = (scale * 1.3).toInt();
    final plumeH = (scale * 1.1).toInt();

    final startX = max(0, (mouthX - plumeW / 2).toInt());
    final endX = min(width - 1, (mouthX + plumeW / 2).toInt());
    final startY = max(0, (mouthY - plumeH * 0.4).toInt());
    final endY = min(height - 1, (mouthY + plumeH * 0.8).toInt());

    final actualW = endX - startX;
    final actualH = endY - startY;
    if (actualW < 10 || actualH < 10) return false;

    double sum = 0;
    double sumSq = 0;
    int count = 0;
    final bytesPerRow = yPlane.bytesPerRow;

    for (int y = startY; y <= endY; y += 4) {
      final row = y * bytesPerRow;
      for (int x = startX; x <= endX; x += 4) {
        if (row + x < yBytes.length) {
          final v = yBytes[row + x].toDouble();
          sum += v;
          sumSq += v * v;
          count++;
        }
      }
    }

    if (count == 0) return false;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final stdDev = variance > 0 ? sqrt(variance) : 0.0;

    if (_baselineLuma < 0) {
      _baselineLuma = mean;
      _baselineStdDev = stdDev;
      return false;
    }

    final lumaDiff = mean - _baselineLuma;
    final stdDevDrop = _baselineStdDev - stdDev;

    _baselineLuma = _baselineLuma * 0.90 + mean * 0.10;
    _baselineStdDev = _baselineStdDev * 0.90 + stdDev * 0.10;

    final isSmoke = (lumaDiff > 11.0 && stdDev < 50.0) ||
        (stdDevDrop > 12.0 && stdDev < 40.0) ||
        (mean > 175.0 && stdDev < 42.0);

    return isSmoke;
  }

  double calculateDizzyIncrement(double puffDurationSec) {
    return (puffDurationSec * 0.035 * _strengthMultiplier).clamp(0.05, 0.45);
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    if (Platform.isAndroid) {
      final Uint8List nv21Bytes;
      final int bytesPerRow;

      if (image.planes.length == 1) {
        nv21Bytes = image.planes[0].bytes;
        bytesPerRow = image.planes[0].bytesPerRow;
      } else {
        nv21Bytes = _yuv420ToNv21(image);
        bytesPerRow = image.width;
      }

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: bytesPerRow,
        ),
      );
    }

    if (Platform.isIOS) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return null;
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height * 3 ~/ 2);
    int idY = 0;
    for (int y = 0; y < height; y++) {
      final rowStart = y * yPlane.bytesPerRow;
      for (int x = 0; x < width; x++) {
        if (rowStart + x < yPlane.bytes.length) {
          nv21[idY++] = yPlane.bytes[rowStart + x];
        } else {
          nv21[idY++] = 0;
        }
      }
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < uvHeight; y++) {
      final uRowStart = y * uPlane.bytesPerRow;
      final vRowStart = y * vPlane.bytesPerRow;
      for (int x = 0; x < uvWidth; x++) {
        final uvIndex = x * uvPixelStride;
        final vIndex = vRowStart + uvIndex;
        final uIndex = uRowStart + uvIndex;
        if (vIndex < vPlane.bytes.length) {
          nv21[idY++] = vPlane.bytes[vIndex];
        }
        if (uIndex < uPlane.bytes.length) {
          nv21[idY++] = uPlane.bytes[uIndex];
        }
      }
    }

    return nv21;
  }

  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void dispose() {
    stopAudioListening();
    _audioRecorder?.dispose();
    _faceDetector?.close();
    _poseDetector?.close();
  }
}
