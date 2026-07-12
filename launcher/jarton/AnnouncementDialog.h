// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QFrame>

class QQuickWidget;

namespace Jarton {

// Inline modal card that floats on top of the main window. Not a separate
// OS window; just a child QFrame positioned over the central area.
class AnnouncementDialog : public QFrame {
    Q_OBJECT
   public:
    explicit AnnouncementDialog(QWidget* parent = nullptr);

    void showAtIndex(int index);

   signals:
    // native section containers (QQuickView windows) composite over this QWidget
    // modal, so MainWindow hides them while we're open and restores on close
    void opened();
    void closed();

   protected:
    void resizeEvent(QResizeEvent* event) override;
    bool eventFilter(QObject* watched, QEvent* event) override;

   private slots:
    void onCloseRequested();

   private:
    QQuickWidget* m_qml = nullptr;
    QWidget* m_scrim = nullptr;
};

}  // namespace Jarton
