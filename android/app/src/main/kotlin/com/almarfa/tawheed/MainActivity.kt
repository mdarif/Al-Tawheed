package com.almarfa.tawheed

import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity : AudioServiceActivity() {
    private val startupChannel = "com.almarfa.tawheed/startup"
    private var activityCreatedAt: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        activityCreatedAt = SystemClock.elapsedRealtime()
        super.onCreate(savedInstanceState)
        // Opt into edge-to-edge display so Android 15 doesn't enforce it
        // with unexpected insets, and to stop calling deprecated
        // setStatusBarColor / setNavigationBarColor APIs.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, startupChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "startupInteractive") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val cohort = call.argument<String>("cohort") ?: "unspecified"
                val surface = call.argument<String>("surface") ?: "unknown"
                val elapsed = SystemClock.elapsedRealtime() - activityCreatedAt
                Log.i(
                    "TawheedStartup",
                    "COLD_START_INTERACTIVE cohort=$cohort " +
                        "surface=$surface elapsed_ms=$elapsed",
                )
                result.success(null)
            }
    }

    // This allows the audio service plugin to safely find the active engine instance
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngine(context)
    }
}
