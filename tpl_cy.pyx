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


# tpl_cy.pyx
# TPL image data encoder and decoder in Cython.


################################################################
################################################################

ctypedef unsigned char u8
ctypedef unsigned short u16
ctypedef unsigned int u32


# 'data' must be RGBA8 raw data
cpdef bytes decodeRGB4A3(data, u32 width, u32 height, int noAlpha):
    cdef bytearray result = bytearray(width * height * 4)

    cdef u32 i, yTile, xTile, y, x
    cdef u16 pixel
    cdef u8 r, g, b, a
    cdef u32 pos

    i = 0

    for yTile in range(0, height, 4):
        for xTile in range(0, width, 4):
            for y in range(yTile, yTile + 4):
                for x in range(xTile, xTile + 4):
                    pixel = (data[i] << 8) | data[i+1]

                    if pixel & 0x8000:
                        r = (pixel & 0x1F) * 255 // 0x1F
                        g = ((pixel >> 5) & 0x1F) * 255 // 0x1F
                        b = ((pixel >> 10) & 0x1F) * 255 // 0x1F

                    else:
                        r = (pixel & 0xF) * 255 // 0xF
                        g = ((pixel & 0xF0) >> 4) * 255 // 0xF
                        b = ((pixel & 0xF00) >> 8) * 255 // 0xF

                    if noAlpha or pixel & 0x8000:
                        a = 0xFF

                    else:
                        a = ((pixel & 0x7000) >> 12) * 255 // 0x7

                    pos = (y * width + x) * 4

                    # works but slow
                    ## result[pos:pos + 4] = ((r << 24) | (g << 16) | (b << 8) | a).to_bytes(4, "big")

                    result[pos] = r
                    result[pos + 1] = g
                    result[pos + 2] = b
                    result[pos + 3] = a

                    i += 2 

    return bytes(result)


# 'tex' must be an ARGB32 QImage
cpdef encodeRGB4A3(tex, u32 width, u32 height):
    cdef bytearray result = bytearray(width * height * 2)

    cdef u32 i, yTile, xTile, y, x
    cdef u8 r, g, b, a
    cdef u16 rgb
    cdef u32 pixel

    i = 0

    for yTile in range(0, height, 4):
        for xTile in range(0, width, 4):
            for y in range(yTile, yTile + 4):
                for x in range(xTile, xTile + 4):
                    pixel = tex.pixel(x, y)
                    
                    a = pixel >> 24
                    r = (pixel >> 16) & 0xFF
                    g = (pixel >> 8) & 0xFF
                    b = pixel & 0xFF
                    
                    if a < 0xF7:
                        a //= 32
                        r //= 16
                        g //= 16
                        b //= 16

                        rgb = b | (g << 4) | (r << 8) | (a << 12)
                
                    else:
                        r //= 8
                        g //= 8
                        b //= 8
                        
                        rgb = b | (g << 5) | (r << 10) | 0x8000
                                                                                                            
                    result[i] = rgb >> 8
                    result[i + 1] = rgb & 0xFF

                    i += 2
                    
    return bytes(result)
