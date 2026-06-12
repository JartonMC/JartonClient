// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QTimer;

namespace Jarton {

class JartonManifestService;

class ServerStatusService : public QObject {
    Q_OBJECT

    Q_PROPERTY(State state READ state NOTIFY statusChanged)
    Q_PROPERTY(int playersOnline READ playersOnline NOTIFY statusChanged)
    Q_PROPERTY(int playersMax READ playersMax NOTIFY statusChanged)
    Q_PROPERTY(QString motd READ motd NOTIFY statusChanged)
    Q_PROPERTY(int latencyMs READ latencyMs NOTIFY statusChanged)
    Q_PROPERTY(QString host READ host NOTIFY statusChanged)

   public:
    enum State : uint8_t { Unknown, Online, Offline };
    Q_ENUM(State)

    explicit ServerStatusService(JartonManifestService* manifest, QObject* parent = nullptr);
    ~ServerStatusService() override;

    State state() const { return m_state; }
    int playersOnline() const { return m_playersOnline; }
    int playersMax() const { return m_playersMax; }
    QString motd() const { return m_motd; }
    int latencyMs() const { return m_latencyMs; }
    QString host() const { return m_host; }

    Q_INVOKABLE void pingNow();

   signals:
    void statusChanged();

   private slots:
    void onManifestChanged(bool stale);

   private:
    void runPing();

    JartonManifestService* m_manifest = nullptr;
    QTimer* m_timer = nullptr;
    QString m_host;
    uint16_t m_port = 25565;
    State m_state = Unknown;
    int m_playersOnline = 0;
    int m_playersMax = 0;
    int m_latencyMs = 0;
    int m_consecutiveFailures = 0;
    QString m_motd;
    bool m_pingInFlight = false;
};

}  // namespace Jarton
