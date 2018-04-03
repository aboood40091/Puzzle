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

from cpython cimport array
from cython cimport view
from libc.stdlib cimport malloc, free
from libc.string cimport memchr
from libc.string cimport memcpy


ctypedef unsigned char u8
ctypedef unsigned short u16
ctypedef unsigned int u32
ctypedef signed long long int64


cdef (u32, u32) GetUncompressedSize(u8 *inData):
    cdef u32 offset = 4
    cdef u32 outSize = inData[1] | (inData[2] << 8) | (inData[3] << 16)

    if not outSize:
        outSize = inData[4] | (inData[5] << 8) | (inData[6] << 16) | (inData[7] << 24)
        offset += 4

    return outSize, offset


cpdef bytes UncompressLZ77(bytes data):
    cdef:
        array.array dataArr = array.array('B', data)
        u8 *inData = dataArr.data.as_uchars

    if inData[0] != 0x11:
        return bytes(data)

    cdef:
        u32 inLength, outLength, offset, outIndex, copylen
        u8 flags, x, first, second, third, fourth
        u16 pos
        u8 *outData

    inLength = len(data)
    outLength, offset = GetUncompressedSize(inData)
    outData = <u8 *>malloc(outLength)

    try:
        outIndex = 0
        while outIndex < outLength and offset < inLength:
            flags = inData[offset]
            offset += 1

            for x in range(7, -1, -1):
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

                    for _ in range(copylen):
                        outData[outIndex] = outData[outIndex - pos]; outIndex += 1

                else:
                    outData[outIndex] = inData[offset]
                    offset += 1
                    outIndex += 1

        return bytes(<u8[:outLength]>outData)

    finally:
        free(outData)


cdef (u8 *, u32) compressionSearch(u8 *src, u8 *src_pos, int max_len, u32 range_, u8 *src_end):
    cdef:
        u32 found_len = 1

        u8 *found
        u8 *search
        u8 *cmp_end
        u8 c1
        u8 *cmp1
        u8 *cmp2
        int len_

    if src + 2 < src_end:
        search = src - range_
        if search < src_pos:
             search = src_pos

        cmp_end = src + max_len
        if cmp_end > src_end:
            cmp_end = src_end

        c1 = src[0]
        while search < src:
            search = <u8 *>memchr(search, c1, src - search)
            if not search:
                break

            cmp1 = search + 1
            cmp2 = src + 1

            while cmp2 < cmp_end and cmp1[0] == cmp2[0]:
                cmp1 += 1; cmp2 += 1

            len_ = cmp2 - src

            if found_len < len_:
                found_len = len_
                found = search
                if found_len == max_len:
                    break

            search += 1

    return found, found_len


cpdef bytes CompressLZ77(bytes src_):
    cdef u32 src_len = len(src_)
    assert src_len <= 0xFFFFFF

    cdef:
        array.array dataArr = array.array('B', src_)
        u8 *src = dataArr.data.as_uchars
        u8 *src_pos = src
        u8 *src_end = src + src_len

        u8 *dest = <u8 *>malloc(len(src_) + (len(src_) + 8) // 8)
        u8 *dest_pos = dest

    dest[0] = 0x11
    dest[1] = src_len & 0xFF
    dest[2] = (src_len >> 8) & 0xFF
    dest[3] = (src_len >> 16) & 0xFF
    dest += 4

    cdef:
        u8 *code_byte = dest

        u32 range_ = 0x1000
        int max_len = 0x110

        int i
        u32 found_len, delta
        u8 *found

    try:
        while src < src_end:
            code_byte = dest
            dest[0] = 0; dest += 1

            for i in range(8):
                if src >= src_end:
                    break

                found_len = 1

                if range_:
                    found, found_len = compressionSearch(src, src_pos, max_len, range_, src_end)

                if found_len > 2:
                    code_byte[0] |= 1 << (7 - i)

                    delta = src - found - 1

                    if found_len < 0x11:
                        dest[0] = delta >> 8 | (found_len - 1) << 4; dest += 1
                        dest[0] = delta & 0xFF; dest += 1

                    else:
                        dest[0] = ((found_len - 0x11) & 0xFF) >> 4; dest += 1
                        dest[0] = delta >> 8 | ((found_len - 0x11) & 0xF) << 4; dest += 1
                        dest[0] = delta & 0xFF; dest += 1

                    src += found_len

                else:
                    dest[0] = src[0]; dest += 1; src += 1

        return bytes(<u8[:dest - dest_pos]>dest_pos)

    finally:
        free(dest_pos)
