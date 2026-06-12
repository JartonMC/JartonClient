// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QString>

namespace Jarton {

// On-disk store for CDN-synced JartonUI jars: <root>/<mcVersion>.jar plus a sidecar
// <mcVersion>.json recording the JartonUI version and the jar's sha256. The sidecar is
// the trust anchor — a jar only resolves if its bytes still hash to the recorded value,
// so a torn write or a tampered file falls back to the bundled copy instead of loading.
class JartonUiCache {
   public:
    explicit JartonUiCache(QString rootDir);

    QString jarPath(const QString& mcVersion) const;
    QString recordedSha256(const QString& mcVersion) const;
    QString recordedVersion(const QString& mcVersion) const;

    // Path of the cached jar, or empty unless it exists and still matches its recorded sha256.
    QString verifiedJar(const QString& mcVersion) const;

    // Move a downloaded jar into the cache. The hash is checked before anything is touched,
    // and a failed swap puts the previous jar back — the cache never ends up worse off.
    bool commit(const QString& downloadedJar, const QString& mcVersion, const QString& sha256, const QString& uiVersion);

    static QString sha256Hex(const QString& filePath);

   private:
    QString metaPath(const QString& mcVersion) const;

    QString m_root;
};

}  // namespace Jarton
