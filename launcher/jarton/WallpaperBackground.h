// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QImage>
#include <QPixmap>
#include <QSize>
#include <QString>
#include <QWidget>

class QVariantAnimation;

namespace Jarton {

// Widget that paints a wallpaper image as its background and cross-fades
// smoothly between wallpapers when setWallpaperUrl() is called with a new
// path. Driven by WallpaperService.
class WallpaperBackground : public QWidget {
    Q_OBJECT
   public:
    explicit WallpaperBackground(QWidget* parent = nullptr);

   public slots:
    void setWallpaperUrl(const QString& url);

   protected:
    void paintEvent(QPaintEvent* event) override;

   private:
    // Rescale both source images to fit `target` once, caching the result. The fade only
    // changes opacity, so paintEvent can blit these without touching QImage::scaled again.
    void rebuildScaled(const QSize& target);

    QImage m_current;
    QImage m_incoming;
    QPixmap m_currentScaled;
    QPixmap m_incomingScaled;
    QSize m_scaledFor;   // size the cached pixmaps were built for; invalid forces a rebuild
    qreal m_fade = 1.0;  // 1.0 = fully showing m_current
    QVariantAnimation* m_anim = nullptr;
};

}  // namespace Jarton
