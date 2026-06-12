// SPDX-License-Identifier: GPL-3.0-only
#include "ConfigService.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace Jarton {

ConfigService::ConfigService(QObject* parent) : QObject(parent)
{
    load();
}

ConfigService::~ConfigService() = default;

void ConfigService::setWallpaperRotation(bool v)
{
    if (m_wallpaperRotation == v) {
        return;
    }
    m_wallpaperRotation = v;
    save();
    emit changed();
}

void ConfigService::setSoundEnabled(bool v)
{
    if (m_soundEnabled == v) {
        return;
    }
    m_soundEnabled = v;
    save();
    emit changed();
}

QString ConfigService::configPath()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(base);
    return base + QStringLiteral("/jarton-config.json");
}

void ConfigService::load()
{
    QFile f(configPath());
    if (!f.exists() || !f.open(QIODevice::ReadOnly)) {
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) {
        return;
    }
    const QJsonObject obj = doc.object();
    m_wallpaperRotation = obj.value(QStringLiteral("wallpaper_rotation")).toBool(true);
    m_soundEnabled = obj.value(QStringLiteral("sound_enabled")).toBool(true);
}

void ConfigService::save() const
{
    QJsonObject obj;
    obj["wallpaper_rotation"] = m_wallpaperRotation;
    obj["sound_enabled"] = m_soundEnabled;
    QFile f(configPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
    }
}

}  // namespace Jarton
