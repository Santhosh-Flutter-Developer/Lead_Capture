package com.srisoftwarez.leadcapture

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val INSTALLCHANNEL = "com.srisoftwarez.leadcapture/install_apk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Install APK Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLCHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    installApk(filePath)
                    result.success(null)
                } else {
                    result.error("INVALID_FILE_PATH", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this@MainActivity,
                    "${applicationContext.packageName}.provider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
