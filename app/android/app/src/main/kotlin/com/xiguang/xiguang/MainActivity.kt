package com.xiguang.xiguang

import com.alipay.sdk.app.PayTask
import com.tencent.mm.opensdk.modelbiz.WXOpenBusinessWebview
import com.tencent.mm.opensdk.openapi.WXAPIFactory
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xiguang.xiguang/payments",
        ).setMethodCallHandler { call, result ->
            if (call.method == "startSubscription") {
                val provider = call.argument<String>("provider")
                when (provider) {
                    "alipay" -> startAlipayAgreement(call.argument("order_string"), result)
                    "wechat" -> startWeChatAgreement(
                        call.argument("app_id"),
                        call.argument("pre_entrustweb_id"),
                        call.argument<Int>("business_type") ?: 12,
                        result,
                    )
                    else -> result.error("INVALID_PROVIDER", "不支持的支付渠道", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startAlipayAgreement(orderString: String?, result: MethodChannel.Result) {
        if (orderString.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "支付宝签约参数为空", null)
            return
        }
        Thread {
            try {
                val payResult = PayTask(this).payV2(orderString, true)
                runOnUiThread { result.success(payResult) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("ALIPAY_SDK_ERROR", error.message ?: "支付宝签约失败", null)
                }
            }
        }.start()
    }

    private fun startWeChatAgreement(
        appId: String?,
        preEntrustWebId: String?,
        businessType: Int,
        result: MethodChannel.Result,
    ) {
        if (appId.isNullOrBlank() || preEntrustWebId.isNullOrBlank()) {
            result.error("INVALID_PAYLOAD", "微信签约参数不完整", null)
            return
        }
        val api = WXAPIFactory.createWXAPI(this, appId, true)
        if (!api.registerApp(appId)) {
            result.error("WECHAT_REGISTER_FAILED", "无法注册微信支付应用", null)
            return
        }
        val request = WXOpenBusinessWebview.Req().apply {
            this.businessType = businessType
            this.queryInfo = hashMapOf("pre_entrustweb_id" to preEntrustWebId)
        }
        if (!api.sendReq(request)) {
            result.error("WECHAT_SDK_ERROR", "未能打开微信签约页", null)
            return
        }
        // 签约最终结果以服务端验签回调为准，客户端进入订单轮询。
        result.success(mapOf("resultStatus" to "8000"))
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
