// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/TimeFmt.h"

#include <QTimeZone>

namespace Jarton {

TimeFmt::TimeFmt(QObject* parent) : QObject(parent) {}

QString TimeFmt::zoneLabel() const {
    QTimeZone tz = QTimeZone::systemTimeZone();
    QDateTime now = QDateTime::currentDateTimeUtc();
    QString abbr = tz.abbreviation(now);   // e.g. "MDT"
    int secs = tz.offsetFromUtc(now);
    int hours = secs / 3600;
    int mins = qAbs(secs % 3600) / 60;
    QString tag = QStringLiteral("UTC%1%2").arg(hours >= 0 ? "+" : "-").arg(qAbs(hours));
    if (mins)
        tag += QStringLiteral(":%1").arg(mins, 2, 10, QChar('0'));
    return abbr.isEmpty() ? tag : QStringLiteral("%1 · %2").arg(abbr, tag);
}

QDateTime TimeFmt::parseUtc(const QVariant& v) const {
    if (!v.isValid() || v.isNull())
        return {};
    // epoch milliseconds (number, or an all-digit string of that magnitude)
    bool isNum = false;
    qint64 ms = v.toLongLong(&isNum);
    if (isNum && ms > 100000000000LL)   // > ~1973 in ms — treat as epoch ms
        return QDateTime::fromMSecsSinceEpoch(ms, QTimeZone::UTC);

    QString s = v.toString().trimmed();
    if (s.isEmpty())
        return {};
    if (s.indexOf(' ') >= 0 && s.indexOf('T') < 0)
        s.replace(' ', 'T');
    QDateTime dt = QDateTime::fromString(s, Qt::ISODate);
    if (!dt.isValid())
        return {};
    // bare MariaDB strings carry no zone → they are UTC; stamp it so conversion is correct
    if (dt.timeSpec() == Qt::LocalTime)
        dt.setTimeZone(QTimeZone::UTC);
    return dt.toUTC();
}

QString TimeFmt::abs(const QVariant& v) const {
    QDateTime dt = parseUtc(v);
    if (!dt.isValid())
        return {};
    return dt.toLocalTime().toString(QStringLiteral("dd MMM, HH:mm"));
}

QString TimeFmt::rel(const QVariant& v) const {
    QDateTime dt = parseUtc(v);
    if (!dt.isValid())
        return {};
    qint64 diff = dt.msecsTo(QDateTime::currentDateTimeUtc());
    if (diff < 0)
        diff = 0;
    qint64 days = diff / 86400000;
    if (days > 0)
        return QStringLiteral("%1d ago").arg(days);
    qint64 hours = diff / 3600000;
    if (hours > 0)
        return QStringLiteral("%1h ago").arg(hours);
    qint64 mins = diff / 60000;
    return QStringLiteral("%1m ago").arg(qMax<qint64>(1, mins));
}

QString TimeFmt::when(const QVariant& v) const {
    QString r = rel(v), a = abs(v);
    if (r.isEmpty() && a.isEmpty())
        return {};
    if (r.isEmpty())
        return a;
    if (a.isEmpty())
        return r;
    return r + QStringLiteral(" · ") + a;
}

}  // namespace Jarton
