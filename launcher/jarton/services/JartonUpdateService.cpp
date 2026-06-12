// SPDX-License-Identifier: GPL-3.0-only
#include "JartonUpdateService.h"

#include <QMessageBox>
#include <QUrl>

#include "BaseInstance.h"
#include "BuildConfig.h"
#include "DesktopServices.h"
#include "InstanceList.h"
#include "JartonManifestService.h"
#include "PackRecord.h"
#include "Version.h"

namespace Jarton {

namespace {
const char* const g_releasesUrl = "https://github.com/JartonMC/JartonClient/releases";
}  // namespace

JartonUpdateService::JartonUpdateService(JartonManifestService* manifest, InstanceList* instances, QObject* parent)
    : QObject(parent), m_manifest(manifest), m_instances(instances)
{
    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &JartonUpdateService::onManifestChanged);
    }
}

JartonUpdateService::~JartonUpdateService() = default;

void JartonUpdateService::onManifestChanged(bool stale)
{
    // A stale (disk-cache) manifest could prompt the user to "update" to a version
    // older than what's already live, so wait for a network-confirmed manifest.
    if (stale) {
        return;
    }
    checkAll();
}

void JartonUpdateService::checkAll()
{
    checkLauncherUpdate();
    checkInstanceUpdates();
}

void JartonUpdateService::checkInstanceUpdates()
{
    if (m_instancesPrompted || m_instances == nullptr || m_manifest == nullptr || !m_manifest->ready()) {
        return;
    }
    const Manifest& manifest = m_manifest->manifest();

    struct Pending {
        QString id;
        QString name;
        QString url;
        QString mcVersion;
        QString fromVersion;
        QString toVersion;
    };
    QVector<Pending> pending;

    for (int i = 0; i < m_instances->count(); ++i) {
        BaseInstance* inst = m_instances->at(i);
        if (inst == nullptr || inst->isRunning()) {
            continue;
        }
        const PackRecord rec = PackRecord::read(inst->instanceRoot());
        if (!rec.valid) {
            continue;
        }

        QString url;
        QString available;
        for (const ManifestPack& pack : manifest.packs) {
            if (pack.minecraftVersion == rec.mcVersion) {
                url = pack.packUrl;
                available = pack.packVersion;
                break;
            }
        }
        if (url.isEmpty() && manifest.instance.minecraftVersion == rec.mcVersion) {
            url = manifest.instance.packUrl;
            available = manifest.instance.packVersion;
        }
        if (url.isEmpty() || available.isEmpty() || !(Version(rec.packVersion) < Version(available))) {
            continue;
        }
        if (!rec.modsMatch(inst->gameRoot())) {
            qInfo() << "[jarton.update] skipping" << inst->name() << "- player has edited it";
            continue;
        }
        pending.append({ inst->id(), inst->name(), url, rec.mcVersion, rec.packVersion, available });
    }

    if (pending.isEmpty()) {
        return;
    }
    m_instancesPrompted = true;

    QStringList lines;
    for (const Pending& p : pending) {
        lines << tr("%1:  %2 \u2192 %3").arg(p.name, p.fromVersion, p.toVersion);
    }
    QMessageBox box;
    box.setWindowTitle(tr("Jarton update available"));
    box.setIcon(QMessageBox::Information);
    box.setText(pending.size() == 1 ? tr("An update is ready for your Jarton instance:")
                                    : tr("Updates are ready for your Jarton instances:"));
    box.setInformativeText(lines.join(QLatin1Char('\n')) +
                           tr("\n\nYour worlds, settings and keybinds are kept. Instances you've modified are never touched."));
    auto* updateBtn = box.addButton(tr("Update"), QMessageBox::AcceptRole);
    box.addButton(tr("Later"), QMessageBox::RejectRole);
    box.exec();
    if (box.clickedButton() != updateBtn) {
        return;
    }
    for (const Pending& p : pending) {
        emit instanceUpdateRequested(p.id, p.url, p.mcVersion, p.toVersion);
    }
}

QString JartonUpdateService::runningLauncherVersion()
{
    // Source of truth is the compiled-in BuildConfig version, not the manifest.
    return BuildConfig.versionString();
}

void JartonUpdateService::checkLauncherUpdate()
{
    if (m_launcherPrompted || m_manifest == nullptr || !m_manifest->ready()) {
        return;
    }
    const QString manifestVersion = m_manifest->manifest().launcherVersion;
    if (manifestVersion.isEmpty()) {
        return;
    }
    const Version running(runningLauncherVersion());
    const Version available(manifestVersion);
    if (!(running < available)) {
        return;
    }
    m_launcherPrompted = true;

    QMessageBox box;
    box.setWindowTitle(tr("Launcher update available"));
    box.setIcon(QMessageBox::Information);
    box.setText(tr("A newer Jarton Client is available (%1, you have %2).").arg(manifestVersion, runningLauncherVersion()));
    box.setInformativeText(tr("Open the releases page to download the installer for your platform?"));
    auto* openBtn = box.addButton(tr("Open releases"), QMessageBox::AcceptRole);
    box.addButton(tr("Later"), QMessageBox::RejectRole);
    box.exec();
    if (box.clickedButton() == openBtn) {
        DesktopServices::openUrl(QUrl(QString::fromLatin1(g_releasesUrl)));
    }
}

}  // namespace Jarton
