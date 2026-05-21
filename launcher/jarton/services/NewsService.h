// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

namespace Jarton {

// Fetches a markdown changelog from the CDN every 15 minutes and exposes it as
// one big Q_PROPERTY for the home tab's news panel to render with Text.MarkdownText.
// One file, edit-and-push admin workflow, same as the manifest.
class NewsService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString markdown READ markdown NOTIFY changed)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)

   public:
    explicit NewsService(QObject* parent = nullptr);
    ~NewsService() override;

    QString markdown() const { return m_markdown; }
    bool ready() const { return !m_markdown.isEmpty(); }

    void setEndpointUrl(const QString& url);

    Q_INVOKABLE void refreshNow();

   signals:
    void changed();

   private slots:
    void onReplyFinished();

   private:
    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_inFlight = nullptr;
    QTimer* m_timer = nullptr;
    QString m_endpoint;
    QString m_markdown;
};

}  // namespace Jarton
