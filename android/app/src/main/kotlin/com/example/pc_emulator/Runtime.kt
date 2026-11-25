package com.example.pc_emulator

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.system.Os
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.GZIPInputStream

/**
 * Manages the Debian rootfs and runs commands inside it with proot.
 * proot (libproot.so) and its loader (libproot_loader.so) are bundled in jniLibs.
 */
class Runtime(private val ctx: Context, private val log: (String) -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val procs = ConcurrentHashMap<String, Process>()

    val base: File get() = ctx.filesDir
    val rootfs: File get() = File(base, "debian")
    val prootTmp: File get() = File(base, "proot-tmp").apply { mkdirs() }
    private val libDir: String get() = ctx.applicationInfo.nativeLibraryDir

    fun paths(): Map<String, String> = mapOf(
        "base" to base.absolutePath,
        "rootfs" to rootfs.absolutePath,
        "nativeLibDir" to libDir,
        "framebuffer" to File(rootfs, "tmp/fb/Xvfb_screen0").absolutePath,
    )

    fun rootfsReady(): Boolean = File(rootfs, "bin/bash").exists() || File(rootfs, "usr/bin/bash").exists()

    /** Download a .tar.gz rootfs and extract it. progress(0..1). */
    fun installRootfs(url: String, progress: (Double, String) -> Unit) {
        val tmp = File(ctx.cacheDir, "rootfs.tar.gz")
        progress(0.0, "Downloading Linux image")
        download(url, tmp) { p -> progress(p * 0.5, "Downloading Linux image") }
        progress(0.5, "Unpacking Linux image")
        if (rootfs.exists()) rootfs.deleteRecursively()
        rootfs.mkdirs()
        extractTarGz(tmp, rootfs) { p -> progress(0.5 + p * 0.5, "Unpacking Linux image") }
        tmp.delete()
        // Networking basics for apt inside proot
        File(rootfs, "etc/resolv.conf").apply { delete(); writeText("nameserver 8.8.8.8\nnameserver 1.1.1.1\n") }
        File(rootfs, "etc/hosts").writeText("127.0.0.1 localhost\n::1 localhost\n")
        File(rootfs, "tmp").apply { mkdirs(); setWritable(true, false) }
        // apt sandbox user cannot work under proot
        File(rootfs, "etc/apt/apt.conf.d/99pcemu").apply {
            parentFile?.mkdirs(); writeText("APT::Sandbox::User \"root\";\nAcquire::Retries \"3\";\n")
        }
        progress(1.0, "Linux image ready")
    }

    private fun download(url: String, dest: File, onProgress: (Double) -> Unit) {
        var u = URL(url)
        var conn: HttpURLConnection
        var redirects = 0
        while (true) {
            conn = u.openConnection() as HttpURLConnection
            conn.instanceFollowRedirects = false
            conn.connectTimeout = 20000
            conn.readTimeout = 60000
            val code = conn.responseCode
            if (code in 300..399 && redirects < 8) {
                u = URL(u, conn.getHeaderField("Location")); redirects++; conn.disconnect(); continue
            }
            if (code != 200) throw RuntimeException("Download failed: HTTP $code")
            break
        }
        val total = conn.contentLengthLong
        var done = 0L
        var last = 0L
        conn.inputStream.use { input ->
            FileOutputStream(dest).use { out ->
                val buf = ByteArray(256 * 1024)
                while (true) {
                    val n = input.read(buf); if (n < 0) break
                    out.write(buf, 0, n); done += n
                    if (total > 0 && done - last > 1_000_000) { last = done; onProgress(done.toDouble() / total) }
                }
            }
        }
    }

    private fun extractTarGz(src: File, dest: File, onProgress: (Double) -> Unit) {
        val total = src.length().toDouble()
        val counting = CountingStream(src.inputStream())
        val links = ArrayList<Pair<File, String>>()
        TarArchiveInputStream(GZIPInputStream(BufferedInputStream(counting, 1 shl 16))).use { tar ->
            var e: TarArchiveEntry? = tar.nextEntry
            var n = 0
            while (e != null) {
                val name = e.name.removePrefix("./")
                if (name.isNotEmpty() && !name.contains("..")) {
                    val out = File(dest, name)
                    when {
                        e.isDirectory -> { out.mkdirs(); chmod(out, e.mode) }
                        e.isSymbolicLink -> {
                            out.parentFile?.mkdirs(); out.delete()
                            try { Os.symlink(e.linkName, out.absolutePath) } catch (_: Exception) {}
                        }
                        e.isLink -> links.add(out to e.linkName.removePrefix("./"))
                        e.isFile -> {
                            out.parentFile?.mkdirs(); out.delete()
                            FileOutputStream(out).use { tar.copyTo(it, 1 shl 16) }
                            chmod(out, e.mode)
                        }
                        else -> {} // device nodes etc. are provided by proot binds
                    }
                }
                if (++n % 200 == 0) onProgress(counting.count / total)
                e = tar.nextEntry
            }
        }
        for ((out, target) in links) {
            val t = File(dest, target)
            out.parentFile?.mkdirs(); out.delete()
            try { Os.link(t.absolutePath, out.absolutePath) } catch (_: Exception) {
                try { t.copyTo(out, true); out.setExecutable(t.canExecute(), false) } catch (_: Exception) {}
            }
        }
    }

    private fun chmod(f: File, mode: Int) { try { Os.chmod(f.absolutePath, mode and 0xFFF) } catch (_: Exception) {} }

    private class CountingStream(private val inner: java.io.InputStream) : java.io.InputStream() {
        var count = 0L
        override fun read(): Int { val r = inner.read(); if (r >= 0) count++; return r }
        override fun read(b: ByteArray, off: Int, len: Int): Int { val r = inner.read(b, off, len); if (r > 0) count += r; return r }
        override fun close() = inner.close()
    }

    private fun prootCommand(cmd: String): List<String> {
        val ext = "/storage/emulated/0"
        val args = mutableListOf(
            "$libDir/libproot.so",
            "--kill-on-exit",
            "--link2symlink",
            "-0",
            "-r", rootfs.absolutePath,
            "-b", "/dev",
            "-b", "/proc",
            "-b", "/sys",
            "-b", "/proc/self/fd:/dev/fd",
            "-b", "${rootfs.absolutePath}/tmp:/dev/shm",
            "-w", "/root",
        )
        if (File(ext).exists()) { args += listOf("-b", "$ext:/sdcard") }
        args += listOf(
            "/usr/bin/env", "-i",
            "HOME=/root", "USER=root", "TERM=xterm-256color", "LANG=C.UTF-8",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/wine/bin",
            "TMPDIR=/tmp",
            "/bin/bash", "-lc", cmd
        )
        return args
    }

    private fun builder(cmd: String): ProcessBuilder {
        val pb = ProcessBuilder(prootCommand(cmd)).redirectErrorStream(true)
        pb.environment().apply {
            put("PROOT_LOADER", "$libDir/libproot_loader.so")
            put("PROOT_TMP_DIR", prootTmp.absolutePath)
        }
        return pb
    }

    /** Run a command to completion, streaming output to the log. Returns the exit code. */
    fun run(cmd: String): Int {
        val p = builder(cmd).start()
        p.inputStream.bufferedReader().forEachLine { log(it) }
        return p.waitFor()
    }

    /** Start a long-running named process (replacing any existing one with that name). */
    fun start(name: String, cmd: String, onExit: (Int) -> Unit) {
        stop(name)
        val p = builder(cmd).start()
        procs[name] = p
        Thread {
            try { p.inputStream.bufferedReader().forEachLine { log(it) } } catch (_: Exception) {}
            val code = try { p.waitFor() } catch (_: Exception) { -1 }
            if (procs[name] === p) procs.remove(name)
            main.post { onExit(code) }
        }.start()
    }

    fun isRunning(name: String): Boolean = procs[name]?.isAlive == true

    fun stop(name: String) {
        procs.remove(name)?.let { p ->
            try { p.destroy(); Thread.sleep(300); if (p.isAlive) p.destroyForcibly() } catch (_: Exception) {}
        }
    }

    fun stopAll() { procs.keys.toList().forEach { stop(it) } }
}
