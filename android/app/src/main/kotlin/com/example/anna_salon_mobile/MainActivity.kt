package com.example.anna_salon_mobile

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val updaterChannel = "brimoon/app_updater"
    private var installPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            updaterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> result.success(canInstallPackages())
                "updateDirectory" -> {
                    val directory = File(cacheDir, "updates")
                    directory.mkdirs()
                    result.success(directory.absolutePath)
                }
                "requestInstallPermission" -> {
                    requestInstallPermission(result)
                }
                "sha256" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("missing_path", "APK path is required.", null)
                    } else {
                        runCatching { sha256(File(path)) }
                            .onSuccess(result::success)
                            .onFailure { result.error("hash_failed", it.message, null) }
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("missing_path", "APK path is required.", null)
                    } else if (!canInstallPackages()) {
                        result.success("permission_required")
                    } else {
                        runCatching { installApk(File(path)) }
                            .onSuccess { result.success("started") }
                            .onFailure { result.error("install_failed", it.message, null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun requestInstallPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || canInstallPackages()) {
            result.success(true)
            return
        }
        if (installPermissionResult != null) {
            result.error("permission_in_progress", "Install permission is already open.", null)
            return
        }
        installPermissionResult = result
        startActivityForResult(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ),
            INSTALL_PERMISSION_REQUEST_CODE,
        )
    }

    @Deprecated("Deprecated in Android, retained for the system settings result callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != INSTALL_PERMISSION_REQUEST_CODE) return
        val callback = installPermissionResult
        installPermissionResult = null
        callback?.success(canInstallPackages())
    }

    private fun installApk(apk: File) {
        require(apk.exists() && apk.length() > 0) { "Downloaded APK does not exist." }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            FileInputStream(apk).use { input ->
                session.openWrite("brimoon-update.apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val callback = Intent(this, UpdateInstallReceiver::class.java).apply {
                action = UpdateInstallReceiver.ACTION_INSTALL_RESULT
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                sessionId,
                callback,
                flags,
            )
            session.commit(pendingIntent.intentSender)
        }
    }

    private fun sha256(file: File): String {
        require(file.exists()) { "File does not exist." }
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val INSTALL_PERMISSION_REQUEST_CODE = 9102
    }
}
