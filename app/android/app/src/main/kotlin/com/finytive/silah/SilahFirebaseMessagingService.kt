package com.finytive.silah

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class SilahFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val title = remoteMessage.notification?.title
            ?: remoteMessage.data["title"]
            ?: ""

        if (title.isNotBlank()) {
            Log.d("SilahFCM", "Voice reading heading: $title")
            TtsManager.speak(applicationContext, title)
        }

        super.onMessageReceived(remoteMessage)
    }
}
