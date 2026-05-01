#include <jni.h>
#include <string>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <android/log.h>
#include <time.h>
#include <sys/stat.h>

#define LOG_TAG "AIOS-Crash"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

static char g_log_dir[512] = {0};
static struct sigaction g_old_sigsegv;
static struct sigaction g_old_sigabrt;
static struct sigaction g_old_sigbus;
static struct sigaction g_old_sigfpe;

static void write_signal_log(int sig) {
    if (g_log_dir[0] == '\0') return;

    time_t now = time(nullptr);
    struct tm *tm_info = localtime(&now);
    char filename[600];
    strftime(filename, sizeof(filename), "%Y-%m-%d_%H-%M-%S", tm_info);
    char filepath[800];
    snprintf(filepath, sizeof(filepath), "%s/signal_%s.log", g_log_dir, filename);

    int fd = open(filepath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;

    const char *sig_name = "UNKNOWN";
    switch (sig) {
        case SIGABRT: sig_name = "SIGABRT"; break;
        case SIGSEGV: sig_name = "SIGSEGV"; break;
        case SIGBUS:  sig_name = "SIGBUS";  break;
        case SIGFPE:  sig_name = "SIGFPE";  break;
        case SIGPIPE: sig_name = "SIGPIPE"; break;
        case SIGTERM: sig_name = "SIGTERM"; break;
    }

    char header[1024];
    int len = snprintf(header, sizeof(header),
        "=== AIOS Native Crash Log ===\n"
        "Signal: %d (%s)\n"
        "PID: %d\n"
        "TID: %d\n"
        "\n"
        "This was a native crash. Check logcat for stack trace:\n"
        "  adb logcat | grep -E 'AIOS|DEBUG|CRASH'\n"
        "\n"
        "Run for detailed tombstone:\n"
        "  adb logcat -b crash\n",
        sig, sig_name, getpid(), gettid());

    write(fd, header, len);
    fsync(fd);
    close(fd);

    LOGI("Signal crash log written: %s (signal %d/%s)", filepath, sig, sig_name);
}

static void crash_signal_handler(int sig, siginfo_t *info, void *ctx) {
    write_signal_log(sig);

    struct sigaction *old_action = nullptr;
    switch (sig) {
        case SIGSEGV: old_action = &g_old_sigsegv; break;
        case SIGABRT: old_action = &g_old_sigabrt; break;
        case SIGBUS:  old_action = &g_old_sigbus;  break;
        case SIGFPE:  old_action = &g_old_sigfpe;  break;
        default: break;
    }

    if (old_action && old_action->sa_sigaction) {
        old_action->sa_sigaction(sig, info, ctx);
    } else if (old_action && old_action->sa_handler) {
        old_action->sa_handler(sig);
    } else {
        signal(sig, SIG_DFL);
        raise(sig);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_agent_aios_crash_CrashLogManager_nativeInstallSignalHandler(
        JNIEnv *env, jobject thiz, jstring log_dir) {
    if (log_dir) {
        const char *dir = env->GetStringUTFChars(log_dir, nullptr);
        if (dir) {
            snprintf(g_log_dir, sizeof(g_log_dir), "%s", dir);
            env->ReleaseStringUTFChars(log_dir, dir);
        }
    }

    struct sigaction sa;
    sigemptyset(&sa.sa_mask);
    sa.sa_sigaction = crash_signal_handler;
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;

    sigaction(SIGSEGV, &sa, &g_old_sigsegv);
    sigaction(SIGABRT, &sa, &g_old_sigabrt);
    sigaction(SIGBUS,  &sa, &g_old_sigbus);
    sigaction(SIGFPE,  &sa, &g_old_sigfpe);
}
