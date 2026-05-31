package com.almarfa.tawheed

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context

class MainActivity : AudioServiceActivity() {
    // This allows the audio service plugin to safely find the active engine instance
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngine(context)
    }
}