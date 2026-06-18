// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/ConfigHighlighter.h"

#include <QColor>
#include <QQuickTextDocument>
#include <QRegularExpression>
#include <QTextDocument>

namespace Jarton {

static QTextCharFormat fmtOf(const QString& hex, bool italic = false)
{
    QTextCharFormat f;
    f.setForeground(QColor(hex));
    if (italic) f.setFontItalic(true);
    return f;
}

ConfigHighlighter::ConfigHighlighter(QTextDocument* doc) : QSyntaxHighlighter(doc)
{
    m_comment = fmtOf(QStringLiteral("#6b6256"), true);
    // order matters: later rules paint over earlier ones where they overlap
    m_rules.push_back({ new QRegularExpression(QStringLiteral("^\\s*[A-Za-z0-9_.\\-]+(?=\\s*[:=])")), fmtOf(QStringLiteral("#FFB81C")) });   // key
    m_rules.push_back({ new QRegularExpression(QStringLiteral("\\b(true|false|null|yes|no|on|off|none)\\b"), QRegularExpression::CaseInsensitiveOption), fmtOf(QStringLiteral("#d2a8ff")) });  // keyword
    m_rules.push_back({ new QRegularExpression(QStringLiteral("\\b-?\\d+(?:\\.\\d+)?\\b")), fmtOf(QStringLiteral("#79b8ff")) });  // number
    m_rules.push_back({ new QRegularExpression(QStringLiteral("\"[^\"]*\"|'[^']*'")), fmtOf(QStringLiteral("#7ee787")) });        // string
}

void ConfigHighlighter::highlightBlock(const QString& text)
{
    const QString trimmed = text.trimmed();
    if (trimmed.startsWith('#') || trimmed.startsWith(';') || trimmed.startsWith(QStringLiteral("//"))) {
        setFormat(0, text.length(), m_comment);
        return;
    }
    for (const Rule& rule : m_rules) {
        auto it = rule.re->globalMatch(text);
        while (it.hasNext()) {
            const auto m = it.next();
            setFormat(m.capturedStart(), m.capturedLength(), rule.fmt);
        }
    }
}

void SyntaxHelper::attach(QQuickTextDocument* doc)
{
    if (!doc || !doc->textDocument()) return;
    // parent to the QTextDocument so the highlighter's lifetime tracks the editor's
    new ConfigHighlighter(doc->textDocument());
}

}  // namespace Jarton
