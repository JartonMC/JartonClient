#include <QTest>
#include "BuildConfig.h"
#include "jarton/services/JartonSelfUpdateService.h"

using Jarton::JartonSelfUpdateService;
using Asset = Jarton::JartonSelfUpdateService::Asset;

class JartonSelfUpdateTest : public QObject {
    Q_OBJECT
  private slots:
    void mac_asset_name() {
        QCOMPARE(JartonSelfUpdateService::assetName(Asset::MacZip, "1.2.0"), QStringLiteral("JartonClient-macOS-1.2.0.zip"));
    }
    void windows_portable_asset_name() {
        QCOMPARE(JartonSelfUpdateService::assetName(Asset::WindowsPortable, "1.2.0"),
                 QStringLiteral("JartonClient-Windows-MSVC-Portable-1.2.0.zip"));
    }
    void windows_setup_asset_name() {
        QCOMPARE(JartonSelfUpdateService::assetName(Asset::WindowsSetup, "1.2.0"),
                 QStringLiteral("JartonClient-Windows-MSVC-Setup-1.2.0.exe"));
    }
    void url_points_at_version_tag() {
        // Base tracks the configured updater repo (public vs staff channel), so
        // build it the same way the service does instead of hardcoding one repo.
        // Staff builds carry the channel key as a query param.
        QString expected = BuildConfig.UPDATER_GITHUB_REPO
            + QStringLiteral("/releases/download/1.2.0/JartonClient-macOS-1.2.0.zip");
        if (!BuildConfig.JARTON_UPDATE_KEY.isEmpty())
            expected += QStringLiteral("?k=") + BuildConfig.JARTON_UPDATE_KEY;
        QCOMPARE(JartonSelfUpdateService::assetUrl(Asset::MacZip, "1.2.0"), expected);
    }
    void cache_lives_under_updates_per_version() {
        QCOMPARE(JartonSelfUpdateService::cachedAssetPath("/data", Asset::MacZip, "1.2.0"),
                 QStringLiteral("/data/updates/1.2.0/JartonClient-macOS-1.2.0.zip"));
    }
};

QTEST_GUILESS_MAIN(JartonSelfUpdateTest)
#include "JartonSelfUpdate_test.moc"
