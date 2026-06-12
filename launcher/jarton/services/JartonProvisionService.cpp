// SPDX-License-Identifier: GPL-3.0-only
#include "JartonProvisionService.h"

#include <QCollator>
#include <QLoggingCategory>

#include "JartonManifestService.h"

Q_LOGGING_CATEGORY(jartonProvision, "jarton.provision")

namespace Jarton {

JartonProvisionService::JartonProvisionService(JartonManifestService* manifest, QObject* parent)
    : QObject(parent), m_manifest(manifest)
{
}

JartonProvisionService::~JartonProvisionService() = default;

QVector<ManifestPack> JartonProvisionService::availablePacks() const
{
    if (m_manifest == nullptr || !m_manifest->ready()) {
        return {};
    }
    QVector<ManifestPack> packs = m_manifest->manifest().packs;

    // Newest MC first. QCollator with numericMode sorts 1.21.10 above 1.21.9 and keeps
    // the 26.x line on top, which a plain string compare gets wrong.
    QCollator collator;
    collator.setNumericMode(true);
    std::sort(packs.begin(), packs.end(), [&collator](const ManifestPack& a, const ManifestPack& b) {
        return collator.compare(a.minecraftVersion, b.minecraftVersion) > 0;
    });
    return packs;
}

void JartonProvisionService::provision(const QString& mcVersion)
{
    if (m_manifest == nullptr || !m_manifest->ready()) {
        qCWarning(jartonProvision) << "provision called before manifest ready — ignoring";
        return;
    }
    for (const auto& pack : m_manifest->manifest().packs) {
        if (pack.minecraftVersion != mcVersion) {
            continue;
        }
        if (pack.packUrl.isEmpty()) {
            qCWarning(jartonProvision) << "pack for" << mcVersion << "has no url";
            return;
        }
        const QString name = QStringLiteral("Jarton %1").arg(mcVersion);
        qCInfo(jartonProvision) << "provisioning" << name << "from" << pack.packUrl;
        emit provisionRequested(pack.packUrl, name, mcVersion, pack.packVersion);
        return;
    }
    qCWarning(jartonProvision) << "no pack available for" << mcVersion;
}

}  // namespace Jarton
