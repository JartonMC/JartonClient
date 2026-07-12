// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QVariant>

namespace Jarton {

// Client-wide time formatter. The broker sends MariaDB DATETIME strings in UTC as bare
// "YYYY-MM-DD HH:MM:SS" (no zone marker); parsing them as local skews every absolute time by
// the viewer's offset. TimeFmt parses them as UTC and renders in the viewer's own system
// local zone — no setting, each machine shows its own time. `zoneLabel` (e.g. "MDT · UTC-6")
// backs the small "times shown in your local time" disclaimer next to absolute timestamps.
// One shared singleton so every view formats identically. Epoch-ms values are accepted verbatim.
class TimeFmt : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString zoneLabel READ zoneLabel CONSTANT)

   public:
    explicit TimeFmt(QObject* parent = nullptr);

    QString zoneLabel() const;   // e.g. "MDT · UTC-6"

    Q_INVOKABLE QString abs(const QVariant& v) const;    // "12 Jul, 12:51" — viewer local
    Q_INVOKABLE QString rel(const QVariant& v) const;    // "3h ago"
    Q_INVOKABLE QString when(const QVariant& v) const;   // "3h ago · 12 Jul, 12:51"

   private:
    QDateTime parseUtc(const QVariant& v) const;   // → UTC instant (invalid if unparseable)
};

}  // namespace Jarton
