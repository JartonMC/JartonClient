// SPDX-License-Identifier: GPL-3.0-only
#include "DefaultInstanceService.h"

#include <QLoggingCategory>
#include <QTimer>

#include "Application.h"
#include "BaseInstance.h"
#include "InstanceList.h"
#include "JartonManifestService.h"

Q_LOGGING_CATEGORY(jartonDefaultInstance, "jarton.instance")

namespace Jarton {

namespace {
const char* const g_targetInstanceName = "Jarton";
}

DefaultInstanceService::DefaultInstanceService(JartonManifestService* manifest, QObject* parent)
    : QObject(parent), m_manifest(manifest)
{
    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &DefaultInstanceService::onManifestChanged);
    }
    // Defer the first refresh to the next event-loop turn. The manifest can already be
    // ready at construction (loadFromDiskCache populates it synchronously), so a direct
    // refresh() here would emit provisionRequested before Application has connected its
    // handler — the signal fires into the void and provisioning silently never runs.
    QTimer::singleShot(0, this, &DefaultInstanceService::refresh);
}

DefaultInstanceService::~DefaultInstanceService() = default;

void DefaultInstanceService::setState(State newState, const QString& id)
{
    if (m_state == newState && m_instanceId == id) {
        return;
    }
    m_state = newState;
    m_instanceId = id;
    emit stateChanged();
}

void DefaultInstanceService::refresh()
{
    auto* list = APPLICATION->instances();
    if (list == nullptr) {
        setState(Missing);
        return;
    }
    const QString target = QString::fromLatin1(g_targetInstanceName);
    for (int i = 0; i < list->rowCount(QModelIndex{}); ++i) {
        auto* const inst = list->at(i);
        if (inst != nullptr && inst->name() == target) {
            setState(Ready, inst->id());
            return;
        }
    }
    // An import we kicked off is still staging — don't thrash back to Missing
    // (and don't re-trigger provisioning) while it runs.
    if (m_state == Provisioning) {
        return;
    }
    setState(Missing);
    maybeProvision();
}

void DefaultInstanceService::maybeProvision()
{
    // First-launch only: instance absent, manifest carries a pack, haven't tried yet.
    if (m_state != Missing || m_provisionAttempted || m_manifest == nullptr || !m_manifest->ready()) {
        qCDebug(jartonDefaultInstance) << "maybeProvision skipped — state:" << m_state
                                       << "attempted:" << m_provisionAttempted
                                       << "manifestReady:" << (m_manifest && m_manifest->ready());
        return;
    }
    const QString packUrl = m_manifest->manifest().instance.packUrl;
    if (packUrl.isEmpty()) {
        qCWarning(jartonDefaultInstance) << "manifest ready but instance.pack_url is empty — cannot provision";
        return;
    }
    m_provisionAttempted = true;
    setState(Provisioning);
    qCInfo(jartonDefaultInstance) << "provisioning Jarton instance from" << packUrl;
    emit provisionRequested(packUrl);
}

void DefaultInstanceService::onProvisionFinished()
{
    // Drop out of Provisioning so refresh() can settle on Ready (import succeeded)
    // or Missing (import failed — leaves the user on Prism's manual New Instance path).
    if (m_state == Provisioning) {
        m_state = Missing;
    }
    refresh();
}

void DefaultInstanceService::onManifestChanged(bool /*stale*/)
{
    refresh();
}

void DefaultInstanceService::play()
{
    if (m_state != Ready || m_instanceId.isEmpty()) {
        return;
    }
    setState(Launching, m_instanceId);
    emit launchRequested(m_instanceId);
}

void DefaultInstanceService::requestSetup()
{
    if (!m_manifest) {
        emit setupRequested(QString::fromLatin1(g_targetInstanceName), QStringLiteral("1.21.4"), QStringLiteral("0.16.9"));
        return;
    }
    const auto& inst = m_manifest->manifest().instance;
    emit setupRequested(QString::fromLatin1(g_targetInstanceName),
                        inst.minecraftVersion.isEmpty() ? QStringLiteral("1.21.4") : inst.minecraftVersion,
                        inst.fabricVersion.isEmpty() ? QStringLiteral("0.16.9") : inst.fabricVersion);
}

}  // namespace Jarton
