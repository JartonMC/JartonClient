// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>

namespace Jarton::Mac {

// Thin UNUserNotificationCenter wrapper for the staff alert banners.
// Both calls are no-ops when the process isn't running from a .app bundle
// (notification center refuses bare binaries).
void requestNotificationPermission();
void postNotification(const QString& title, const QString& body);

}  // namespace Jarton::Mac
