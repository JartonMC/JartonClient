// SPDX-License-Identifier: GPL-3.0-only
#pragma once

namespace Jarton {

// Install signal handlers (SIGSEGV/SIGABRT/SIGFPE/SIGILL) that dump a
// stack trace + last log lines to ~/.jartonclient/crashes/crash-<ts>.log,
// then call the previously installed handler. Idempotent.
void installCrashHandler();

}  // namespace Jarton
