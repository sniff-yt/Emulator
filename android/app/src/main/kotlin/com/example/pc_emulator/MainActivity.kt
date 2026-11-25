package com.example.pc_emulator

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var logSink: EventChannel.EventSink? = null
    private lateinit var runtime: Runtime
    private var display: Display? = null
    private lateinit var channel: MethodChannel

    private fun emit(event: Map<String, Any?>) { main.post { logSink?.success(event) } }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        runtime = Runtime(applicationContext) { line -> emit(mapOf("type" to "log", "line" to line)) }
        display = Display(flutterEngine.renderer)

        EventChannel(messenger, "pcemu/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { logSink = events }
            override fun onCancel(arguments: Any?) { logSink = null }
        })

        channel = MethodChannel(messenger, "pcemu/runtime")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "paths" -> result.success(runtime.paths())
                    "rootfsReady" -> result.success(runtime.rootfsReady())
                    "installRootfs" -> {
                        val url = call.argument<String>("url")!!
                        Thread {
                            try {
                                runtime.installRootfs(url) { p, msg -> emit(mapOf("type" to "progress", "value" to p, "message" to msg)) }
                                main.post { result.success(true) }
                            } catch (e: Throwable) {
                                main.post { result.error("INSTALL", e.message ?: e.toString(), null) }
                            }
                        }.start()
                    }
                    "run" -> {
                        val cmd = call.argument<String>("cmd")!!
                        Thread {
                            val code = try { runtime.run(cmd) } catch (e: Throwable) { emit(mapOf("type" to "log", "line" to "error: ${e.message}")); -1 }
                            main.post { result.success(code) }
                        }.start()
                    }
                    "start" -> {
                        val name = call.argument<String>("name")!!
                        val cmd = call.argument<String>("cmd")!!
                        runtime.start(name, cmd) { code -> emit(mapOf("type" to "exit", "name" to name, "code" to code)) }
                        result.success(true)
                    }
                    "stop" -> { runtime.stop(call.argument<String>("name")!!); result.success(true) }
                    "stopAll" -> { runtime.stopAll(); result.success(true) }
                    "isRunning" -> result.success(runtime.isRunning(call.argument<String>("name")!!))
                    "displayStart" -> {
                        val id = display!!.start(
                            call.argument<String>("path")!!,
                            call.argument<Int>("width")!!,
                            call.argument<Int>("height")!!,
                            call.argument<Int>("fps") ?: 60,
                        )
                        result.success(id)
                    }
                    "displayInfo" -> result.success(mapOf("width" to display!!.width, "height" to display!!.height, "fps" to display!!.fps))
                    "displayStop" -> { display?.stop(); result.success(true) }
                    "keepScreenOn" -> {
                        if (call.argument<Boolean>("on") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(true)
                    }
                    "hasStorage" -> result.success(hasStorage())
                    "requestStorage" -> { requestStorage(); result.success(true) }
                    "deviceInfo" -> result.success(mapOf(
                        "model" to Build.MODEL, "soc" to (if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else Build.HARDWARE),
                        "sdk" to Build.VERSION.SDK_INT,
                        "kgsl" to java.io.File("/dev/kgsl-3d0").exists(),
                    ))
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                result.error("NATIVE_ERROR", e.message, null)
            }
        }
    }

    private fun hasStorage(): Boolean =
        if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager() ||
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        else checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    private fun requestStorage() {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName")))
                return
            } catch (_: Exception) {}
        }
        requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE), 42)
    }

    override fun onDestroy() {
        display?.stop()
        if (::runtime.isInitialized) runtime.stopAll()
        super.onDestroy()
    }
}
