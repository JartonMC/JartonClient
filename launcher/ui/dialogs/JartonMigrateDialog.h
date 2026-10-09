// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QDialog>

#include "jarton/services/JartonManifest.h"

class QComboBox;
class QLabel;

class JartonMigrateDialog : public QDialog {
    Q_OBJECT
   public:
    JartonMigrateDialog(const QString& currentMc, QWidget* parent = nullptr);
    Jarton::ManifestPack selectedPack() const;

   private:
    void refreshSummary();

    QString m_currentMc;
    QComboBox* m_versionBox = nullptr;
    QLabel* m_summary = nullptr;
    QVector<Jarton::ManifestPack> m_packs;
};
