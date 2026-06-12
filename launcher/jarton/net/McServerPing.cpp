// SPDX-License-Identifier: GPL-3.0-only
#include "McServerPing.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>

namespace Jarton {

QByteArray McServerPing::writeVarInt(int32_t value)
{
    QByteArray out;
    auto v = static_cast<uint32_t>(value);
    while (true) {
        if ((v & ~0x7FU) == 0U) {
            out.append(static_cast<char>(v));
            return out;
        }
        out.append(static_cast<char>((v & 0x7FU) | 0x80U));
        v >>= 7U;
    }
}

int32_t McServerPing::readVarInt(const QByteArray& data, int& cursor, bool& ok)
{
    uint32_t result = 0U;
    uint32_t shift = 0U;
    while (true) {
        if (cursor >= data.size() || shift >= 35U) {
            ok = false;
            return 0;
        }
        const auto byte = static_cast<uint8_t>(data.at(cursor++));
        result |= static_cast<uint32_t>(byte & 0x7FU) << shift;
        if ((byte & 0x80U) == 0U) {
            ok = true;
            return static_cast<int32_t>(result);
        }
        shift += 7U;
    }
}

namespace {

QByteArray writeString(const QString& s)
{
    const QByteArray utf8 = s.toUtf8();
    QByteArray out = McServerPing::writeVarInt(static_cast<int32_t>(utf8.size()));
    out.append(utf8);
    return out;
}

QByteArray framePacket(int packetId, const QByteArray& payload)
{
    QByteArray inner = McServerPing::writeVarInt(packetId);
    inner.append(payload);
    QByteArray out = McServerPing::writeVarInt(static_cast<int32_t>(inner.size()));
    out.append(inner);
    return out;
}

}  // namespace

QByteArray McServerPing::buildHandshake(const QString& host, uint16_t port, int protocolVersion)
{
    QByteArray payload;
    payload.append(writeVarInt(protocolVersion));
    payload.append(writeString(host));
    // Server address port, big-endian unsigned 16
    const auto p = static_cast<uint32_t>(port);
    payload.append(static_cast<char>((p >> 8U) & 0xFFU));
    payload.append(static_cast<char>(p & 0xFFU));
    // Next state: 1 = status
    payload.append(writeVarInt(1));
    return framePacket(0x00, payload);
}

QByteArray McServerPing::buildStatusRequest()
{
    return framePacket(0x00, QByteArray{});
}

McPingResult McServerPing::parseStatusResponse(const QByteArray& payload)
{
    McPingResult result;
    int cursor = 0;
    bool ok = false;

    const int32_t outerLength = readVarInt(payload, cursor, ok);
    if (!ok) {
        result.errorString = QStringLiteral("malformed packet length");
        return result;
    }
    if (outerLength > payload.size() - cursor) {
        result.errorString = QStringLiteral("truncated packet");
        return result;
    }

    const int32_t packetId = readVarInt(payload, cursor, ok);
    if (!ok || packetId != 0x00) {
        result.errorString = QStringLiteral("unexpected packet id");
        return result;
    }

    const int32_t jsonLength = readVarInt(payload, cursor, ok);
    if (!ok || jsonLength > payload.size() - cursor) {
        result.errorString = QStringLiteral("truncated json");
        return result;
    }

    const QByteArray jsonBytes = payload.mid(cursor, jsonLength);
    QJsonParseError parseErr;
    const QJsonDocument doc = QJsonDocument::fromJson(jsonBytes, &parseErr);
    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        result.errorString = QStringLiteral("invalid json: ") + parseErr.errorString();
        return result;
    }

    const QJsonObject root = doc.object();
    const QJsonObject players = root.value("players").toObject();
    result.playersOnline = players.value("online").toInt(0);
    result.playersMax = players.value("max").toInt(0);

    const QJsonValue descVal = root.value("description");
    if (descVal.isString()) {
        result.motd = descVal.toString();
    } else if (descVal.isObject()) {
        const QJsonObject descObj = descVal.toObject();
        if (descObj.contains("text")) {
            result.motd = descObj.value("text").toString();
        } else if (descObj.contains("extra")) {
            QString assembled;
            const QJsonArray extra = descObj.value("extra").toArray();
            for (const auto& part : extra) {
                if (part.isObject()) {
                    assembled += part.toObject().value("text").toString();
                } else if (part.isString()) {
                    assembled += part.toString();
                }
            }
            result.motd = assembled;
        }
    }

    const QJsonObject version = root.value("version").toObject();
    result.versionName = version.value("name").toString();
    result.protocolVersion = version.value("protocol").toInt(0);

    result.ok = true;
    return result;
}

}  // namespace Jarton
