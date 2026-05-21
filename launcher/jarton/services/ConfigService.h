// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>

namespace Jarton {

class ConfigService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool wallpaperRotation READ wallpaperRotation WRITE setWallpaperRotation NOTIFY changed)
    Q_PROPERTY(bool soundEnabled READ soundEnabled WRITE setSoundEnabled NOTIFY changed)

   public:
    explicit ConfigService(QObject* parent = nullptr);
    ~ConfigService() override;

    bool wallpaperRotation() const { return m_wallpaperRotation; }
    void setWallpaperRotation(bool v);

    bool soundEnabled() const { return m_soundEnabled; }
    void setSoundEnabled(bool v);

   signals:
    void changed();

   private:
    void load();
    void save() const;
    static QString configPath();

    bool m_wallpaperRotation = true;
    bool m_soundEnabled = true;
};

}  // namespace Jarton
