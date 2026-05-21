// SPDX-License-Identifier: GPL-3.0-only
#include "DefaultInstanceService.h"

#include "Application.h"
#include "BaseInstance.h"
#include "InstanceList.h"
#include "JartonManifestService.h"

namespace Jarton {

namespace {
const char* const g_targetInstanceName = "JartonMC";
}

DefaultInstanceService::DefaultInstanceService(JartonManifestService* manifest, QObject* parent)
    : QObject(parent), m_manifest(manifest)
{
    if (m_manifest) {
        connect(m_manifest, &JartonManifestService::manifestChanged, this, &DefaultInstanceService::onManifestChanged);
    }
    refresh();
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
    setState(Missing);
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
