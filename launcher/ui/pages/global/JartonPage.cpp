// SPDX-License-Identifier: GPL-3.0-only
#include "JartonPage.h"

#include <QCheckBox>
#include <QDir>
#include <QFile>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QStandardPaths>
#include <QVBoxLayout>

#include "Application.h"
#include "jarton/services/ConfigService.h"
#include "settings/SettingsObject.h"

namespace {
const char* const g_defaultManifestUrl = "https://jarton.me/launcher/manifest.json";
const char* const g_settingsKeyManifestUrl = "JartonManifestUrl";
}  // namespace

JartonPage::JartonPage(QWidget* parent) : QWidget(parent)
{
    auto* root = new QVBoxLayout(this);
    root->setContentsMargins(16, 16, 16, 16);
    root->setSpacing(16);

    // -- Home tab group --
    {
        auto* group = new QGroupBox(tr("Home tab"), this);
        auto* form = new QFormLayout(group);

        m_wallpaperRotation = new QCheckBox(tr("Rotate wallpapers every 5 minutes"), group);
        form->addRow(m_wallpaperRotation);

        m_soundEnabled = new QCheckBox(tr("Play sound effects"), group);
        form->addRow(m_soundEnabled);

        root->addWidget(group);
    }

    // -- Manifest group --
    {
        auto* group = new QGroupBox(tr("Live data source"), this);
        auto* form = new QFormLayout(group);

        m_manifestUrl = new QLineEdit(group);
        m_manifestUrl->setPlaceholderText(QString::fromLatin1(g_defaultManifestUrl));
        form->addRow(tr("Manifest URL:"), m_manifestUrl);

        auto* btnRow = new QHBoxLayout();
        m_resetUrl = new QPushButton(tr("Reset to default"), group);
        m_clearCache = new QPushButton(tr("Clear offline cache"), group);
        btnRow->addWidget(m_resetUrl);
        btnRow->addWidget(m_clearCache);
        btnRow->addStretch();
        form->addRow(btnRow);

        auto* hint = new QLabel(
            tr("Override only for dev builds. Live changes take effect on the next manifest refresh (every 15 minutes)."),
            group);
        hint->setWordWrap(true);
        hint->setStyleSheet("color: #888;");
        form->addRow(hint);

        root->addWidget(group);
    }

    root->addStretch();

    connect(m_resetUrl, &QPushButton::clicked, this, &JartonPage::onResetManifestUrl);
    connect(m_clearCache, &QPushButton::clicked, this, &JartonPage::onClearManifestCache);

    loadSettings();
}

JartonPage::~JartonPage() = default;

QIcon JartonPage::icon() const
{
    return QIcon(QStringLiteral(":/jarton/icons/jartonclient_64.png"));
}

void JartonPage::loadSettings()
{
    if (auto* cfg = APPLICATION->jartonConfig()) {
        m_wallpaperRotation->setChecked(cfg->wallpaperRotation());
        m_soundEnabled->setChecked(cfg->soundEnabled());
    }
    const QString stored = APPLICATION->settings()->get(QString::fromLatin1(g_settingsKeyManifestUrl)).toString();
    m_manifestUrl->setText(stored.isEmpty() ? QString::fromLatin1(g_defaultManifestUrl) : stored);
}

bool JartonPage::apply()
{
    if (auto* cfg = APPLICATION->jartonConfig()) {
        cfg->setWallpaperRotation(m_wallpaperRotation->isChecked());
        cfg->setSoundEnabled(m_soundEnabled->isChecked());
    }
    APPLICATION->settings()->set(QString::fromLatin1(g_settingsKeyManifestUrl), m_manifestUrl->text().trimmed());
    return true;
}

void JartonPage::onResetManifestUrl()
{
    m_manifestUrl->setText(QString::fromLatin1(g_defaultManifestUrl));
}

void JartonPage::onClearManifestCache()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QFile::remove(base + QStringLiteral("/manifest.cache.json"));
    QDir(base + QStringLiteral("/wallpapers")).removeRecursively();
}

void JartonPage::retranslate() {}
