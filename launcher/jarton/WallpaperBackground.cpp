// SPDX-License-Identifier: GPL-3.0-only
#include "WallpaperBackground.h"

#include <QGraphicsBlurEffect>
#include <QGraphicsPixmapItem>
#include <QGraphicsScene>
#include <QImageReader>
#include <QLinearGradient>
#include <QPaintEvent>
#include <QPainter>
#include <QUrl>
#include <QVariantAnimation>

namespace Jarton {

namespace {
// Light frosted blur on the wallpaper so the instance grid and overlays read cleanly
// over it. Applied once per wallpaper/resize into the cached pixmap, never per frame.
constexpr qreal g_blurRadius = 15.0;

QPixmap frosted(const QPixmap& src)
{
    if (src.isNull()) {
        return src;
    }
    QGraphicsScene scene;
    auto* item = new QGraphicsPixmapItem(src);
    auto* blur = new QGraphicsBlurEffect;
    blur->setBlurRadius(g_blurRadius);
    blur->setBlurHints(QGraphicsBlurEffect::QualityHint);
    item->setGraphicsEffect(blur);  // scene takes ownership of item; item owns the effect
    scene.addItem(item);

    QImage out(src.size(), QImage::Format_ARGB32_Premultiplied);
    out.fill(Qt::transparent);
    QPainter p(&out);
    scene.render(&p, QRectF(), QRectF(QPointF(0, 0), QSizeF(src.size())));
    p.end();
    return QPixmap::fromImage(out);
}
}  // namespace

WallpaperBackground::WallpaperBackground(QWidget* parent) : QWidget(parent), m_anim(new QVariantAnimation(this))
{
    setAttribute(Qt::WA_StyledBackground, true);
    setAutoFillBackground(true);

    m_anim->setStartValue(qreal{ 0.0 });
    m_anim->setEndValue(qreal{ 1.0 });
    m_anim->setDuration(1400);
    m_anim->setEasingCurve(QEasingCurve::InOutQuad);
    connect(m_anim, &QVariantAnimation::valueChanged, this, [this](const QVariant& v) {
        m_fade = 1.0 - v.toReal();  // start: 1.0 → end: 0.0; current fades out, incoming fades in
        update();
    });
    connect(m_anim, &QVariantAnimation::finished, this, [this]() {
        m_current = m_incoming;
        m_incoming = QImage();
        m_currentScaled = m_incomingScaled;  // already scaled to the current size; no re-scale needed
        m_incomingScaled = QPixmap();
        m_fade = 1.0;
        update();
    });
}

void WallpaperBackground::setWallpaperUrl(const QString& url)
{
    if (url.isEmpty()) {
        return;
    }
    const QUrl parsed(url);
    QString readerPath;
    if (parsed.scheme() == QLatin1String("qrc")) {
        // qrc:/foo.jpg → :/foo.jpg (the form QImageReader accepts for resources)
        readerPath = QStringLiteral(":") + parsed.path();
    } else if (parsed.isLocalFile()) {
        readerPath = parsed.toLocalFile();
    } else {
        // Remote URLs are downloaded by WallpaperService; nothing to render until
        // the cached file lands and we get called again with a file:// path.
        return;
    }
    QImageReader reader(readerPath);
    reader.setAutoTransform(true);
    QImage img = reader.read();
    if (img.isNull()) {
        return;
    }
    if (m_current.isNull()) {
        m_current = std::move(img);
        m_fade = 1.0;
        m_scaledFor = QSize();
        update();
        return;
    }
    m_incoming = std::move(img);
    m_scaledFor = QSize();
    m_anim->stop();
    m_anim->start();
}

void WallpaperBackground::rebuildScaled(const QSize& target)
{
    m_scaledFor = target;
    // Overscan before blurring: the blur fades the pixmap edges toward transparent, so scale a
    // margin larger than the window and let paintEvent's center-crop keep that fringe off-screen.
    const int pad = static_cast<int>(g_blurRadius) * 3;
    const QSize grown = target + QSize(pad * 2, pad * 2);
    auto scale = [&](const QImage& img) -> QPixmap {
        if (img.isNull() || target.isEmpty()) {
            return {};
        }
        return frosted(QPixmap::fromImage(img.scaled(grown, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation)));
    };
    m_currentScaled = scale(m_current);
    m_incomingScaled = scale(m_incoming);
}

void WallpaperBackground::paintEvent(QPaintEvent* event)
{
    const QSize target = size();
    if (target != m_scaledFor) {
        rebuildScaled(target);
    }

    QPainter p(this);
    // Translucent children (the changelog/stats overlays) repaint this widget ~16x/s as they
    // drift-scroll; clip to the dirty region so an idle background isn't re-blitted whole.
    p.setClipRegion(event->region());
    p.fillRect(rect(), QColor("#0f0a06"));

    auto draw = [&](const QPixmap& pm, qreal opacity) {
        if (pm.isNull() || opacity <= 0.0) {
            return;
        }
        const int dx = (pm.width() - target.width()) / 2;
        const int dy = (pm.height() - target.height()) / 2;
        p.setOpacity(opacity);
        p.drawPixmap(QPoint(-dx, -dy), pm);
        p.setOpacity(1.0);
    };

    // Current under, incoming over.
    draw(m_currentScaled, m_fade);
    draw(m_incomingScaled, 1.0 - m_fade);

    // Light bottom darken for legibility against status text.
    QLinearGradient vert(0, 0, 0, height());
    vert.setColorAt(0.0, QColor(0, 0, 0, 0));
    vert.setColorAt(0.85, QColor(0, 0, 0, 0));
    vert.setColorAt(1.0, QColor(15, 10, 6, 140));
    p.fillRect(rect(), vert);
}

}  // namespace Jarton
