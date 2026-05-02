#include <jni.h>
#include <string>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <android/log.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/prctl.h>
#include <unwind.h>
#include <inttypes.h>

#define LOG_TAG "AIOS-Crash"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static const int MAX_BACKTRACE_FRAMES = 64;

static char g_log_dir[512] = {0};
static struct sigaction g_old_sa[32];

static const char *signal_name(int sig) {
    switch (sig) {
        case SIGABRT: return "SIGABRT";
        case SIGSEGV: return "SIGSEGV";
        case SIGBUS:  return "SIGBUS";
        case SIGFPE:  return "SIGFPE";
        case SIGILL:  return "SIGILL";
        case SIGTRAP: return "SIGTRAP";
        case SIGPIPE: return "SIGPIPE";
        case SIGTERM: return "SIGTERM";
        default:      return "UNKNOWN";
    }
}

static const char *signal_code_name(int sig, int code) {
    switch (sig) {
        case SIGSEGV:
            switch (code) {
                case SEGV_MAPERR: return "SEGV_MAPERR (address not mapped)";
                case SEGV_ACCERR: return "SEGV_ACCERR (invalid permissions)";
                default:          return "UNKNOWN";
            }
        case SIGBUS:
            switch (code) {
                case BUS_ADRALN: return "BUS_ADRALN (invalid address alignment)";
                case BUS_ADRERR: return "BUS_ADRERR (nonexistent physical address)";
                case BUS_OBJERR: return "BUS_OBJERR (object-specific hardware error)";
                default:          return "UNKNOWN";
            }
        case SIGFPE:
            switch (code) {
                case FPE_INTDIV: return "FPE_INTDIV (integer divide by zero)";
                case FPE_INTOVF: return "FPE_INTOVF (integer overflow)";
                case FPE_FLTDIV: return "FPE_FLTDIV (float divide by zero)";
                default:          return "UNKNOWN";
            }
        case SIGILL:
            switch (code) {
                case ILL_ILLOPC: return "ILL_ILLOPC (illegal opcode)";
                case ILL_ILLOPN: return "ILL_ILLOPN (illegal operand)";
                case ILL_ILLADR: return "ILL_ILLADR (illegal addressing mode)";
                default:          return "UNKNOWN";
            }
        default:
            return "";
    }
}

struct BacktraceContext {
    size_t frame_index;
    uintptr_t frames[MAX_BACKTRACE_FRAMES];
};

static _Unwind_Reason_Code unwind_callback(struct _Unwind_Context *ctx, void *data) {
    BacktraceContext *bt = reinterpret_cast<BacktraceContext *>(data);
    if (bt->frame_index >= MAX_BACKTRACE_FRAMES) {
        return _URC_END_OF_STACK;
    }
    uintptr_t pc = _Unwind_GetIP(ctx);
    if (pc == 0) {
        return _URC_END_OF_STACK;
    }
    bt->frames[bt->frame_index++] = pc;
    return _URC_NO_REASON;
}

static int g_crash_fd = -1;

static void safe_write(const char *buf, size_t len) {
    if (g_crash_fd < 0) return;
    while (len > 0) {
        ssize_t ret = write(g_crash_fd, buf, len);
        if (ret <= 0) break;
        buf += ret;
        len -= ret;
    }
}

static void safe_str(const char *s) {
    if (s) safe_write(s, strlen(s));
}

static void safe_char(char c) {
    safe_write(&c, 1);
}

static void safe_uint(unsigned int v) {
    if (v == 0) { safe_char('0'); return; }
    char buf[16];
    int pos = 0;
    while (v > 0) { buf[pos++] = '0' + (v % 10); v /= 10; }
    for (int i = pos - 1; i >= 0; i--) safe_char(buf[i]);
}

static void safe_hex(uintptr_t v) {
    safe_str("0x");
    if (v == 0) { safe_char('0'); return; }
    char buf[20];
    int pos = 0;
    while (v > 0) { buf[pos++] = "0123456789abcdef"[v % 16]; v /= 16; }
    for (int i = pos - 1; i >= 0; i--) safe_char(buf[i]);
}

static void safe_int(intptr_t v) {
    if (v < 0) { safe_char('-'); v = -v; }
    safe_uint((unsigned int)v);
}

static void write_registers(void *context) {
#if defined(__aarch64__)
    ucontext_t *uc = reinterpret_cast<ucontext_t *>(context);
    mcontext_t *mc = &uc->uc_mcontext;
    safe_str("Registers:\n");
    for (int i = 0; i < 31; i++) {
        safe_str("  x");
        safe_uint(i);
        safe_str("=");
        safe_hex(mc->regs[i]);
        safe_str("\n");
    }
    safe_str("  sp=");
    safe_hex(mc->sp);
    safe_str(" pc=");
    safe_hex(mc->pc);
    safe_str("\n");
#elif defined(__x86_64__)
    safe_str("Registers: (x86_64)\n");
#else
    safe_str("Registers: (unsupported arch)\n");
#endif
}

static void write_maps() {
    int maps_fd = open("/proc/self/maps", O_RDONLY);
    if (maps_fd < 0) return;

    safe_str("\nLoaded libraries:\n");

    char buf[4096];
    ssize_t n;
    bool first = true;
    int count = 0;

    while ((n = read(maps_fd, buf, sizeof(buf))) > 0 && count < 50) {
        for (ssize_t i = 0; i < n; i++) {
            if (buf[i] == '\n') {
                safe_char('\n');
                count++;
            } else {
                safe_char(buf[i]);
            }
        }
    }

    close(maps_fd);
}

static void crash_signal_handler(int sig, siginfo_t *info, void *context) {
    g_crash_fd = -1;

    if (g_log_dir[0] != '\0') {
        time_t now = time(nullptr);
        struct tm *tm_info = localtime(&now);
        char filepath[600];
        snprintf(filepath, sizeof(filepath), "%s/signal_%04d-%02d-%02d_%02d-%02d-%02d.log",
                 g_log_dir,
                 tm_info->tm_year + 1900, tm_info->tm_mon + 1, tm_info->tm_mday,
                 tm_info->tm_hour, tm_info->tm_min, tm_info->tm_sec);

        g_crash_fd = open(filepath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    }

    if (g_crash_fd < 0) {
        char tmp[256];
        snprintf(tmp, sizeof(tmp), "/data/local/tmp/aios_crash_%d.log", getpid());
        g_crash_fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    }

    if (g_crash_fd >= 0) {
        safe_str("=== AIOS Native Crash Log ===\n");

        time_t now = time(nullptr);
        struct tm *tm_info = localtime(&now);
        char timebuf[64];
        snprintf(timebuf, sizeof(timebuf), "%04d-%02d-%02d %02d:%02d:%02d",
                 tm_info->tm_year + 1900, tm_info->tm_mon + 1, tm_info->tm_mday,
                 tm_info->tm_hour, tm_info->tm_min, tm_info->tm_sec);
        safe_str("Time: ");
        safe_str(timebuf);
        safe_str("\n");

        safe_str("Signal: ");
        safe_int(sig);
        safe_str(" (");
        safe_str(signal_name(sig));
        safe_str(")\n");

        if (info) {
            safe_str("Signal code: ");
            safe_int(info->si_code);
            safe_str(" (");
            safe_str(signal_code_name(sig, info->si_code));
            safe_str(")\n");

            safe_str("Fault address: ");
            safe_hex((uintptr_t)info->si_addr);
            safe_str("\n");
        }

        safe_str("PID: ");
        safe_int(getpid());
        safe_str("  TID: ");
        safe_int(gettid());
        safe_str("\n");

        BacktraceContext bt = {0, {0}};
        _Unwind_Backtrace(unwind_callback, &bt);

        safe_str("\nBacktrace (");
        safe_uint(bt.frame_index);
        safe_str(" frames):\n");

        for (size_t i = 0; i < bt.frame_index; i++) {
            safe_str("  #");
            if (i < 10) safe_char('0');
            safe_uint(i);
            safe_str(" pc ");
            safe_hex(bt.frames[i]);

            Dl_info dlinfo;
            if (dladdr(reinterpret_cast<void *>(bt.frames[i]), &dlinfo)) {
                safe_str("  ");

                if (dlinfo.dli_fname) {
                    const char *slash = strrchr(dlinfo.dli_fname, '/');
                    safe_str(slash ? slash + 1 : dlinfo.dli_fname);
                }

                if (dlinfo.dli_sname) {
                    safe_str(" (");
                    safe_str(dlinfo.dli_sname);
                    safe_str("+");
                    safe_hex((uintptr_t)bt.frames[i] - (uintptr_t)dlinfo.dli_saddr);
                    safe_str(")");
                } else if (dlinfo.dli_fbase) {
                    safe_str(" (+");
                    safe_hex((uintptr_t)bt.frames[i] - (uintptr_t)dlinfo.dli_fbase);
                    safe_str(")");
                }
            } else {
                safe_str("  <unknown>");
            }
            safe_str("\n");
        }

        if (context) {
            write_registers(context);
        }

        write_maps();

        safe_str("\n--- End of crash log ---\n");
        fsync(g_crash_fd);
        close(g_crash_fd);
        g_crash_fd = -1;
    }

    LOGE("=== NATIVE CRASH: signal %d (%s) at %p ===", sig, signal_name(sig), info ? info->si_addr : nullptr);

    struct sigaction *old_action = nullptr;
    if (sig >= 0 && sig < 32) {
        old_action = &g_old_sa[sig];
    }

    if (old_action && (old_action->sa_flags & SA_SIGINFO) && old_action->sa_sigaction) {
        old_action->sa_sigaction(sig, info, context);
    } else if (old_action && old_action->sa_handler && old_action->sa_handler != SIG_DFL && old_action->sa_handler != SIG_IGN) {
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

            mkdir(g_log_dir, 0755);
        }
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sigemptyset(&sa.sa_mask);
    sa.sa_sigaction = crash_signal_handler;
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;

    int signals[] = {SIGSEGV, SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGTRAP};
    for (int s : signals) {
        if (s < 32) {
            sigaction(s, &sa, &g_old_sa[s]);
        }
    }

    LOGI("Native signal handler installed (backtrace + dladdr enabled)");
}
