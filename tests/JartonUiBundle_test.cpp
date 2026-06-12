#include <QCryptographicHash>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>
#include "jarton/services/JartonUiCache.h"
#include "minecraft/JartonUiBundle.h"

class JartonUiBundleTest : public QObject {
    Q_OBJECT

    static QString shaOf(const QByteArray& bytes)
    {
        return QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
    }

    static QString writeFile(const QString& path, const QByteArray& bytes)
    {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly) || f.write(bytes) != bytes.size()) {
            return {};
        }
        return path;
    }

  private slots:
    void fabric_maps_to_version_jar() {
        QCOMPARE(JartonUiBundle::jarFor("net.fabricmc.fabric-loader", "1.21.11"),
                 QStringLiteral(":/jarton/JartonUI-1.21.11.jar"));
    }
    void quilt_maps_to_version_jar() {
        QCOMPARE(JartonUiBundle::jarFor("org.quiltmc.quilt-loader", "1.21.4"),
                 QStringLiteral(":/jarton/JartonUI-1.21.4.jar"));
    }
    void neoforge_maps_to_neoforge_jar() {
        QCOMPARE(JartonUiBundle::jarFor("net.neoforged", "1.21.11"), QStringLiteral(":/jarton/JartonUI-neoforge.jar"));
    }
    void forge_maps_to_forge_jar() {
        QCOMPARE(JartonUiBundle::jarFor("net.minecraftforge", "1.21.11"), QStringLiteral(":/jarton/JartonUI-forge.jar"));
    }
    void unknown_loader_is_empty() {
        QCOMPARE(JartonUiBundle::jarFor("com.mumfrey.liteloader", "1.21.11"), QString());
    }

    void commit_accepts_matching_sha_and_resolves() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        Jarton::JartonUiCache cache(dir.path());

        const QByteArray bytes("fake jar bytes");
        const QString dl = writeFile(dir.filePath("dl.jar"), bytes);
        QVERIFY(!dl.isEmpty());

        QVERIFY(cache.commit(dl, "1.21.4", shaOf(bytes), "1.2.1"));
        QCOMPARE(cache.recordedVersion("1.21.4"), QStringLiteral("1.2.1"));
        QCOMPARE(cache.recordedSha256("1.21.4"), shaOf(bytes));
        QCOMPARE(cache.verifiedJar("1.21.4"), cache.jarPath("1.21.4"));
        QCOMPARE(JartonUiBundle::resolve("net.fabricmc.fabric-loader", "1.21.4", cache), cache.jarPath("1.21.4"));
    }

    void commit_rejects_sha_mismatch_and_keeps_old_jar() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        Jarton::JartonUiCache cache(dir.path());

        const QByteArray old("old jar");
        QVERIFY(cache.commit(writeFile(dir.filePath("a.jar"), old), "1.21.4", shaOf(old), "1.2.0"));

        const QString bad = writeFile(dir.filePath("b.jar"), QByteArray("corrupted download"));
        QVERIFY(!cache.commit(bad, "1.21.4", shaOf(QByteArray("what the cdn promised")), "1.2.1"));
        QVERIFY(!QFile::exists(bad));

        QCOMPARE(cache.recordedVersion("1.21.4"), QStringLiteral("1.2.0"));
        QCOMPARE(cache.verifiedJar("1.21.4"), cache.jarPath("1.21.4"));
    }

    void tampered_jar_falls_back_to_bundle() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        Jarton::JartonUiCache cache(dir.path());

        const QByteArray bytes("legit jar");
        QVERIFY(cache.commit(writeFile(dir.filePath("dl.jar"), bytes), "1.21.4", shaOf(bytes), "1.2.1"));
        QVERIFY(!writeFile(cache.jarPath("1.21.4"), QByteArray("tampered")).isEmpty());

        QCOMPARE(cache.verifiedJar("1.21.4"), QString());
        QCOMPARE(JartonUiBundle::resolve("net.fabricmc.fabric-loader", "1.21.4", cache),
                 QStringLiteral(":/jarton/JartonUI-1.21.4.jar"));
    }

    void empty_cache_falls_back_to_bundle() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        Jarton::JartonUiCache cache(dir.path());
        QCOMPARE(JartonUiBundle::resolve("org.quiltmc.quilt-loader", "1.21.11", cache),
                 QStringLiteral(":/jarton/JartonUI-1.21.11.jar"));
    }

    void forge_ignores_cache() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        Jarton::JartonUiCache cache(dir.path());

        const QByteArray bytes("fabric-only jar");
        QVERIFY(cache.commit(writeFile(dir.filePath("dl.jar"), bytes), "1.21.11", shaOf(bytes), "1.2.1"));

        QCOMPARE(JartonUiBundle::resolve("net.minecraftforge", "1.21.11", cache),
                 QStringLiteral(":/jarton/JartonUI-forge.jar"));
        QCOMPARE(JartonUiBundle::resolve("net.neoforged", "1.21.11", cache),
                 QStringLiteral(":/jarton/JartonUI-neoforge.jar"));
    }
};

QTEST_GUILESS_MAIN(JartonUiBundleTest)
#include "JartonUiBundle_test.moc"
