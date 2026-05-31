package com.almarfa.tawheed

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    // Explicit plugin registration so audio_service can locate the
    // FlutterEngine when AudioService.init() is called at startup.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.register(flutterEngine)
    }
}
