// SPDX-License-Identifier: GPL-3.0-only
#include "ServerStatusService.h"

#include <QElapsedTimer>
#include <QFuture>
#include <QFutureWatcher>
#include <QLoggingCategory>
#include <QTcpSocket>
#include <QTimer>
#include <QtConcurrent/QtConcurrent>

Q_LOGGING_CATEGORY(jartonStatus, "jarton.status")

#include "JartonManifestService.h"
#include "jarton/net/McServerPing.h"

namespace Jarton {

namespace {
constexpr int g_pingIntervalMs = 30 * 1000;
constexpr int g_socketTimeoutMs = 5 * 1000;
constexpr int g_failuresUntilUnknown = 3;

struct PingOutcome {
    McPingResult result;
    int latencyMs = 0;
    QString transportError;
};

PingOutcome runPingSync(const QString& host, uint16_t port)
{
    PingOutcome outcome;
    QTcpSocket socket;
    QElapsedTimer clock;
    clock.start();

    socket.connectToHost(host, port);
    if (!socket.waitForConnected(g_socketTimeoutMs)) {
        outcome.transportError = QStringLiteral("connect failed: ") + socket.errorString();
        return outcome;
    }

    socket.write(McServerPing::buildHandshake(host, port));
    socket.write(McServerPing::buildStatusRequest());

    QByteArray buf;
    while (socket.waitForReadyRead(g_socketTimeoutMs)) {
        buf.append(socket.readAll());
        // Heuristic: keep reading until we have the full JSON. Status responses are
        // typically a few hundred bytes; if we have at least 5 bytes (varint + id)
        // we can attempt a parse and continue if it fails.
        const McPingResult tentative = McServerPing::parseStatusResponse(buf);
        if (tentative.ok) {
            outcome.result = tentative;
            outcome.latencyMs = static_cast<int>(clock.elapsed());
            return outcome;
        }
    }

    if (buf.isEmpty()) {
        outcome.transportError = QStringLiteral("no response: ") + socket.errorString();
    } else {
        outcome.result = McServerPing::parseStatusResponse(buf);
        if (!outcome.result.ok) {
            outcome.transportError = outcome.result.errorString.isEmpty() ? QStringLiteral("truncated response")
                                                                          : outcome.result.errorString;
        } else {
            outcome.latencyMs = static_cast<int>(clock.elapsed());
        }
    }
    return outcome;
}

}  // namespace

ServerStatusService::ServerStatusService(JartonManifestService* manifest, QObject* parent)
    : QObject(parent), m_manifest(manifest), m_timer(new QTimer(this))
{
    m_timer->setInterval(g_pingIntervalMs);
    connect(m_timer, &QTimer::timeout, this, &ServerStatusService::runPing);
    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &ServerStatusService::onManifestChanged);
        if (m_manifest->ready()) {
            onManifestChanged(m_manifest->stale());
        }
    }
}

ServerStatusService::~ServerStatusService() = default;

void ServerStatusService::onManifestChanged(bool /*stale*/)
{
    if (!m_manifest) {
        return;
    }
    const auto& inst = m_manifest->manifest().instance;
    if (inst.serverAddress.isEmpty()) {
        return;
    }
    const bool firstBoot = m_host.isEmpty();
    m_host = inst.serverAddress;
    m_port = inst.serverPort;
    emit statusChanged();
    if (firstBoot) {
        QTimer::singleShot(0, this, &ServerStatusService::pingNow);
        m_timer->start();
    }
}

void ServerStatusService::pingNow()
{
    runPing();
}

void ServerStatusService::runPing()
{
    if (m_pingInFlight || m_host.isEmpty()) {
        return;
    }
    m_pingInFlight = true;

    const QString host = m_host;
    const uint16_t port = m_port;

    auto* watcher = new QFutureWatcher<PingOutcome>(this);
    connect(watcher, &QFutureWatcher<PingOutcome>::finished, this, [this, watcher]() {
        watcher->deleteLater();
        m_pingInFlight = false;
        const PingOutcome outcome = watcher->result();

        if (outcome.result.ok) {
            m_consecutiveFailures = 0;
            m_state = Online;
            m_playersOnline = outcome.result.playersOnline;
            m_playersMax = outcome.result.playersMax;
            m_motd = outcome.result.motd;
            m_latencyMs = outcome.latencyMs;
            emit statusChanged();
            return;
        }

        qCWarning(jartonStatus) << "ping failed for" << m_host << ":" << m_port
                                << "—" << outcome.transportError;
        m_consecutiveFailures++;
        if (m_consecutiveFailures >= g_failuresUntilUnknown) {
            m_state = Unknown;
        } else {
            m_state = Offline;
        }
        m_playersOnline = 0;
        m_playersMax = 0;
        m_motd.clear();
        m_latencyMs = 0;
        emit statusChanged();
    });
    watcher->setFuture(QtConcurrent::run([host, port]() { return runPingSync(host, port); }));
}

}  // namespace Jarton
