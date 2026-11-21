// SPDX-License-Identifier: GPL-3.0-or-later

package org.ippo.ippo

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * Tells the Dart side the name of the phone's time zone, such as
 * "Europe/Paris" (an IANA time zone id). Each event records it, so an
 * analysis can tell a daylight saving change from a trip. This reads a
 * setting only; it touches no files and needs no permission.
 *
 * Methods:
 * - `timeZone()`: the time zone id as text.
 */
class SystemTimeZone : MethodChannel.MethodCallHandler {

    companion object {
        /** The channel name. It must match the Dart side. */
        const val CHANNEL_NAME = "org.ippo.ippo/time_zone"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "timeZone" -> result.success(TimeZone.getDefault().id)
            else -> result.notImplemented()
        }
    }
}
