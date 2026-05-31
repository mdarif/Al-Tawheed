package com.almarfa.tawheed

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // Explicit override ensures audio_service can locate the FlutterEngine
    // through FlutterActivity.getFlutterEngine() when AudioService.init() runs.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
}
