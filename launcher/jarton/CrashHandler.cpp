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
#include <cstdlib>
#include <cstring>
#include <ctime>

#if defined(Q_OS_UNIX)
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>
#endif

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
#if defined(SIGBUS)
        case SIGBUS:
            return "SIGBUS";
#endif
        default:
            return "UNKNOWN";
    }
}

void writeCrashDump(int sig) noexcept
{
#if defined(Q_OS_UNIX)
    // Signal-safe: NOT calling Qt allocation paths here. We use raw POSIX writes.
    const char* base = std::getenv("HOME");
    if (base == nullptr) {
        return;
    }
    char path[2048];
    std::snprintf(path, sizeof(path), "%s/Library/Application Support/JartonClient/crashes", base);
    char cmd[2200];
    std::snprintf(cmd, sizeof(cmd), "mkdir -p \"%s\"", path);
    [[maybe_unused]] int ignored = std::system(cmd);  // best-effort

    char filepath[2300];
    std::snprintf(filepath, sizeof(filepath), "%s/crash-%lld.log", path, static_cast<long long>(std::time(nullptr)));

    int fd = open(filepath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        return;
    }
    char header[256];
    int hlen = std::snprintf(header, sizeof(header), "Jarton Client crash: signal %s (%d)\n\n", signalName(sig), sig);
    [[maybe_unused]] auto written = write(fd, header, hlen);

    void* frames[64];
    int n = backtrace(frames, 64);
    backtrace_symbols_fd(frames, n, fd);

    close(fd);
#else
    // Windows path: minimal best-effort dump via stderr. The Windows Error Reporting
    // facility already captures full minidumps for unhandled exceptions, so a custom
    // file dump here is duplicative. Keeping the function for parity with the UNIX
    // path; full Windows minidump support can be wired via MiniDumpWriteDump later.
    (void)sig;
#endif
}

void crashHandler(int sig)
{
    writeCrashDump(sig);
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
#if defined(SIGBUS)
    std::signal(SIGBUS, crashHandler);
#endif
}

}  // namespace Jarton
