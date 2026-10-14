package com.priti.insta_story_app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newCachedThreadPool()

    private var methodChannel: MethodChannel? = null
    private var progressSink: EventChannel.EventSink? = null
    private var pendingSharedText: String? = null
    private var permissionResult: MethodChannel.Result? = null
    private var loginResult: MethodChannel.Result? = null

    @Volatile
    private var engineReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        methodChannel = MethodChannel(messenger, "insta_saver/engine").apply {
            setMethodCallHandler(::onMethodCall)
        }

        EventChannel(messenger, "insta_saver/progress").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            }
        )

        pendingSharedText = extractSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent) ?: return
        methodChannel?.invokeMethod("sharedText", text)
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeSharedText" -> {
                result.success(pendingSharedText)
                pendingSharedText = null
            }
            "ensureStoragePermission" -> ensureStoragePermission(result)
            "isSignedIn" -> result.success(LoginActivity.cookieFile(this).exists())
            "signIn" -> {
                loginResult = result
                @Suppress("DEPRECATION")
                startActivityForResult(Intent(this, LoginActivity::class.java), LOGIN_REQUEST)
            }
            "signOut" -> {
                LoginActivity.signOut(this)
                result.success(true)
            }
            "init" -> runAsync(result) { initEngine() }
            "version" -> runAsync(result) { YoutubeDL.getInstance().versionName(applicationContext) }
            "update" -> runAsync(result) { updateEngine() }
            "download" -> runAsync(result) {
                download(
                    url = call.argument<String>("url")!!,
                    taskId = call.argument<String>("taskId")!!,
                )
            }
            "cancel" -> {
                val taskId = call.argument<String>("taskId")!!
                result.success(YoutubeDL.getInstance().destroyProcessById(taskId))
            }
            "open" -> {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val intent = Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "video/mp4")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                runCatching { startActivity(intent) }
                    .onSuccess { result.success(true) }
                    .onFailure { result.error("OPEN_FAILED", it.message, null) }
            }
            "share" -> {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                val send = Intent(Intent.ACTION_SEND)
                    .setType("video/mp4")
                    .putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                startActivity(Intent.createChooser(send, null))
                result.success(true)
            }
            "delete" -> runAsync(result) {
                val uri = Uri.parse(call.argument<String>("uri")!!)
                // Fails after a reinstall (we no longer own the file); caller just drops the history row.
                runCatching { contentResolver.delete(uri, null, null) > 0 }.getOrDefault(false)
            }
            else -> result.notImplemented()
        }
    }

    /** Android 10+ saves through MediaStore with no permission; Android 9 and below need write access. */
    private fun ensureStoragePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != LOGIN_REQUEST) return
        loginResult?.success(resultCode == RESULT_OK)
        loginResult = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_REQUEST) return
        permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Throwable) {
                mainHandler.post { result.error("ENGINE_ERROR", describe(e), null) }
            }
        }
    }

    /** Runs `yt-dlp --version` to tell "engine can't start" apart from "Instagram refused". */
    private fun engineSelfCheck(): String = runCatching {
        val response = YoutubeDL.getInstance().execute(YoutubeDLRequest(emptyList()).addOption("--version"))
        "ok, yt-dlp ${response.out.trim()} (Android ${Build.VERSION.RELEASE}, ${Build.SUPPORTED_ABIS.firstOrNull()})"
    }.getOrElse { "FAILED: ${describe(it)} (Android ${Build.VERSION.RELEASE}, ${Build.SUPPORTED_ABIS.firstOrNull()})" }

    /** Full error text including causes; library exceptions often carry an empty message. */
    private fun describe(error: Throwable): String {
        val parts = generateSequence(error) { it.cause }
            .take(4)
            .map { e -> e.message?.trim()?.takeIf { it.isNotEmpty() } ?: e.javaClass.simpleName }
            .distinct()
            .toList()
        return parts.joinToString("\nCaused by: ").ifBlank { error.toString() }
    }

    // ---- yt-dlp engine -------------------------------------------------------------------

    @Synchronized
    private fun initEngine(): String? {
        if (!engineReady) {
            // First launch unpacks python + yt-dlp + ffmpeg, which takes a few seconds.
            YoutubeDL.getInstance().init(applicationContext)
            FFmpeg.getInstance().init(applicationContext)
            engineReady = true
        }
        return YoutubeDL.getInstance().versionName(applicationContext)
    }

    private fun updateEngine(): Map<String, Any?> {
        initEngine()
        val status = YoutubeDL.getInstance()
            .updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.STABLE)
        return mapOf(
            "status" to status?.name,
            "version" to YoutubeDL.getInstance().versionName(applicationContext),
        )
    }

    private fun download(url: String, taskId: String): Map<String, Any?> {
        initEngine()
        val workDir = File(cacheDir, "dl_$taskId").apply {
            deleteRecursively()
            mkdirs()
        }
        // Temp names carry the metadata we need, so no separate info request hits Instagram.
        // On Instagram, yt-dlp's `channel` is the @username; `uploader_id` is a numeric account id.
        val template = "%(autonumber)s${SEP}%(channel,uploader,uploader_id|instagram)s${SEP}%(id)s.%(ext)s"

        try {
            val request = YoutubeDLRequest(url)
                // Best video + best audio merged into an MP4, falling back to the best single file.
                .addOption("-f", "bv*[ext=mp4]+ba[ext=m4a]/bv*+ba/b[ext=mp4]/b")
                .addOption("--merge-output-format", "mp4")
                .addOption("--no-mtime")
                .addOption("--restrict-filenames")
                .addOption("--write-thumbnail")
                .addOption("--convert-thumbnails", "jpg")
                .addOption("-o", "${workDir.absolutePath}/$template")
                .addOption("-o", "thumbnail:${workDir.absolutePath}/thumb_$template")

            // Instagram hides post data from logged-out clients; use the session from LoginActivity if present.
            val cookies = LoginActivity.cookieFile(this)
            if (cookies.exists()) request.addOption("--cookies", cookies.absolutePath)

            // yt-dlp sometimes exits non-zero with an empty stderr, so keep recent stdout for the error report.
            val recentOutput = ArrayDeque<String>()
            val failure = runCatching {
                YoutubeDL.getInstance().execute(request, taskId) { progress, eta, line ->
                    synchronized(recentOutput) {
                        recentOutput.addLast(line)
                        if (recentOutput.size > 15) recentOutput.removeFirst()
                    }
                    val event = mapOf(
                        "taskId" to taskId,
                        "progress" to progress.toDouble(),
                        "eta" to eta,
                        "line" to line,
                    )
                    mainHandler.post { progressSink?.success(event) }
                }
            }.exceptionOrNull()

            val videos = workDir.listFiles { f -> f.extension.equals("mp4", true) && !f.name.startsWith("thumb_") }
                ?.sortedBy { it.name }
                .orEmpty()
            if (videos.isEmpty()) {
                if (failure is YoutubeDL.CanceledException) throw IllegalStateException("Download canceled")
                val output = synchronized(recentOutput) { recentOutput.joinToString("\n") }
                throw IllegalStateException(
                    listOfNotNull(
                        failure?.let { describe(it) } ?: "No video found in this post",
                        output.takeIf { it.isNotBlank() }?.let { "Output:\n$it" },
                        failure?.let { "Engine check: ${engineSelfCheck()}" },
                    ).joinToString("\n")
                )
            }
            // A video file exists, so a late failure (e.g. thumbnail conversion) isn't fatal.

            val parts = videos.first().nameWithoutExtension.split(SEP)
            val uploader = parts.drop(1).dropLast(1).joinToString(SEP).ifEmpty { "instagram" }
            val mediaId = parts.lastOrNull()?.takeIf { parts.size >= 3 } ?: taskId
            val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val kind = if ("/stories/" in url) "story" else "reel"
            val baseName = "${kind}_${uploader}_${mediaId}_$stamp"

            val thumbDir = File(filesDir, "thumbs").apply { mkdirs() }
            val thumb = workDir.listFiles { f -> f.name.startsWith("thumb_") }?.minByOrNull { it.name }
            val savedThumb = thumb?.let {
                val target = File(thumbDir, "$taskId.jpg")
                it.copyTo(target, overwrite = true)
                target.absolutePath
            }

            val saved = videos.mapIndexed { index, file ->
                val name = if (videos.size == 1) "$baseName.mp4" else "${baseName}_${index + 1}.mp4"
                mapOf(
                    "uri" to saveToDownloads(file, name).toString(),
                    "fileName" to name,
                    "size" to file.length(),
                )
            }

            return mapOf(
                "files" to saved,
                "thumbnail" to savedThumb,
                "uploader" to uploader,
                "mediaId" to mediaId,
            )
        } finally {
            workDir.deleteRecursively()
        }
    }

    // ---- Saving to Download/PrettySaver -----------------------------------------------------

    private fun saveToDownloads(source: File, displayName: String): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$ALBUM")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = contentResolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create file in Downloads")
            try {
                contentResolver.openOutputStream(uri)!!.use { out ->
                    source.inputStream().use { it.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                uri
            } catch (e: Throwable) {
                contentResolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                ALBUM,
            ).apply { mkdirs() }
            val target = uniqueFile(dir, displayName)
            source.copyTo(target)
            scanFile(target) ?: Uri.fromFile(target)
        }
    }

    private fun uniqueFile(dir: File, name: String): File {
        var file = File(dir, name)
        var i = 1
        while (file.exists()) {
            file = File(dir, "${name.substringBeforeLast('.')}($i).${name.substringAfterLast('.')}")
            i++
        }
        return file
    }

    /** Registers the file with MediaStore so it shows up in the gallery, returning its content URI. */
    private fun scanFile(file: File): Uri? {
        val latch = CountDownLatch(1)
        var scanned: Uri? = null
        MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf("video/mp4")) { _, uri ->
            scanned = uri
            latch.countDown()
        }
        latch.await(10, TimeUnit.SECONDS)
        return scanned
    }

    companion object {
        private const val ALBUM = "PrettySaver"
        private const val SEP = "__"
        private const val STORAGE_REQUEST = 4201
        private const val LOGIN_REQUEST = 4202
    }
}
