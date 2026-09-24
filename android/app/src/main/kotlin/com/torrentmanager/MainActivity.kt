package com.torrentmanager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * ⚠️ 2026-09-24（V0.2.12）：本类不再是空壳 —— 新增 `tm_updater` 通道，
 * 为「检查更新」弹窗提供三项**只能用原生 API 做到**的能力：
 *   · getAbi     —— 读 Build.SUPPORTED_ABIS，用来在 Release 资产里挑对架构的 APK；
 *   · openUrl    —— 起 ACTION_VIEW 交给系统浏览器（替代 url_launcher 依赖）；
 *   · installApk —— 用 FileProvider 把缓存目录里的 APK 以 content:// 交给安装器。
 *
 * 之所以自己写而不是引 url_launcher / open_filex 之类的插件：本项目刻意把
 * 原生插件数量压到最少（体积 + 鸿蒙移植成本），这里只需要 3 个方法，
 * 自己实现比拖一整个插件划算。
 *
 * ⚠️ 鸿蒙（OHOS）侧若未实现同名通道，Dart 侧会收到 MissingPluginException
 *    并降级为「复制发布页地址」，不会崩溃。
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAbi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")

                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        result.success(if (url.isNullOrEmpty()) false else openUrl(url))
                    }

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(
                            if (path.isNullOrEmpty()) CODE_UNAVAILABLE else installApk(path)
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun openUrl(raw: String): Boolean = try {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(raw)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        true
    } catch (e: Exception) {
        false
    }

    /**
     * @return "ok" 已唤起安装器 / "permission" 已跳设置页等待授权 /
     *         "unavailable" 平台或文件不支持。
     */
    private fun installApk(path: String): String {
        val file = File(path)
        if (!file.exists() || !file.canRead()) return CODE_UNAVAILABLE

        // Android 8 起，安装"未知来源"应用必须先被用户授予该权限；
        // 没授权就直接跳系统设置页（授权后用户回来再点一次即可）。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            return try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                CODE_PERMISSION
            } catch (e: Exception) {
                CODE_UNAVAILABLE
            }
        }

        // Android 7 起 file:// URI 会被 FileUriExposedException 挡下，
        // 必须经 FileProvider 换成 content:// 并临时授予读权限。
        return try {
            val uri = FileProvider.getUriForFile(
                this, "$packageName.fileprovider", file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            CODE_OK
        } catch (e: Exception) {
            CODE_UNAVAILABLE
        }
    }

    private companion object {
        const val CHANNEL = "tm_updater"
        const val CODE_OK = "ok"
        const val CODE_PERMISSION = "permission"
        const val CODE_UNAVAILABLE = "unavailable"
    }
}
