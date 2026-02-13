package com.coopvestafrica

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.view.FlutterMain

class MainActivity: FlutterActivity() {

    override fun provideFlutterEngine(activity: io.flutter.app.FlutterActivity): FlutterEngine? {
        return null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FlutterMain.startInitialization(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun getDartEntrypointFunctionName(): String {
        return "main"
    }
}
