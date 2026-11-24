#include <jni.h>
#include <string>
#include <android/log.h>
#include <unistd.h>
#include <sys/wait.h>
#include <cstdlib>
#include <dlfcn.h>

#define LOG_TAG "PCEmulator"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static pid_t g_pid = -1;
static void* g_box64_handle = nullptr;

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_pc_1emulator_NativeBridge_hello(JNIEnv* env, jclass) {
    return env->NewStringUTF("PC Emulator native engine (box64+Wine hook ready)");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_pc_1emulator_NativeBridge_loadEngineLibs(JNIEnv* env, jclass) {
    // Attempt to dynamically load the engine binaries.
    // If they are present in jniLibs/<abi>/, dlopen will succeed.
    g_box64_handle = dlopen("libbox64.so", RTLD_NOW | RTLD_GLOBAL);
    if (g_box64_handle) {
        LOGI("Successfully loaded libbox64.so");
        return JNI_TRUE;
    } else {
        LOGE("Failed to load libbox64.so: %s", dlerror());
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_pc_1emulator_NativeBridge_initEngine(JNIEnv* env, jclass, jstring gamePath, jint ramMB, jint cores) {
    const char* path = env->GetStringUTFChars(gamePath, nullptr);
    LOGI("initEngine: %s (ram=%d cores=%d)", path, ramMB, cores);

    if (!g_box64_handle) {
        if (!Java_com_example_pc_1emulator_NativeBridge_loadEngineLibs(env, nullptr)) {
            LOGE("Engine libraries not found. Please ensure libbox64.so is in jniLibs.");
            env->ReleaseStringUTFChars(gamePath, path);
            return -1;
        }
    }

    // In a real scenario, box64 and wine are executables.
    // We exec them via the Android linker.
    g_pid = fork();
    if (g_pid == 0) {
        // Child process: launch wine via box64
        setenv("WINEPREFIX", "/data/local/tmp/.wine", 1);

        // Construct the command to run box64 with wine
        // Note: box64 and wine binaries must be executable and in PATH or specified by absolute path
        execlp("sh", "sh", "-c",
               "export LD_LIBRARY_PATH=/data/app/*/lib/arm64:/data/local/tmp; "
               "box64 wine \"$1\"", "sh", path, (char*)nullptr);
        _exit(127);
    } else if (g_pid > 0) {
        LOGI("Launched emulation process pid=%d", g_pid);
    } else {
        LOGE("fork failed");
    }

    env->ReleaseStringUTFChars(gamePath, path);
    return g_pid > 0 ? 0 : -1;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_pc_1emulator_NativeBridge_stopEngine(JNIEnv*, jclass) {
    if (g_pid > 0) {
        kill(g_pid, SIGTERM);
        waitpid(g_pid, nullptr, 0);
        g_pid = -1;
        LOGI("stopEngine: terminated");
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_pc_1emulator_NativeBridge_isRunning(JNIEnv*, jclass) {
    if (g_pid <= 0) return JNI_FALSE;
    int status;
    pid_t r = waitpid(g_pid, &status, WNOHANG);
    if (r == 0) return JNI_TRUE; // still running
    g_pid = -1;
    return JNI_FALSE;
}