// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QVector>

class QQuickTextDocument;
class QRegularExpression;

namespace Jarton {

// Lightweight highlighter for server config files (yml / properties / json / conf):
// comments, keys, strings, numbers, booleans. Honey-leaning palette to match the theme.
class ConfigHighlighter : public QSyntaxHighlighter {
    Q_OBJECT
   public:
    explicit ConfigHighlighter(QTextDocument* doc);
   protected:
    void highlightBlock(const QString& text) override;
   private:
    struct Rule { QRegularExpression* re; QTextCharFormat fmt; };
    QVector<Rule> m_rules;
    QTextCharFormat m_comment;
};

// QML-attachable: SyntaxHelper.attach(editor.textDocument) wires a ConfigHighlighter to a
// TextEdit's document (parented to it, so it lives exactly as long as the editor).
class SyntaxHelper : public QObject {
    Q_OBJECT
   public:
    using QObject::QObject;
    Q_INVOKABLE void attach(QQuickTextDocument* doc);
};

}  // namespace Jarton
