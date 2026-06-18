// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/PteroServer.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>
#include <QWebSocket>

#include "jarton/staff/StaffAuth.h"

namespace Jarton {

PteroServer::PteroServer(StaffAuth* auth, QObject* parent)
    : QObject(parent), m_auth(auth), m_nam(auth ? auth->network() : nullptr)
{
}

PteroServer::~PteroServer()
{
    if (m_ws) {
        m_ws->deleteLater();
    }
}

void PteroServer::open(const QString& serverId, const QString& serverName)
{
    if (m_serverId == serverId && m_wantOpen) {
        return;  // already live on this server
    }
    close();
    m_serverId = serverId;
    m_serverName = serverName;
    m_lines.clear();
    m_wantOpen = true;
    emit linesChanged();
    emit changed();
    fetchConsoleAuth(false);
}

void PteroServer::close()
{
    m_wantOpen = false;
    if (m_ws) {
        m_ws->abort();
        m_ws->deleteLater();
        m_ws = nullptr;
    }
    setConsoleState(QStringLiteral("idle"));
}

void PteroServer::setConsoleState(const QString& s)
{
    if (m_consoleState == s) {
        return;
    }
    m_consoleState = s;
    emit changed();
}

void PteroServer::fetchConsoleAuth(bool reauthOnly)
{
    if (!m_auth || m_serverId.isEmpty()) {
        return;
    }
    if (!reauthOnly) {
        setConsoleState(QStringLiteral("connecting"));
    }
    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers/" + m_serverId + "/console") };
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, reauthOnly]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            if (m_wantOpen) {
                setConsoleState(QStringLiteral("disconnected"));
            }
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QString token = obj.value("token").toString();
        const QString socket = obj.value("socket").toString();
        const QString origin = obj.value("origin").toString();
        if (reauthOnly) {
            sendFrame(QStringLiteral("auth"), { token });
            return;
        }
        connectSocket(socket, origin, token);
    });
}

void PteroServer::connectSocket(const QString& socketUrl, const QString& origin, const QString& token)
{
    if (m_ws) {
        m_ws->abort();
        m_ws->deleteLater();
    }
    m_ws = new QWebSocket();
    m_ws->setParent(this);

    connect(m_ws, &QWebSocket::connected, this, [this, token]() { sendFrame(QStringLiteral("auth"), { token }); });
    connect(m_ws, &QWebSocket::textMessageReceived, this, &PteroServer::onTextMessage);
    connect(m_ws, &QWebSocket::disconnected, this, [this]() {
        if (!m_wantOpen) {
            return;
        }
        setConsoleState(QStringLiteral("disconnected"));
        // wings drops the socket on token expiry / idle; re-auth and reconnect
        QTimer::singleShot(2000, this, [this]() {
            if (m_wantOpen) {
                fetchConsoleAuth(false);
            }
        });
    });

    QNetworkRequest req{ QUrl(socketUrl) };
    if (!origin.isEmpty()) {
        req.setRawHeader("Origin", origin.toUtf8());
    }
    m_ws->open(req);
}

void PteroServer::onTextMessage(const QString& text)
{
    const QJsonObject frame = QJsonDocument::fromJson(text.toUtf8()).object();
    const QString event = frame.value("event").toString();
    const QJsonArray args = frame.value("args").toArray();
    const QString first = args.isEmpty() ? QString() : args.first().toString();

    if (event == QStringLiteral("auth success")) {
        setConsoleState(QStringLiteral("live"));
        sendFrame(QStringLiteral("send logs"), {});
        sendFrame(QStringLiteral("send stats"), {});
    } else if (event == QStringLiteral("console output")) {
        appendLine(first);
    } else if (event == QStringLiteral("stats")) {
        const QJsonObject s = QJsonDocument::fromJson(first.toUtf8()).object();
        m_cpu = s.value("cpu_absolute").toDouble();
        m_mem = static_cast<qlonglong>(s.value("memory_bytes").toDouble());
        m_memLimit = static_cast<qlonglong>(s.value("memory_limit_bytes").toDouble());
        m_disk = static_cast<qlonglong>(s.value("disk_bytes").toDouble());
        m_uptime = static_cast<qlonglong>(s.value("uptime").toDouble());
        const QString st = s.value("state").toString();
        if (!st.isEmpty()) {
            m_runState = st;
        }
        emit statsChanged();
    } else if (event == QStringLiteral("status")) {
        if (!first.isEmpty()) {
            m_runState = first;
            emit statsChanged();
        }
    } else if (event == QStringLiteral("token expiring")) {
        fetchConsoleAuth(true);
    } else if (event == QStringLiteral("token expired")) {
        if (m_ws) {
            m_ws->close();
        }
    }
}

void PteroServer::sendFrame(const QString& event, const QStringList& args)
{
    if (!m_ws) {
        return;
    }
    QJsonArray arr;
    for (const QString& a : args) {
        arr.append(a);
    }
    QJsonObject frame;
    frame.insert("event", event);
    frame.insert("args", arr);
    m_ws->sendTextMessage(QString::fromUtf8(QJsonDocument(frame).toJson(QJsonDocument::Compact)));
}

void PteroServer::sendCommand(const QString& command)
{
    if (command.trimmed().isEmpty() || m_consoleState != QStringLiteral("live")) {
        return;
    }
    sendFrame(QStringLiteral("send command"), { command });
}

namespace {
QString ansiColor(int code)
{
    switch (code) {
        case 30: case 90: return QStringLiteral("#6b6256");
        case 31: case 91: return QStringLiteral("#ff6b6b");
        case 32: case 92: return QStringLiteral("#7ee787");
        case 33: case 93: return QStringLiteral("#ffcf4d");
        case 34: case 94: return QStringLiteral("#79b8ff");
        case 35: case 95: return QStringLiteral("#d2a8ff");
        case 36: case 96: return QStringLiteral("#76e0e8");
        case 37: case 97: return QStringLiteral("#e6dcc4");
        default: return QString();
    }
}
QString htmlEscape(const QString& s)
{
    QString r = s;
    r.replace('&', QStringLiteral("&amp;")).replace('<', QStringLiteral("&lt;")).replace('>', QStringLiteral("&gt;"));
    return r;
}
}  // namespace

// Convert a wings console line (ANSI SGR colour codes) to HTML for Text.RichText. Cursor
// and other non-colour escapes are dropped. Default text colour is the honey console fg.
QString PteroServer::ansiToHtml(const QString& raw)
{
    QString out;
    QString run;
    QString color;  // empty = default

    auto flush = [&]() {
        if (run.isEmpty()) return;
        if (!color.isEmpty()) {
            out += "<span style=\"color:" + color + "\">" + htmlEscape(run) + "</span>";
        } else {
            out += htmlEscape(run);
        }
        run.clear();
    };

    for (int i = 0; i < raw.size(); ++i) {
        const QChar c = raw.at(i);
        if (c.unicode() == 0x1B && i + 1 < raw.size() && raw.at(i + 1) == '[') {
            // CSI sequence: read params until the final letter
            int j = i + 2;
            QString params;
            while (j < raw.size() && !raw.at(j).isLetter()) {
                params += raw.at(j);
                ++j;
            }
            const QChar final = j < raw.size() ? raw.at(j) : QChar();
            if (final == 'm') {
                flush();
                if (params.isEmpty() || params == QStringLiteral("0")) {
                    color.clear();
                } else {
                    for (const QString& p : params.split(';')) {
                        const int code = p.toInt();
                        if (code == 0) color.clear();
                        else { const QString col = ansiColor(code); if (!col.isEmpty()) color = col; }
                    }
                }
            }
            i = j;  // skip the whole escape
            continue;
        }
        if (c.unicode() == 0x1B) { ++i; continue; }  // ESC + single letter
        run += c;
    }
    flush();
    return out;
}

void PteroServer::appendLine(const QString& raw)
{
    const QString trimmed = raw.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }
    m_lines.append(ansiToHtml(trimmed));
    if (m_lines.size() > 500) {
        m_lines.remove(0, m_lines.size() - 500);
    }
    emit linesChanged();
}

void PteroServer::power(const QString& signal)
{
    if (!m_auth || m_serverId.isEmpty() || m_powerBusy) {
        return;
    }
    m_powerBusy = true;
    emit changed();

    QJsonObject body;
    body.insert("signal", signal);
    QNetworkRequest req{ QUrl(m_auth->baseUrl() + "/servers/" + m_serverId + "/power") };
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", "Bearer " + m_auth->token().toUtf8());
    req.setRawHeader("User-Agent", "JartonClient/staff");
    req.setTransferTimeout(15000);

    QNetworkReply* reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_powerBusy = false;
        emit changed();
    });
}

}  // namespace Jarton
