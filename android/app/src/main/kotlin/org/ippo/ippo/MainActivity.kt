// SPDX-License-Identifier: GPL-3.0-or-later

package org.ippo.ippo

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's single Android screen. Flutter draws everything inside it.
 *
 * Its only extra job is connecting [StorageBridge] (files),
 * [SystemColors] (the phone's accent color) and [SystemTimeZone] (the
 * name of the phone's time zone) to the Dart code.
 */
class MainActivity : FlutterActivity() {

    private var storageBridge: StorageBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = StorageBridge(this)
        storageBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, StorageBridge.CHANNEL_NAME)
            .setMethodCallHandler(bridge)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SystemColors.CHANNEL_NAME)
            .setMethodCallHandler(SystemColors(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SystemTimeZone.CHANNEL_NAME)
            .setMethodCallHandler(SystemTimeZone())
    }

    // The folder picker reports back here. We use this older API because
    // FlutterActivity does not support the newer "activity result" helpers
    // without adding an extra library.
    @Deprecated("Needed for the folder picker; see comment above.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == StorageBridge.PICK_FOLDER_REQUEST_CODE) {
            storageBridge?.onPickFolderResult(resultCode, data)
        }
    }
}
