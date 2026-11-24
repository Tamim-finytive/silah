package com.finytive.silah

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.hardware.GeomagneticField

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "silah/compass")
            .setMethodCallHandler { call, result ->
                if (call.method == "magneticDeclination") {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    if (latitude == null || longitude == null) {
                        result.error("invalid_location", "Latitude and longitude are required", null)
                    } else {
                        val field = GeomagneticField(
                            latitude.toFloat(),
                            longitude.toFloat(),
                            0f,
                            System.currentTimeMillis(),
                        )
                        result.success(field.declination.toDouble())
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "silah/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "localTimeZone") {
                    val tzId = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        try {
                            java.time.ZoneId.systemDefault().id
                        } catch (_: Exception) {
                            java.util.TimeZone.getDefault().id
                        }
                    } else {
                        java.util.TimeZone.getDefault().id
                    }
                    result.success(tzId)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "silah/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        TtsManager.speak(context, text)
                        result.success(true)
                    }
                    "stop" -> {
                        TtsManager.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
