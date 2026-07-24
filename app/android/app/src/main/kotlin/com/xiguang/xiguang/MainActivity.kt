package com.xiguang.xiguang

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xiguang.xiguang/storage",
        ).setMethodCallHandler { call, result ->
            if (call.method == "installationBytes") {
                result.success(installationBytes())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun installationBytes(): Long {
        val info = applicationInfo
        var total = File(info.sourceDir).takeIf { it.exists() }?.length() ?: 0L
        info.splitSourceDirs?.forEach { path ->
            total += File(path).takeIf { it.exists() }?.length() ?: 0L
        }
        return total
    }
}
