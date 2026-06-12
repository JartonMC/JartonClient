// SPDX-License-Identifier: GPL-3.0-only
#include "JartonInstanceDialog.h"

#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>

#include "Application.h"
#include "jarton/services/JartonProvisionService.h"

JartonInstanceDialog::JartonInstanceDialog(QWidget* parent) : QDialog(parent)
{
    setWindowTitle(tr("Create Jarton Instance"));
    setModal(true);

    auto* layout = new QVBoxLayout(this);

    auto* blurb = new QLabel(
        tr("Pick a Minecraft version. The instance is set up with the Jarton mods and "
           "settings for that version; you can change them afterwards."),
        this);
    blurb->setWordWrap(true);
    layout->addWidget(blurb);

    auto* form = new QFormLayout();
    m_versionBox = new QComboBox(this);
    for (const auto& pack : APPLICATION->jartonProvision()->availablePacks()) {
        m_versionBox->addItem(pack.minecraftVersion, pack.minecraftVersion);
    }
    form->addRow(tr("Version:"), m_versionBox);
    layout->addLayout(form);

    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    buttons->button(QDialogButtonBox::Ok)->setText(tr("Create"));
    connect(buttons, &QDialogButtonBox::accepted, this, &QDialog::accept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    layout->addWidget(buttons);

    // Nothing to pick means the manifest hasn't loaded its packs yet; let the user know
    // rather than handing them an empty create button.
    if (m_versionBox->count() == 0) {
        m_versionBox->setEnabled(false);
        buttons->button(QDialogButtonBox::Ok)->setEnabled(false);
        blurb->setText(tr("No Jarton versions are available right now. Check your connection and try again in a moment."));
    }
}

QString JartonInstanceDialog::selectedVersion() const
{
    if (result() != QDialog::Accepted || m_versionBox == nullptr) {
        return {};
    }
    return m_versionBox->currentData().toString();
}
