// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QIcon>
#include <QWidget>

#include "ui/pages/BasePage.h"

class QCheckBox;
class QLineEdit;
class QPushButton;

class JartonPage : public QWidget, public BasePage {
    Q_OBJECT

   public:
    explicit JartonPage(QWidget* parent = nullptr);
    ~JartonPage() override;

    QString id() const override { return QStringLiteral("jarton-client"); }
    QString displayName() const override { return tr("Jarton Client"); }
    QIcon icon() const override;
    bool apply() override;
    void retranslate() override;

   private slots:
    void onResetManifestUrl();
    void onClearManifestCache();

   private:
    void loadSettings();

    QCheckBox* m_wallpaperRotation = nullptr;
    QCheckBox* m_soundEnabled = nullptr;
    QLineEdit* m_manifestUrl = nullptr;
    QPushButton* m_resetUrl = nullptr;
    QPushButton* m_clearCache = nullptr;
};
