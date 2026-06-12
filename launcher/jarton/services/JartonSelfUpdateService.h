// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QObject>
#include <QString>

#include <functional>

#include "net/NetJob.h"

class QNetworkAccessManager;

namespace Jarton {

// In-client launcher self-update, fed by JartonUpdateService's manifest check.
//
// macOS: the release zip is downloaded silently to <dataRoot>/updates/<ver>/ and
// extracted; only then does the single "Restart to update?" prompt appear.
// Accepting swaps the running .app for the new one (old bundle parked as
// <name>.app.old-<ver> beside it) and relaunches. Declining keeps the download
// so the next launch re-offers without re-downloading.
//
// Windows: hands off to the bundled <name>_updater binary (the prismupdater),
// which picks the right release asset for portable vs installed copies, swaps
// the files and relaunches on its own.
//
// Linux, or when anything above isn't possible: the old open-the-releases-page
// prompt.
class JartonSelfUpdateService : public QObject {
    Q_OBJECT

   public:
    enum class Asset { MacZip, WindowsPortable, WindowsSetup };

    JartonSelfUpdateService(QString dataRoot, QString updaterBinary, QNetworkAccessManager* network, QObject* parent = nullptr);

    // Blocks the restart prompt while a game is running; checked again before applying.
    void setUpdatesAllowedCheck(std::function<bool()> check) { m_updatesAllowed = std::move(check); }

    // Manual "Check for Updates": allows the offer to fire again this run.
    void rearm() { m_active = false; }

    // Startup sweep: parked .app.old-* bundles from the last update, and cached
    // downloads for versions we already run (or older).
    void cleanupStaleArtifacts();

    static QString assetName(Asset asset, const QString& version);
    static QString assetUrl(Asset asset, const QString& version);
    static QString cachedAssetPath(const QString& dataRoot, Asset asset, const QString& version);

   public slots:
    void onLauncherUpdateAvailable(const QString& version);

   private:
    void startDownload();
    void prepareAndOffer();
    void offerRestart();
    void applyMacUpdate();
    bool moveBundle(const QString& src, const QString& dst);
    void runWindowsUpdater();
    void discardAndFallBack(const QString& reason);
    void macFallback(const QString& reason);
    void offerReleasesPage();

    QString versionCacheDir() const;
    QString locateAppBundle(const QString& unpackedRoot) const;

    QString m_dataRoot;
    QString m_updaterBinary;
    QNetworkAccessManager* m_network = nullptr;

    QString m_version;
    QString m_newAppPath;
    NetJob::Ptr m_dlJob;
    std::function<bool()> m_updatesAllowed;
    bool m_active = false;  // one offer per run
};

}  // namespace Jarton
