package com.example.anna_salon_mobile

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log

class UpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirmation = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                confirmation?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (confirmation != null) context.startActivity(confirmation)
            }
            PackageInstaller.STATUS_SUCCESS -> {
                relaunchUpdatedApp(context)
            }
            else -> Log.w(TAG, "Update installation failed: ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}")
        }
    }

    private fun relaunchUpdatedApp(context: Context) {
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            ?: return
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val creatorOptions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            ActivityOptions.makeBasic().apply {
                pendingIntentCreatorBackgroundActivityStartMode =
                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            }.toBundle()
        } else {
            null
        }
        val launchPendingIntent = PendingIntent.getActivity(
            context,
            RELAUNCH_REQUEST_CODE,
            launchIntent,
            flags,
            creatorOptions,
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val senderOptions = ActivityOptions.makeBasic().apply {
                    pendingIntentBackgroundActivityStartMode =
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                }
                launchPendingIntent.send(
                    context,
                    0,
                    null,
                    null,
                    null,
                    null,
                    senderOptions.toBundle(),
                )
            } else {
                launchPendingIntent.send()
            }
            Log.i(TAG, "Requested app relaunch after update.")
        } catch (error: PendingIntent.CanceledException) {
            Log.e(TAG, "Unable to relaunch app after update.", error)
        }
    }

    companion object {
        private const val TAG = "BrimoonUpdater"
        private const val RELAUNCH_REQUEST_CODE = 9103
        const val ACTION_INSTALL_RESULT =
            "com.example.anna_salon_mobile.UPDATE_INSTALL_RESULT"
    }
}
