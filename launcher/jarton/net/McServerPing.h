// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QByteArray>
#include <QString>
#include <cstdint>

namespace Jarton {

struct McPingResult {
    bool ok = false;
    int playersOnline = 0;
    int playersMax = 0;
    QString motd;
    QString versionName;
    int protocolVersion = 0;
    int latencyMs = 0;
    QString errorString;
};

// Minecraft "server list ping" protocol (handshake + status request).
// Pure encoder/decoder; the transport (QTcpSocket, QTimer, threading) is
// the caller's problem. Tested against canned responses without an event loop.
class McServerPing {
   public:
    static QByteArray buildHandshake(const QString& host, uint16_t port, int protocolVersion = 770);
    static QByteArray buildStatusRequest();
    static McPingResult parseStatusResponse(const QByteArray& payload);

    // VarInt helpers, exposed for testing.
    static QByteArray writeVarInt(int32_t value);
    static int32_t readVarInt(const QByteArray& data, int& cursor, bool& ok);
};

}  // namespace Jarton
