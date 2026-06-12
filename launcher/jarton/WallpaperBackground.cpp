// SPDX-License-Identifier: GPL-3.0-only
#include "WallpaperBackground.h"

#include <QImageReader>
#include <QLinearGradient>
#include <QPaintEvent>
#include <QPainter>
#include <QUrl>
#include <QVariantAnimation>

namespace Jarton {

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
        update();
        return;
    }
    m_incoming = std::move(img);
    m_anim->stop();
    m_anim->start();
}

void WallpaperBackground::paintEvent(QPaintEvent* /*event*/)
{
    QPainter p(this);
    p.fillRect(rect(), QColor("#0f0a06"));

    const QSize target = size();

    auto draw = [&](const QImage& img, qreal opacity) {
        if (img.isNull() || opacity <= 0.0) {
            return;
        }
        const QImage scaled =
            img.scaled(target, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
        const int dx = (scaled.width() - target.width()) / 2;
        const int dy = (scaled.height() - target.height()) / 2;
        p.setOpacity(opacity);
        p.drawImage(QPoint(-dx, -dy), scaled);
        p.setOpacity(1.0);
    };

    // Current under, incoming over.
    draw(m_current, m_fade);
    draw(m_incoming, 1.0 - m_fade);

    // Light bottom darken for legibility against status text.
    QLinearGradient vert(0, 0, 0, height());
    vert.setColorAt(0.0, QColor(0, 0, 0, 0));
    vert.setColorAt(0.85, QColor(0, 0, 0, 0));
    vert.setColorAt(1.0, QColor(15, 10, 6, 140));
    p.fillRect(rect(), vert);
}

}  // namespace Jarton
