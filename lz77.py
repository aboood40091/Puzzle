#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Puzzle
# Copyright © 2010 Tempus, 2017 MasterVermilli0n/AboodXD

# This file is part of Puzzle.

# Puzzle is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Puzzle is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


def GetUncompressedSize(inData):
    offset = 4
    outSize = inData[1] | (inData[2] << 8) | (inData[3] << 16)

    if not outSize:
        outSize = inData[4] | (inData[5] << 8) | (inData[6] << 16) | (inData[7] << 24)
        offset += 4

    return outSize, offset


def UncompressLZ77(inData):
    if inData[0] != 0x11:
        return inData

    inLength = len(inData)
    outLength, offset = GetUncompressedSize(inData)
    outData = bytearray(outLength)
    
    outIndex = 0

    while outIndex < outLength and offset < inLength:
        flags = inData[offset]
        offset += 1

        for x in reversed(range(8)):
            if outIndex >= outLength or offset >= inLength:
                break

            if flags & (1 << x):
                first = inData[offset]
                offset += 1

                second = inData[offset]
                offset += 1

                if first < 32:
                    third = inData[offset]
                    offset += 1

                    if first >= 16:
                        fourth = inData[offset]
                        offset += 1

                        pos = (((third & 0xF) << 8) | fourth) + 1
                        copylen = ((second << 4) | ((first & 0xF) << 12) | (third >> 4)) + 273

                    else:
                        pos = (((second & 0xF) << 8) | third) + 1
                        copylen = (((first & 0xF) << 4) | (second >> 4)) + 17

                else:
                    pos = (((first & 0xF) << 8) | second) + 1
                    copylen = (first >> 4) + 1

                for y in range(copylen):
                    outData[outIndex + y] = outData[outIndex - pos + y]

                outIndex += copylen

            else:
                outData[outIndex] = inData[offset]
                offset += 1
                outIndex += 1

    return bytes(outData)


def compressionSearch(data, pos, maxMatchLen, maxMatchDiff, src_end):
    """
    Find the longest match in `data` at or after `pos`.
    From ndspy, thanks RoadrunnerWMC!
    """
    start = max(0, pos - maxMatchDiff)

    lower = 0
    upper = min(maxMatchLen, src_end - pos)

    recordMatchPos = 0
    recordMatchLen = 0

    while lower <= upper:
        matchLen = (lower + upper) // 2
        match = data[pos:pos + matchLen]
        matchPos = data.find(match, start, pos)

        if matchPos == -1:
            upper = matchLen - 1
        else:
            if matchLen > recordMatchLen:
                recordMatchPos, recordMatchLen = matchPos, matchLen
            lower = matchLen + 1

    return recordMatchPos, recordMatchLen


def CompressLZ77(src):
    dest = bytearray(b'\x11')
    dest += len(src).to_bytes(3, "little")

    src_end = len(src)

    search_range = 0x1000
    max_len = 0x110

    pos = 0

    while pos < src_end:
        buffer = bytearray()
        code_byte = 0

        for i in range(8):
            if pos >= src_end:
                break

            found, found_len = compressionSearch(src, pos, max_len, search_range, src_end)

            if found_len > 2:
                code_byte |= 1 << (7 - i)

                delta = pos - found - 1

                if found_len < 0x11:
                    buffer.append(delta >> 8 | (found_len - 1) << 4)
                    buffer.append(delta & 0xFF)

                else:
                    buffer.append(((found_len - 0x11) & 0xFF) >> 4)
                    buffer.append(delta >> 8 | ((found_len - 0x11) & 0xF) << 4)
                    buffer.append(delta & 0xFF)

                pos += found_len

            else:
                buffer.append(src[pos])
                pos += 1

        dest.append(code_byte)
        dest += buffer

    return dest
