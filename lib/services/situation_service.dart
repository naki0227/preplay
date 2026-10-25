import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
// import 'package:geolocator/geolocator.dart'; // Commented out for now to ensure MVP stability first if needed, but we will use it.
import 'package:geolocator/geolocator.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SituationService {
  // Singleton
  static final SituationService _instance = SituationService._internal();
  factory SituationService() => _instance;
  SituationService._internal();

  /// Asks for the permissions context sensing needs. Only called after the
  /// user turned the feature on and saw why it is needed.
  /// Returns true if at least one sensor can be used.
  Future<bool> requestPermissions() async {
    bool granted = false;
    try {
      if (Platform.isMacOS) {
        final status = await Geolocator.requestPermission();
        granted = status == LocationPermission.always || status == LocationPermission.whileInUse;
      } else {
        granted = (await Permission.locationWhenInUse.request()).isGranted;
      }
    } catch (e) {
      print('Location permission error: $e');
    }
    try {
      if ((await Permission.microphone.request()).isGranted) granted = true;
    } catch (e) {
      print('Microphone permission error: $e');
    }
    return granted;
  }

  /// Determine the current context tags based on sensors.
  /// Never shows a permission prompt; sensors without permission are skipped.
  /// Takes about 0.5s - 1.5s to gather data.
  Future<List<String>> determineContext() async {
    List<String> detectedTags = [];

    // Run checks in parallel
    final results = await Future.wait([
      _checkLocationAndMotion(),
      _checkNoiseLevel(),
    ]);

    for (var tags in results) {
      detectedTags.addAll(tags);
    }

    // Default fallback
    if (detectedTags.isEmpty) {
      detectedTags.add('all');
    }

    // Ensure unique
    return detectedTags.toSet().toList();
  }

  Future<List<String>> _checkLocationAndMotion() async {
    List<String> tags = [];
    
    // 1. Location / Speed (Walking check)
    try {
      bool hasLocationPermission = false;
      if (Platform.isMacOS) {
        final status = await Geolocator.checkPermission();
        hasLocationPermission = status == LocationPermission.always || status == LocationPermission.whileInUse;
      } else {
        hasLocationPermission = await Permission.locationWhenInUse.isGranted;
      }

      if (hasLocationPermission) {
        // A cold GPS fix can take many seconds; give up quickly so "次" stays fast.
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(milliseconds: 1500),
          ),
        );
        
        if (position.speed > 0.5) {
          tags.add('walking');
          tags.add('noisy');
        } else {
          tags.add('standing');
          tags.add('waiting');
        }
      }
    } catch (e) {
      print('Location/Permission error: $e');
      // Fail silently or add default tags
    }

    // 2. Accelerometer (Motion intensity check) - skipping for macOS desktop usually, but good for iOS
    // Simple check: listen for 200ms
    try {
      // sensors_plus might be missing on macOS
      if (!Platform.isMacOS) {
        final stream = userAccelerometerEventStream();
        final event = await stream.first.timeout(const Duration(milliseconds: 300));
        
        // Magnitude of acceleration (excluding gravity)
        double magnitude = event.x.abs() + event.y.abs() + event.z.abs();
        
        if (magnitude > 3.0) {
          tags.add('active'); // Shaking or moving
        } else {
          tags.add('quiet'); // Still
        }
      } else {
        // On macOS/Simulator, we might default to 'quiet' or 'waiting'
        tags.add('quiet');
      }
    } catch (e) {
      print('Accelerometer error (expected on macOS): $e');
      // On macOS/Simulator, we might default to 'quiet' or 'waiting'
      tags.add('quiet');
    }
    
    return tags;
  }

  Future<List<String>> _checkNoiseLevel() async {
    // Note: NoiseMeter might fail on simulators or desktops without proper audio config.
    // We will wrap in try-catch.
    List<String> tags = [];
    
    try {
      if (await Permission.microphone.isGranted) {
        // Start "recording" briefly to get decibels
        final Completer<double> decibelCompleter = Completer();
        NoiseMeter noiseMeter = NoiseMeter();
        StreamSubscription? subscription;
        
        subscription = noiseMeter.noise.listen((NoiseReading reading) {
          if (!decibelCompleter.isCompleted) {
            decibelCompleter.complete(reading.meanDecibel);
          }
        }, onError: (e) {
          if (!decibelCompleter.isCompleted) decibelCompleter.complete(0);
        });

        // Wait a bit or until first reading
        double db = await decibelCompleter.future.timeout(const Duration(milliseconds: 500), onTimeout: () => 40.0);
        
        subscription?.cancel();

        // 60dB is conversational. 70dB+ is noisy.
        if (db > 70) {
          tags.add('noisy');
        } else if (db < 50) {
          tags.add('quiet');
        } else {
          tags.add('all'); // Normal volume
        }
      } else {
        tags.add('all');
      }
    } catch (e) {
      print('Microphone/Permission error: $e');
      tags.add('all');
    }
    return tags;
  }
}
