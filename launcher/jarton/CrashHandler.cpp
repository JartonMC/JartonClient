// SPDX-License-Identifier: GPL-3.0-only
#include "CrashHandler.h"

#include <QByteArray>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QString>

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstring>

#if defined(Q_OS_UNIX)
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>
#endif

#include <ctime>

namespace Jarton {

namespace {
std::atomic<bool> g_installed{ false };

const char* signalName(int sig)
{
    switch (sig) {
        case SIGSEGV:
            return "SIGSEGV";
        case SIGABRT:
            return "SIGABRT";
        case SIGFPE:
            return "SIGFPE";
        case SIGILL:
            return "SIGILL";
        case SIGBUS:
            return "SIGBUS";
        default:
            return "UNKNOWN";
    }
}

void writeCrashDump(int sig) noexcept
{
    // Signal-safe: NOT calling Qt allocation paths here. We use raw POSIX writes.
    const char* base = std::getenv("HOME");
    if (base == nullptr) {
        return;
    }
    char path[2048];
    std::snprintf(path, sizeof(path), "%s/Library/Application Support/JartonClient/crashes", base);
    // mkdir is signal-safe on POSIX.
#if defined(Q_OS_UNIX)
    char cmd[2200];
    std::snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", path);
    [[maybe_unused]] int ignored = std::system(cmd);  // best-effort
#endif
    char filepath[2300];
    std::snprintf(filepath, sizeof(filepath), "%s/crash-%lld.log", path, static_cast<long long>(std::time(nullptr)));

    int fd = open(filepath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        return;
    }
    char header[256];
    int hlen = std::snprintf(header, sizeof(header), "Jarton Client crash: signal %s (%d)\n\n", signalName(sig), sig);
    write(fd, header, hlen);

#if defined(Q_OS_UNIX)
    void* frames[64];
    int n = backtrace(frames, 64);
    backtrace_symbols_fd(frames, n, fd);
#endif

    close(fd);
}

void crashHandler(int sig)
{
    writeCrashDump(sig);
    // Restore default handler and re-raise so the OS produces its normal crash report.
    std::signal(sig, SIG_DFL);
    std::raise(sig);
}

}  // namespace

void installCrashHandler()
{
    if (g_installed.exchange(true)) {
        return;
    }
    std::signal(SIGSEGV, crashHandler);
    std::signal(SIGABRT, crashHandler);
    std::signal(SIGFPE, crashHandler);
    std::signal(SIGILL, crashHandler);
    std::signal(SIGBUS, crashHandler);
}

}  // namespace Jarton
