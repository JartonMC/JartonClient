// SPDX-License-Identifier: GPL-3.0-only
#include "JartonMigrateDialog.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>

#include "Application.h"
#include "jarton/services/JartonProvisionService.h"

JartonMigrateDialog::JartonMigrateDialog(const QString& currentMc, const QString& currentPack, QWidget* parent)
    : QDialog(parent), m_currentMc(currentMc)
{
    setWindowTitle(tr("Update Instance Version"));
    setModal(true);

    auto* layout = new QVBoxLayout(this);
    auto* blurb = new QLabel(
        tr("Pick the Jarton version to move this instance to. Your worlds, settings, keybinds, "
           "resource packs and shaders are kept. Only the mods are replaced."),
        this);
    blurb->setWordWrap(true);
    layout->addWidget(blurb);

    m_packs = APPLICATION->jartonProvision()->availablePacks();  // newest first
    auto* form = new QFormLayout();
    m_versionBox = new QComboBox(this);
    for (const auto& pack : m_packs) {
        m_versionBox->addItem(pack.minecraftVersion, pack.minecraftVersion);
    }
    form->addRow(tr("Version:"), m_versionBox);
    layout->addLayout(form);

    m_summary = new QLabel(this);
    m_summary->setWordWrap(true);
    layout->addWidget(m_summary);

    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    buttons->button(QDialogButtonBox::Ok)->setText(tr("Update"));
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    layout->addWidget(buttons);

    connect(m_versionBox, &QComboBox::currentIndexChanged, this, [this] { refreshSummary(); });

    if (m_packs.isEmpty()) {
        m_versionBox->setEnabled(false);
        buttons->button(QDialogButtonBox::Ok)->setEnabled(false);
        blurb->setText(tr("No Jarton versions are available right now. Check your connection and try again."));
    } else {
        Q_UNUSED(currentPack);
        refreshSummary();
    }
}

void JartonMigrateDialog::refreshSummary()
{
    const QString target = m_versionBox->currentData().toString();
    if (target != m_currentMc) {
        // A world opened on a newer MC can't be taken back to an older one.
        m_summary->setText(tr("This changes Minecraft %1 → %2. Worlds are upgraded and can't be moved back; "
                              "resource packs or shaders made for another version may need re-selecting.")
                               .arg(m_currentMc, target));
    } else {
        m_summary->setText(tr("Refreshes the mods for Minecraft %1.").arg(m_currentMc));
    }
}

Jarton::ManifestPack JartonMigrateDialog::selectedPack() const
{
    const int i = m_versionBox->currentIndex();
    if (result() != QDialog::Accepted || i < 0 || i >= m_packs.size()) {
        return {};
    }
    return m_packs.at(i);
}
