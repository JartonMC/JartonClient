// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QFrame>
#include <QString>
#include <QUrl>
#include <QHash>

class QTextBrowser;
class QTimer;
class QPropertyAnimation;
class QNetworkAccessManager;
class QNetworkReply;

namespace Jarton {

class ChangelogService;

class ChangelogPanel : public QFrame {
    Q_OBJECT
   public:
    explicit ChangelogPanel(ChangelogService* service, QWidget* parent = nullptr);

   protected:
    bool eventFilter(QObject* obj, QEvent* ev) override;

   private slots:
    void onMarkdownChanged();
    void onDriftTick();
    void onPauseFinished();
    void onImageFinished();

   private:
    void applyMarkdown();
    void requestImage(const QUrl& url);

    ChangelogService* m_service = nullptr;
    QTextBrowser* m_text = nullptr;
    QTimer* m_drift = nullptr;
    QTimer* m_pause = nullptr;
    QPropertyAnimation* m_returnAnim = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    QHash<QUrl, QNetworkReply*> m_pendingImages;
    bool m_userInteracting = false;
};

}  // namespace Jarton
