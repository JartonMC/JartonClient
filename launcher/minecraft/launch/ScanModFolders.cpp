// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Prism Launcher - Minecraft Launcher
 *  Copyright (C) 2022 Sefa Eyeoglu <contact@scrumplex.net>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * This file incorporates work covered by the following copyright and
 * permission notice:
 *
 *      Copyright 2013-2021 MultiMC Contributors
 *
 *      Licensed under the Apache License, Version 2.0 (the "License");
 *      you may not use this file except in compliance with the License.
 *      You may obtain a copy of the License at
 *
 *          http://www.apache.org/licenses/LICENSE-2.0
 *
 *      Unless required by applicable law or agreed to in writing, software
 *      distributed under the License is distributed on an "AS IS" BASIS,
 *      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *      See the License for the specific language governing permissions and
 *      limitations under the License.
 */

#include "ScanModFolders.h"
#include "FileSystem.h"
#include "MMCZip.h"
#include "launch/LaunchTask.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/mod/ModFolderModel.h"

void ScanModFolders::executeTask()
{
    auto m_inst = m_parent->instance();

    // updateFinished fires on every model refresh, including the file-watcher re-scans that
    // happen while the game is running (the injected UI jar churns the mods folder). Tracking the
    // connections lets us drop them the moment the scan completes so a later refresh can't re-enter
    // checkDone() and call emitSucceeded() on an already-finished task.
    auto loaders = m_inst->loaderModList();
    m_connections.append(connect(loaders, &ModFolderModel::updateFinished, this, &ScanModFolders::modsDone));
    if (!loaders->update()) {
        m_modsDone = true;
    }

    auto cores = m_inst->coreModList();
    m_connections.append(connect(cores, &ModFolderModel::updateFinished, this, &ScanModFolders::coreModsDone));
    if (!cores->update()) {
        m_coreModsDone = true;
    }

    auto nils = m_inst->nilModList();
    m_connections.append(connect(nils, &ModFolderModel::updateFinished, this, &ScanModFolders::nilModsDone));
    if (!nils->update()) {
        m_nilModsDone = true;
    }
    checkDone();
}

void ScanModFolders::modsDone()
{
    m_modsDone = true;
    checkDone();
}

void ScanModFolders::coreModsDone()
{
    m_coreModsDone = true;
    checkDone();
}

void ScanModFolders::nilModsDone()
{
    m_nilModsDone = true;
    checkDone();
}

void ScanModFolders::checkDone()
{
    if (!m_modsDone || !m_coreModsDone || !m_nilModsDone) {
        return;
    }
    if (m_finished) {
        return;
    }
    m_finished = true;

    for (const auto& conn : m_connections) {
        disconnect(conn);
    }
    m_connections.clear();

    emitSucceeded();
}
