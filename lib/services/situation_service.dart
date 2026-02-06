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

  /// Determine the current context tags based on sensors.
  /// Takes about 0.5s - 1.0s to gather data.
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
         // macOS: permission_handler might fail, rely on Geolocator's internal check or assume handled by OS
         final status = await Geolocator.checkPermission();
         hasLocationPermission = status == LocationPermission.always || status == LocationPermission.whileInUse;
         if (status == LocationPermission.denied) {
            // Try request via Geolocator directly if possible, or just skip
            final requestStatus = await Geolocator.requestPermission();
             hasLocationPermission = requestStatus == LocationPermission.always || requestStatus == LocationPermission.whileInUse;
         }
      } else {
         // Mobile: Use permission_handler
         if (await Permission.location.request().isGranted) {
          hasLocationPermission = true;
         }
      }

      if (hasLocationPermission) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        
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
      if (await Permission.microphone.request().isGranted) {
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
