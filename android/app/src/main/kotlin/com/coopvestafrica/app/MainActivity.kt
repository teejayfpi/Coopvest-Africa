package com.coopvestafrica.app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * MainActivity - Updated to FlutterFragmentActivity
 *
 * Required by the local_auth plugin for biometric authentication.
 * onFlutterUiDisplayed triggers a smooth fade-in from the splash screen
 * into the app using overridePendingTransition.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        overridePendingTransition(R.anim.fade_in, R.anim.hold)
    }
}
