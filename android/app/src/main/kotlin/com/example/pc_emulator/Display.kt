package com.example.pc_emulator

import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.Rect
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteOrder
import java.nio.IntBuffer
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

/**
 * Shows the Xvfb framebuffer (Xvfb -fbdir writes an XWD file that it keeps mmap'd)
 * on a Flutter texture. No VNC, no copies through the network.
 */
class Display(private val textures: TextureRegistry) {
    private var entry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    @Volatile private var running = false
    private var thread: Thread? = null
    @Volatile var width = 0; private set
    @Volatile var height = 0; private set
    @Volatile var fps = 0; private set

    fun start(fbPath: String, w: Int, h: Int, targetFps: Int): Long {
        stop()
        val e = textures.createSurfaceTexture()
        e.surfaceTexture().setDefaultBufferSize(w, h)
        entry = e
        surface = Surface(e.surfaceTexture())
        width = w; height = h
        running = true
        thread = Thread({ loop(File(fbPath), targetFps) }, "fb-blit").apply { start() }
        return e.id()
    }

    private fun loop(fb: File, targetFps: Int) {
        val paint = Paint().apply { isFilterBitmap = false }
        var map: MappedByteBuffer? = null
        var mappedLen = -1L
        var inode = -1L
        var bmp: Bitmap? = null
        var pixels = IntArray(0)
        var w = 0
        var h = 0
        var stride = 0
        var offset = 0
        val frameNs = 1_000_000_000L / targetFps.coerceIn(10, 60)
        var frames = 0
        var t0 = System.nanoTime()
        while (running) {
            val start = System.nanoTime()
            try {
                if (!fb.exists() || fb.length() < 128) {
                    map = null
                    Thread.sleep(100)
                    continue
                }
                val st = android.system.Os.stat(fb.absolutePath)
                if (map == null || fb.length() != mappedLen || st.st_ino != inode) {
                    val raf = RandomAccessFile(fb, "r")
                    mappedLen = raf.length()
                    val m = raf.channel.map(FileChannel.MapMode.READ_ONLY, 0, mappedLen)
                    raf.close()
                    inode = st.st_ino
                    m.order(ByteOrder.BIG_ENDIAN)
                    val headerSize = m.getInt(0)
                    w = m.getInt(16)
                    h = m.getInt(20)
                    val bpp = m.getInt(44)
                    stride = m.getInt(48)
                    val ncolors = m.getInt(76)
                    offset = headerSize + ncolors * 12
                    if (bpp != 32 || w <= 0 || h <= 0 || offset.toLong() + stride.toLong() * h > mappedLen) {
                        map = null
                        Thread.sleep(200)
                        continue
                    }
                    map = m
                    val old = bmp
                    if (old == null || old.width != w || old.height != h) {
                        bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        pixels = IntArray(w * h)
                        entry?.surfaceTexture()?.setDefaultBufferSize(w, h)
                        width = w
                        height = h
                    }
                }
                val m = map ?: continue
                val b = bmp ?: continue
                // Pixels are little-endian BGRX, i.e. LE ints 0xXXRRGGBB
                val dup = m.duplicate()
                dup.position(offset)
                val ib: IntBuffer = dup.slice().order(ByteOrder.LITTLE_ENDIAN).asIntBuffer()
                val rowInts = stride / 4
                if (rowInts == w) {
                    ib.get(pixels, 0, w * h)
                } else {
                    for (y in 0 until h) {
                        ib.position(y * rowInts)
                        ib.get(pixels, y * w, w)
                    }
                }
                for (i in pixels.indices) pixels[i] = pixels[i] or -0x1000000
                b.setPixels(pixels, 0, w, 0, 0, w, h)
                val s = surface ?: break
                val c = s.lockHardwareCanvas()
                try {
                    c.drawBitmap(b, null, Rect(0, 0, w, h), paint)
                } finally {
                    s.unlockCanvasAndPost(c)
                }
                frames++
                val now = System.nanoTime()
                if (now - t0 >= 1_000_000_000L) {
                    fps = frames
                    frames = 0
                    t0 = now
                }
            } catch (_: Exception) {
                map = null
                try { Thread.sleep(150) } catch (_: InterruptedException) {}
            }
            val spent = System.nanoTime() - start
            if (spent < frameNs) {
                try { Thread.sleep((frameNs - spent) / 1_000_000) } catch (_: InterruptedException) {}
            }
        }
    }

    fun stop() {
        running = false
        thread?.join(500); thread = null
        surface?.release(); surface = null
        entry?.release(); entry = null
    }
}
