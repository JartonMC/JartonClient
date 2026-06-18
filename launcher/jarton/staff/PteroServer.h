// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

class QNetworkAccessManager;
class QWebSocket;

namespace Jarton {

class StaffAuth;

// Live view of one Pterodactyl server for the desktop Pterodactyl section: the wings
// console websocket (logs + stats + command input) plus power control. Mirrors the iOS
// Companion's ConsoleSocket protocol — auth via a short-lived token from the broker's
// /servers/:id/console, then the standard wings frame events.
class PteroServer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString serverId READ serverId NOTIFY changed)
    Q_PROPERTY(QString serverName READ serverName NOTIFY changed)
    Q_PROPERTY(QString consoleState READ consoleState NOTIFY changed)  // idle|connecting|live|disconnected
    Q_PROPERTY(QString runState READ runState NOTIFY statsChanged)     // running|offline|starting|stopping
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY statsChanged)
    Q_PROPERTY(qlonglong memoryBytes READ memoryBytes NOTIFY statsChanged)
    Q_PROPERTY(qlonglong memoryLimitBytes READ memoryLimitBytes NOTIFY statsChanged)
    Q_PROPERTY(qlonglong diskBytes READ diskBytes NOTIFY statsChanged)
    Q_PROPERTY(qlonglong uptimeMs READ uptimeMs NOTIFY statsChanged)
    Q_PROPERTY(QStringList lines READ lines NOTIFY linesChanged)
    Q_PROPERTY(bool powerBusy READ powerBusy NOTIFY changed)

   public:
    explicit PteroServer(StaffAuth* auth, QObject* parent = nullptr);
    ~PteroServer() override;

    QString serverId() const { return m_serverId; }
    QString serverName() const { return m_serverName; }
    QString consoleState() const { return m_consoleState; }
    QString runState() const { return m_runState; }
    double cpuPercent() const { return m_cpu; }
    qlonglong memoryBytes() const { return m_mem; }
    qlonglong memoryLimitBytes() const { return m_memLimit; }
    qlonglong diskBytes() const { return m_disk; }
    qlonglong uptimeMs() const { return m_uptime; }
    QStringList lines() const { return m_lines; }
    bool powerBusy() const { return m_powerBusy; }

    Q_INVOKABLE void open(const QString& serverId, const QString& serverName);
    Q_INVOKABLE void close();
    Q_INVOKABLE void sendCommand(const QString& command);
    Q_INVOKABLE void power(const QString& signal);

   signals:
    void changed();
    void statsChanged();
    void linesChanged();

   private:
    void fetchConsoleAuth(bool reauthOnly);
    void connectSocket(const QString& socketUrl, const QString& origin, const QString& token);
    void onTextMessage(const QString& text);
    void sendFrame(const QString& event, const QStringList& args);
    void appendLine(const QString& raw);
    static QString ansiToHtml(const QString& raw);  // wings ANSI colour codes -> rich text
    void setConsoleState(const QString& s);

    StaffAuth* m_auth = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    QWebSocket* m_ws = nullptr;
    QString m_serverId;
    QString m_serverName;
    QString m_consoleState = QStringLiteral("idle");
    QString m_runState = QStringLiteral("offline");
    double m_cpu = 0.0;
    qlonglong m_mem = 0;
    qlonglong m_memLimit = 0;
    qlonglong m_disk = 0;
    qlonglong m_uptime = 0;
    QStringList m_lines;
    bool m_powerBusy = false;
    bool m_wantOpen = false;  // distinguishes a real close from a dropped socket (reconnect)
};

}  // namespace Jarton
