// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QMainWindow>

class QQuickWidget;

namespace Jarton {

// Top-level window hosting the staff panel QML. Opened from the sidebar's staff
// tab; the panel's "pop out" detaches an independent copy into its own window
// (browser-tab-tear-off style). All windows share the one ProctorClient singleton,
// so login/state stay in sync across them.
class StaffWindow : public QMainWindow {
    Q_OBJECT

   public:
    explicit StaffWindow(QWidget* parent = nullptr);
    ~StaffWindow() override;

   private slots:
    void onPopOutRequested();

   private:
    QQuickWidget* m_qml = nullptr;
};

}  // namespace Jarton
