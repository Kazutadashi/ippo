// SPDX-License-Identifier: GPL-3.0-or-later

package org.ippo.ippo

import android.app.Activity
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Tells the Dart side the phone's own accent color.
 *
 * Since Android 12, the system picks an accent color (from the wallpaper
 * or the user's choice in system settings) and offers it to apps. Ippo
 * reads it so its colors can match the rest of the phone. This reads a
 * color only; it touches no files and needs no permission.
 *
 * Methods:
 * - `accentColor()`: the system accent as a 32-bit ARGB number, or null on
 *   Android versions before 12, which have no system accent.
 */
class SystemColors(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        /** The channel name. It must match the Dart side. */
        const val CHANNEL_NAME = "org.ippo.ippo/system_colors"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "accentColor" -> result.success(accentColor())
            else -> result.notImplemented()
        }
    }

    private fun accentColor(): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return null
        }
        // "system_accent1_500" is the middle shade of the system's main
        // accent palette. Sent as a Long, because Dart reads the color as
        // an unsigned number.
        return activity.getColor(android.R.color.system_accent1_500).toLong() and 0xFFFFFFFFL
    }
}
