// SPDX-License-Identifier: GPL-3.0-only
#include "JartonSelfUpdateService.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QMessageBox>
#include <QTimer>
#include <QProcess>
#include <QProcessEnvironment>
#include <QUrl>

#include "BuildConfig.h"
#include "DesktopServices.h"
#include "FileSystem.h"
#include "Version.h"
#include "net/Download.h"

namespace Jarton {

namespace {
const char* const g_releasesUrl = "https://github.com/JartonMC/JartonClient/releases";
const char* const g_downloadBase = "https://github.com/JartonMC/JartonClient/releases/download";

QString runningBundlePath()
{
    // applicationDirPath is <name>.app/Contents/MacOS for a bundled launcher;
    // anything else (dev build straight from the build tree) gets no bundle.
    const QString path = QDir::cleanPath(QCoreApplication::applicationDirPath() + QStringLiteral("/../.."));
    return path.endsWith(QLatin1String(".app")) ? path : QString();
}
}  // namespace

JartonSelfUpdateService::JartonSelfUpdateService(QString dataRoot, QString updaterBinary, QNetworkAccessManager* network, QObject* parent)
    : QObject(parent), m_dataRoot(std::move(dataRoot)), m_updaterBinary(std::move(updaterBinary)), m_network(network)
{}

QString JartonSelfUpdateService::assetName(Asset asset, const QString& version)
{
    switch (asset) {
        case Asset::MacZip:
            return QStringLiteral("JartonClient-macOS-%1.zip").arg(version);
        case Asset::WindowsPortable:
            return QStringLiteral("JartonClient-Windows-MSVC-Portable-%1.zip").arg(version);
        case Asset::WindowsSetup:
            return QStringLiteral("JartonClient-Windows-MSVC-Setup-%1.exe").arg(version);
    }
    return {};
}

QString JartonSelfUpdateService::assetUrl(Asset asset, const QString& version)
{
    return QStringLiteral("%1/%2/%3").arg(QLatin1String(g_downloadBase), version, assetName(asset, version));
}

QString JartonSelfUpdateService::cachedAssetPath(const QString& dataRoot, Asset asset, const QString& version)
{
    return FS::PathCombine(dataRoot, "updates", version, assetName(asset, version));
}

QString JartonSelfUpdateService::versionCacheDir() const
{
    return FS::PathCombine(m_dataRoot, "updates", m_version);
}

void JartonSelfUpdateService::cleanupStaleArtifacts()
{
    const QString bundle = runningBundlePath();
    if (!bundle.isEmpty()) {
        QDir parent = QFileInfo(bundle).dir();
        const QString pattern = QFileInfo(bundle).fileName() + QStringLiteral(".old-*");
        for (const QString& name : parent.entryList({ pattern }, QDir::Dirs)) {
            qInfo() << "[jarton.selfupdate] removing parked bundle" << name;
            FS::deletePath(parent.absoluteFilePath(name));
        }
    }

    const Version current(BuildConfig.versionString());
    QDir updates(FS::PathCombine(m_dataRoot, "updates"));
    if (!updates.exists()) {
        return;
    }
    for (const QString& name : updates.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!(current < Version(name))) {
            qInfo() << "[jarton.selfupdate] dropping stale update cache" << name;
            FS::deletePath(updates.absoluteFilePath(name));
        }
    }
}

void JartonSelfUpdateService::onLauncherUpdateAvailable(const QString& version)
{
    if (m_active || version.isEmpty()) {
        return;
    }
    m_active = true;
    m_version = version;

#if defined(Q_OS_MACOS)
    if (QFileInfo(cachedAssetPath(m_dataRoot, Asset::MacZip, m_version)).size() > 0) {
        prepareAndOffer();
    } else {
        startDownload();
    }
#elif defined(Q_OS_WIN)
    if (!m_updaterBinary.isEmpty() && QFileInfo::exists(m_updaterBinary)) {
        offerRestart();
    } else {
        offerReleasesPage();
    }
#else
    offerReleasesPage();
#endif
}

void JartonSelfUpdateService::startDownload()
{
    const QString zipPath = cachedAssetPath(m_dataRoot, Asset::MacZip, m_version);
    FS::ensureFilePathExists(zipPath);
    qInfo() << "[jarton.selfupdate] downloading launcher" << m_version;
    m_dlJob.reset(new NetJob(QStringLiteral("Jarton launcher update %1").arg(m_version), m_network));
    m_dlJob->addNetAction(Net::Download::makeFile(QUrl(assetUrl(Asset::MacZip, m_version)), zipPath));
    connect(m_dlJob.get(), &NetJob::succeeded, this, &JartonSelfUpdateService::prepareAndOffer);
    connect(m_dlJob.get(), &NetJob::failed, this, [this, zipPath](QString reason) {
        qWarning() << "[jarton.selfupdate] download failed:" << reason;
        FS::deletePath(zipPath);
        offerReleasesPage();
    });
    m_dlJob->start();
}

void JartonSelfUpdateService::prepareAndOffer()
{
    const QString zipPath = cachedAssetPath(m_dataRoot, Asset::MacZip, m_version);
    if (QFileInfo(zipPath).size() <= 0) {
        discardAndFallBack(QStringLiteral("downloaded archive is empty"));
        return;
    }
    const QString unpacked = FS::PathCombine(versionCacheDir(), "unpacked");
    FS::deletePath(unpacked);

    // ditto, not MMCZip: the bundle only survives extraction that keeps
    // symlinks, exec bits and the code signature intact.
    auto* ditto = new QProcess(this);
    connect(ditto, &QProcess::finished, this, [this, ditto, unpacked](int code, QProcess::ExitStatus status) {
        ditto->deleteLater();
        if (status != QProcess::NormalExit || code != 0) {
            discardAndFallBack(QStringLiteral("archive failed to extract (ditto exit %1)").arg(code));
            return;
        }
        m_newAppPath = locateAppBundle(unpacked);
        if (m_newAppPath.isEmpty()) {
            discardAndFallBack(QStringLiteral("archive has no .app inside"));
            return;
        }
        offerRestart();
    });
    ditto->start(QStringLiteral("/usr/bin/ditto"), { QStringLiteral("-x"), QStringLiteral("-k"), zipPath, unpacked });
}

QString JartonSelfUpdateService::locateAppBundle(const QString& unpackedRoot) const
{
    QStringList candidates{ unpackedRoot };
    const QDir root(unpackedRoot);
    for (const QString& sub : root.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        candidates << root.absoluteFilePath(sub);
    }
    for (const QString& base : candidates) {
        const QDir dir(base);
        for (const QString& name : dir.entryList({ QStringLiteral("*.app") }, QDir::Dirs)) {
            return dir.absoluteFilePath(name);
        }
    }
    return {};
}

void JartonSelfUpdateService::offerRestart()
{
    if (m_updatesAllowed && !m_updatesAllowed()) {
        // A game is running; updating now would kill it. Try again once it's likely over.
        QTimer::singleShot(5 * 60 * 1000, this, &JartonSelfUpdateService::offerRestart);
        return;
    }
    QMessageBox box;
    box.setWindowTitle(tr("Launcher update ready"));
    box.setIcon(QMessageBox::Information);
#if defined(Q_OS_WIN)
    box.setText(tr("Jarton Client %1 is available (you have %2).").arg(m_version, BuildConfig.versionString()));
    box.setInformativeText(tr("The launcher will close while the updater downloads and installs it. Update now?"));
    auto* restartBtn = box.addButton(tr("Update now"), QMessageBox::AcceptRole);
#else
    box.setText(tr("Jarton Client %1 is ready (you have %2).").arg(m_version, BuildConfig.versionString()));
    box.setInformativeText(tr("Restart to update?"));
    auto* restartBtn = box.addButton(tr("Restart to update"), QMessageBox::AcceptRole);
#endif
    box.addButton(tr("Later"), QMessageBox::RejectRole);
    box.exec();
    if (box.clickedButton() != restartBtn) {
        // Download stays cached; the next launch re-offers without re-downloading.
        return;
    }
    if (m_updatesAllowed && !m_updatesAllowed()) {
        return;  // a game launched while the prompt sat open
    }
#if defined(Q_OS_MACOS)
    applyMacUpdate();
#elif defined(Q_OS_WIN)
    runWindowsUpdater();
#endif
}

void JartonSelfUpdateService::applyMacUpdate()
{
    const QString bundlePath = runningBundlePath();
    if (bundlePath.isEmpty()) {
        macFallback(tr("the launcher isn't running from an app bundle"));
        return;
    }
    if (!QFileInfo(QFileInfo(bundlePath).absolutePath()).isWritable()) {
        macFallback(tr("no permission to replace %1").arg(bundlePath));
        return;
    }

    // Park the running bundle instead of deleting it: macOS keeps executing
    // from the moved inodes, and a failed swap can rename it straight back.
    const QString parked = QStringLiteral("%1.old-%2").arg(bundlePath, BuildConfig.versionString());
    FS::deletePath(parked);
    if (!QDir().rename(bundlePath, parked)) {
        macFallback(tr("the current app couldn't be moved aside"));
        return;
    }
    if (!moveBundle(m_newAppPath, bundlePath)) {
        QDir().rename(parked, bundlePath);
        macFallback(tr("the new app couldn't be moved into place"));
        return;
    }

    qInfo() << "[jarton.selfupdate] installed" << m_version << "at" << bundlePath << "- relaunching";
    QProcess::startDetached(QStringLiteral("open"), { QStringLiteral("-n"), bundlePath });
    QCoreApplication::quit();
}

bool JartonSelfUpdateService::moveBundle(const QString& src, const QString& dst)
{
    if (QDir().rename(src, dst)) {
        return true;
    }
    // The update cache and /Applications can sit on different volumes; rename
    // can't cross them, ditto clones the bundle faithfully.
    if (QProcess::execute(QStringLiteral("/usr/bin/ditto"), { src, dst }) == 0) {
        FS::deletePath(src);
        return true;
    }
    FS::deletePath(dst);
    return false;
}

void JartonSelfUpdateService::runWindowsUpdater()
{
    QProcess proc;
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("__COMPAT_LAYER"), QStringLiteral("RUNASINVOKER"));
    proc.setProcessEnvironment(env);
    proc.setProgram(m_updaterBinary);
    proc.setArguments({ QStringLiteral("--dir"), m_dataRoot, QStringLiteral("--install-version"), m_version });
    if (!proc.startDetached()) {
        qWarning() << "[jarton.selfupdate] updater failed to start:" << proc.errorString();
        offerReleasesPage();
        return;
    }
    QCoreApplication::quit();
}

void JartonSelfUpdateService::discardAndFallBack(const QString& reason)
{
    qWarning() << "[jarton.selfupdate]" << reason << "- discarding cached update";
    FS::deletePath(versionCacheDir());
    offerReleasesPage();
}

void JartonSelfUpdateService::macFallback(const QString& reason)
{
    qWarning() << "[jarton.selfupdate] manual fallback:" << reason;
    QMessageBox box;
    box.setWindowTitle(tr("Update needs a hand"));
    box.setIcon(QMessageBox::Warning);
    box.setText(tr("Jarton Client %1 was downloaded but couldn't be installed automatically: %2.").arg(m_version, reason));
    box.setInformativeText(
        tr("The downloaded zip will be shown in Finder. Quit the launcher, then replace the app with the one from the zip."));
    box.exec();
    QProcess::startDetached(QStringLiteral("open"),
                            { QStringLiteral("-R"), cachedAssetPath(m_dataRoot, Asset::MacZip, m_version) });
}

void JartonSelfUpdateService::offerReleasesPage()
{
    QMessageBox box;
    box.setWindowTitle(tr("Launcher update available"));
    box.setIcon(QMessageBox::Information);
    box.setText(tr("A newer Jarton Client is available (%1, you have %2).").arg(m_version, BuildConfig.versionString()));
    box.setInformativeText(tr("Open the releases page to download the installer for your platform?"));
    auto* openBtn = box.addButton(tr("Open releases"), QMessageBox::AcceptRole);
    box.addButton(tr("Later"), QMessageBox::RejectRole);
    box.exec();
    if (box.clickedButton() == openBtn) {
        DesktopServices::openUrl(QUrl(QString::fromLatin1(g_releasesUrl)));
    }
}

}  // namespace Jarton
