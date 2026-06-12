#include <QTest>
#include "minecraft/JartonUiBundle.h"

class JartonUiBundleTest : public QObject {
    Q_OBJECT
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
};

QTEST_GUILESS_MAIN(JartonUiBundleTest)
#include "JartonUiBundle_test.moc"
