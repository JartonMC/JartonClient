// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/StaffWindow.h"

#include <QQuickItem>
#include <QQuickWidget>
#include <QUrl>

namespace Jarton {

StaffWindow::StaffWindow(QWidget* parent) : QMainWindow(parent), m_qml(new QQuickWidget(this))
{
    setWindowTitle(QStringLiteral("Jarton Staff"));
    resize(440, 580);

    m_qml->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_qml->setSource(QUrl(QStringLiteral("qrc:/jarton/staff/StaffPanel.qml")));
    setCentralWidget(m_qml);

    if (auto* root = m_qml->rootObject()) {
        connect(root, SIGNAL(popOutRequested()), this, SLOT(onPopOutRequested()));
    }
}

StaffWindow::~StaffWindow() = default;

void StaffWindow::onPopOutRequested()
{
    auto* detached = new StaffWindow();
    detached->setAttribute(Qt::WA_DeleteOnClose);
    detached->show();
    detached->raise();
}

}  // namespace Jarton
