package com.almarfa.tawheed

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opt into edge-to-edge display so Android 15 doesn't enforce it
        // with unexpected insets, and to stop calling deprecated
        // setStatusBarColor / setNavigationBarColor APIs.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    // This allows the audio service plugin to safely find the active engine instance
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngine(context)
    }
}
