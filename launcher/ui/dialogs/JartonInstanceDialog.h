// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QDialog>
#include <QString>

class QComboBox;

// Version picker for "Create Jarton Instance". Lists the Minecraft versions that have a
// curated pack in the manifest; the chosen one is provisioned with that pack's mods +
// configs. Provisioning is creation-only, so this dialog has no notion of an existing
// instance — it always creates fresh.
class JartonInstanceDialog : public QDialog {
    Q_OBJECT

   public:
    explicit JartonInstanceDialog(QWidget* parent = nullptr);

    // The Minecraft version the user picked, or empty if they cancelled.
    QString selectedVersion() const;

   private:
    QComboBox* m_versionBox = nullptr;
};
