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
    }
}
