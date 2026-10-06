// SPDX-License-Identifier: GPL-3.0-only
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

#include "jarton/JartonPackApply.h"
#include "jarton/services/PackRecord.h"

using namespace Jarton;

class JartonPackApplyTest : public QObject {
    Q_OBJECT

    static bool put(const QString& path, const QByteArray& bytes = "x")
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile f(path);
        return f.open(QIODevice::WriteOnly) && f.write(bytes) == bytes.size();
    }

  private slots:
    void resolved_dir_follows_symlinks()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        QVERIFY(QDir().mkpath(d.filePath("real")));
        QVERIFY(QFile::link(d.filePath("real"), d.filePath("link")));
        QCOMPARE(PackApply::resolvedDir(d.filePath("link")), QFileInfo(d.filePath("real")).canonicalFilePath());
        QCOMPARE(PackApply::resolvedDir(d.filePath("missing")), d.filePath("missing"));
    }

    void finds_game_dir_nested()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        QVERIFY(put(d.filePath("Jarton/minecraft/mods/a.jar")));
        QCOMPARE(PackApply::findGameDir(d.path()), QDir(d.filePath("Jarton/minecraft")).absolutePath());
    }

    void finds_pack_root_nested()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        QVERIFY(put(d.filePath("Jarton/mmc-pack.json"), "{}"));
        QVERIFY(put(d.filePath("Jarton/minecraft/mods/a.jar")));
        QCOMPARE(PackApply::findPackRoot(d.path()), QDir(d.filePath("Jarton")).absolutePath());
    }

    void swap_mods_replaces_set_keeps_jartonui()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString game = d.filePath("inst/minecraft");
        const QString pack = d.filePath("pack/minecraft");
        QVERIFY(put(game + "/mods/old.jar"));
        QVERIFY(put(game + "/mods/player_added.jar"));
        QVERIFY(put(game + "/mods/JartonUI.jar", "ui"));
        QVERIFY(put(pack + "/mods/new1.jar"));
        QVERIFY(put(pack + "/mods/new2.jar"));

        QString err;
        QVERIFY2(PackApply::swapMods(game, pack, &err), qPrintable(err));

        const QDir mods(game + "/mods");
        const auto jars = mods.entryList({ "*.jar" }, QDir::Files, QDir::Name);
        QCOMPARE(jars, (QStringList{ "JartonUI.jar", "new1.jar", "new2.jar" }));
    }

    void fill_configs_only_fills_gaps()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString game = d.filePath("inst/minecraft");
        const QString pack = d.filePath("pack/minecraft");
        QVERIFY(put(game + "/config/keep.cfg", "mine"));
        QVERIFY(put(pack + "/config/keep.cfg", "theirs"));
        QVERIFY(put(pack + "/config/fresh.cfg", "theirs"));

        PackApply::fillConfigs(game, pack);

        QFile keep(game + "/config/keep.cfg");
        QVERIFY(keep.open(QIODevice::ReadOnly));
        QCOMPARE(keep.readAll(), QByteArray("mine"));
        QVERIFY(QFile::exists(game + "/config/fresh.cfg"));
    }

    void swap_version_overwrites_mmc_pack()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString inst = d.filePath("inst");
        const QString pack = d.filePath("pack");
        QVERIFY(put(inst + "/mmc-pack.json", "OLD"));
        QVERIFY(put(pack + "/mmc-pack.json", "NEW"));
        QVERIFY(put(pack + "/minecraft/mods/a.jar"));

        QString err;
        QVERIFY2(PackApply::swapVersion(inst, pack, &err), qPrintable(err));
        QFile f(inst + "/mmc-pack.json");
        QVERIFY(f.open(QIODevice::ReadOnly));
        QCOMPARE(f.readAll(), QByteArray("NEW"));
    }

    void migration_replaces_mods_and_version_keeps_user_data()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString inst = d.filePath("inst");
        const QString game = inst + "/minecraft";
        // player-modified instance: an added mod, user settings, a resource pack, a world
        QVERIFY(put(inst + "/mmc-pack.json", "v1-components"));
        QVERIFY(put(game + "/mods/old.jar"));
        QVERIFY(put(game + "/mods/player_added.jar"));
        QVERIFY(put(game + "/options.txt", "fov:80"));
        QVERIFY(put(game + "/resourcepacks/cool.zip", "rp"));
        QVERIFY(put(game + "/saves/world/level.dat", "world"));

        const QString packRoot = d.filePath("pack/Jarton");
        QVERIFY(put(packRoot + "/mmc-pack.json", "v2-components"));
        QVERIFY(put(packRoot + "/minecraft/mods/new.jar"));
        QVERIFY(put(packRoot + "/minecraft/config/new.cfg", "cfg"));

        QString err;
        QVERIFY2(PackApply::applyMigration(inst, game, d.filePath("pack"), "26.2", "2.0.0", &err), qPrintable(err));

        const QDir mods(game + "/mods");
        QCOMPARE(mods.entryList({ "*.jar" }, QDir::Files, QDir::Name), (QStringList{ "new.jar" }));
        QVERIFY(!QFile::exists(game + "/mods/player_added.jar"));
        QVERIFY(QFile::exists(game + "/options.txt"));
        QVERIFY(QFile::exists(game + "/resourcepacks/cool.zip"));
        QVERIFY(QFile::exists(game + "/saves/world/level.dat"));
        QFile mmc(inst + "/mmc-pack.json");
        QVERIFY(mmc.open(QIODevice::ReadOnly));
        QCOMPARE(mmc.readAll(), QByteArray("v2-components"));

        const PackRecord rec = PackRecord::read(inst);
        QVERIFY(rec.valid);
        QCOMPARE(rec.mcVersion, QStringLiteral("26.2"));
        QCOMPARE(rec.packVersion, QStringLiteral("2.0.0"));
        QVERIFY(rec.modsMatch(game));  // re-baselined against the new mod set
    }

    void migration_fails_clean_on_bad_pack()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString inst = d.filePath("inst");
        const QString game = inst + "/minecraft";
        QVERIFY(put(game + "/mods/old.jar"));
        QString err;
        QVERIFY(!PackApply::applyMigration(inst, game, d.filePath("empty"), "26.2", "2.0.0", &err));
        QVERIFY(!err.isEmpty());
        QVERIFY(QFile::exists(game + "/mods/old.jar"));  // untouched
    }

    void migration_keeps_version_when_mods_fail()
    {
        QTemporaryDir d;
        QVERIFY(d.isValid());
        const QString inst = d.filePath("inst");
        const QString game = inst + "/minecraft";
        QVERIFY(put(inst + "/mmc-pack.json", "v1-components"));
        QVERIFY(put(game + "/mods/old.jar"));
        // A directory sitting where the pack's jar must be copied makes the copy fail.
        QVERIFY(QDir().mkpath(game + "/mods/new.jar"));

        const QString packRoot = d.filePath("pack/Jarton");
        QVERIFY(put(packRoot + "/mmc-pack.json", "v2-components"));
        QVERIFY(put(packRoot + "/minecraft/mods/new.jar"));

        QString err;
        QVERIFY(!PackApply::applyMigration(inst, game, d.filePath("pack"), "26.2", "2.0.0", &err));
        // Mods ran first and failed, so the version profile was never swapped.
        QFile mmc(inst + "/mmc-pack.json");
        QVERIFY(mmc.open(QIODevice::ReadOnly));
        QCOMPARE(mmc.readAll(), QByteArray("v1-components"));
    }
};

QTEST_GUILESS_MAIN(JartonPackApplyTest)
#include "JartonPackApply_test.moc"
