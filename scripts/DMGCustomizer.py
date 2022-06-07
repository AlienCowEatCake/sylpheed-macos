#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import re
import struct
import sys

for package in {'ds_store-1.3.0', 'mac_alias-2.2.0', 'biplist-1.0.3'}:
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), package))

import ds_store
import mac_alias


class AliasCodec(object):
    @staticmethod
    def encode(alias):
        return alias.to_bytes()

    @staticmethod
    def decode(bytes):
        return mac_alias.Alias.from_bytes(bytes)


class BackgroundCodec(object):
    @staticmethod
    def encode(data):
        if data[0] == b'DefB':
            return struct.pack(b'>4sII', data[0], 0x00000000, 0x00000000)
        if data[0] == b'ClrB':
            return struct.pack(b'>4sHHHH', data[0], data[1]['r'], data[1]['g'], data[1]['b'], 0x0000)
        if data[0] == b'PctB':
            return struct.pack(b'>4sII', data[0], data[1]['pict_size'], 0x00000000)
        return data[1]

    @staticmethod
    def decode(bytesData):
        if isinstance(bytesData, bytearray):
            kind, = struct.unpack_from(b'>4s', bytes(bytesData[:4]))
            if kind == b'DefB':
                """Default background"""
                return (kind)
            if kind == b'ClrB':
                """Solid color"""
                r, g, b = struct.unpack_from(b'>HHH', bytes(bytesData[4:]))
                return (kind, {'r': r, 'g': g, 'b': b})
            if kind == b'PctB':
                """Picture"""
                size, = struct.unpack_from(b'>I', bytes(bytesData[4:]))
                return (kind, {'pict_size': size})
        else:
            kind, = struct.unpack(b'>4s', bytesData[:4])
            if kind == b'DefB':
                """Default background"""
                return (kind)
            if kind == b'ClrB':
                """Solid color"""
                r, g, b = struct.unpack(b'>BBB', bytesData[4:])
                return (kind, {'r': r, 'g': g, 'b': b})
            if kind == b'PctB':
                """Picture"""
                size, = struct.unpack(b'>I', bytesData[4:])
                return (kind, {'pict_size': size})
        return (b'blob', bytesData)


class IconViewCodec(object):
    @staticmethod
    def encode(data):
        if data[0] == b'icvo':
            flags = data[1]['flags']
            icon_size = data[1]['icon_size']
            arranged = data[1]['arranged']
            return struct.pack(b'>4s8sH4s', data[0], flags, icon_size, arranged)
        if data[0] == b'icv4':
            icon_size = data[1]['icon_size']
            arranged = data[1]['arranged']
            flags = data[1]['flags']
            label_positon = data[1]['label_positon']
            return struct.pack(b'>4sH4s4s12s', data[0], icon_size, arranged, label_positon, flags)
        return data[1]

    @staticmethod
    def decode(bytesData):
        if isinstance(bytesData, bytearray):
            kind, = struct.unpack_from(b'>4s', bytes(bytesData[:4]))
            if kind == b'icvo':
                flags, icon_size, arranged = struct.unpack_from(b'>8sH4s', bytes(bytesData[4:]))
                return (kind, {'flags': flags, 'icon_size': icon_size, 'arranged': arranged})
            if kind == b'icv4':
                icon_size, arranged, label_positon, flags = struct.unpack_from(b'>H4s4s12s', bytes(bytesData[4:]))
                return (kind, {'icon_size': icon_size, 'arranged': arranged, 'label_positon': label_positon, 'flags': flags})
        else:
            kind, = struct.unpack(b'>4s', bytesData[:4])
            if kind == b'icvo':
                flags, icon_size, arranged = struct.unpack(b'>8sH4s', bytesData[4:])
                return (kind, {'flags': flags, 'icon_size': icon_size, 'arranged': arranged})
            if kind == b'icv4':
                icon_size, arranged, label_positon, flags = struct.unpack(b'>H4s4s12s', bytesData[4:])
                return (kind, {'icon_size': icon_size, 'arranged': arranged, 'label_positon': label_positon, 'flags': flags})
        return (b'blob', bytesData)


class FinderWindowInfoCodec(object):
    @staticmethod
    def encode(info):
        top = info[0]['top']
        left = info[0]['left']
        bottom = info[0]['bottom']
        right = info[0]['right']
        view = info[0]['view']
        tail = info[0]['tail'] if 'tail' in info[0] else b'\x00\x00\x00\x00'
        return struct.pack(b'>hhhh4s4s', top, left, bottom, right, view, tail)

    @staticmethod
    def decode(bytesData):
        if isinstance(bytesData, bytearray):
            top, left, bottom, right, view, tail = struct.unpack_from(b'>hhhh4s4s', bytes(bytesData[:16]))
        else:
            top, left, bottom, right, view, tail = struct.unpack(b'>hhhh4s4s', bytesData[:16])
        return ({'top': top, 'left': left, 'bottom': bottom, 'right': right, 'view': view, 'tail': tail})


def dump_info(ds):
    def _dump_item(item, value):
        print('filename=', item.filename, 'code=', item.code, 'type=', item.type, 'value=', value)
    for item in ds._traverse(None):
        if item.code == b'BKGD':
            _dump_item(item, BackgroundCodec.decode(item.value))
        elif item.code == b'pict':
            _dump_item(item, AliasCodec.decode(item.value).__repr__())
        elif item.code == b'fwi0':
            _dump_item(item, FinderWindowInfoCodec.decode(item.value))
        elif item.code == b'icvo':
            _dump_item(item, IconViewCodec.decode(item.value))
        else:
            _dump_item(item, item.value)


def main():
    """
    Документация: https://metacpan.org/pod/distribution/Mac-Finder-DSStore/DSStoreFormat.pod

    Пример '/Volumes/Sylpheed/.DS_Store':
    filename= . code= b'Iloc' type= <class 'ds_store.store.ILocCodec'> value= (204, 152)
    filename= . code= b'bwsp' type= <class 'ds_store.store.PlistCodec'> value= {'WindowBounds': '{{217, 145}, {541, 233}}', 'ShowSidebar': False, 'ShowStatusBar': True, 'ShowPathbar': False, 'ShowToolbar': False, 'SidebarWidth': 192}
    filename= . code= b'icvp' type= <class 'ds_store.store.PlistCodec'> value= {'backgroundColorBlue': 0.9819161891937256, 'gridSpacing': 100.0, 'textSize': 12.0, 'backgroundColorRed': 0.699933648109436, 'backgroundType': 1, 'backgroundColorGreen': 0.7402167320251465, 'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'showItemInfo': False, 'viewOptionsVersion': 0, 'arrangeBy': 'none', 'labelOnBottom': True, 'showIconPreview': True, 'iconSize': 128.0}
    filename= . code= b'vstl' type= b'type' value= b'icnv'
    filename= Documents code= b'Iloc' type= <class 'ds_store.store.ILocCodec'> value= (448, 76)
    filename= Documents code= b'bwsp' type= <class 'ds_store.store.PlistCodec'> value= {'WindowBounds': '{{52, 305}, {770, 405}}', 'ShowSidebar': False, 'ShowStatusBar': True, 'ShowPathbar': False, 'ShowToolbar': False, 'SidebarWidth': 192}
    filename= README.rtf code= b'Iloc' type= <class 'ds_store.store.ILocCodec'> value= (270, 76)
    filename= README（自動保存）.rtf code= b'Iloc' type= <class 'ds_store.store.ILocCodec'> value= (92, 452)
    filename= Sylpheed.app code= b'Iloc' type= <class 'ds_store.store.ILocCodec'> value= (91, 76)
    """

    if os.path.exists('.DS_Store'):
        os.remove('.DS_Store')

    with ds_store.DSStore.open('.DS_Store', 'w+') as ds:
        ds['.'][b'Iloc'] = (204, 152)
        ds['.'][b'bwsp'] = {
            'WindowBounds': '{{217, 145}, {541, 233}}',
            'ShowSidebar': False,
            'ShowStatusBar': True,
            'ShowPathbar': False,
            'ShowToolbar': False,
            'SidebarWidth': 192
        }
        ds['.'][b'icvp'] = {
            'backgroundColorBlue': 0.9819161891937256,
            'gridSpacing': 100.0,
            'textSize': 12.0,
            'backgroundColorRed': 0.699933648109436,
            'backgroundType': 1,
            'backgroundColorGreen': 0.7402167320251465,
            'gridOffsetX': 0.0,
            'gridOffsetY': 0.0,
            'showItemInfo': False,
            'viewOptionsVersion': 0,
            'arrangeBy': 'none',
            'labelOnBottom': True,
            'showIconPreview': True,
            'iconSize': 128.0
        }
        ds.insert(ds_store.DSStoreEntry('.', b'vstl', b'type', b'icnv'))
        ds['Documents'][b'Iloc'] = (448, 76)
        ds['Documents'][b'bwsp'] = {
            'WindowBounds': '{{52, 305}, {770, 405}}',
            'ShowSidebar': False,
            'ShowStatusBar': True,
            'ShowPathbar': False,
            'ShowToolbar': False,
            'SidebarWidth': 192
        }
        ds['README.rtf'][b'Iloc'] = (270, 76)
        ds['README（自動保存）.rtf'][b'Iloc'] = (92, 452)
        ds['Sylpheed.app'][b'Iloc'] = (91, 76)

        ds['Applications'][b'Iloc'] = (448, 76)

        for hidden in {'.background', '.DS_Store', '.fsevents', '.Trashes', '.VolumeIcon.icns', '.fseventsd'}:
            ds[hidden][b'Iloc'] = (92, 452)

        ds.flush()

    with ds_store.DSStore.open('.DS_Store', 'r') as ds:
        dump_info(ds)

    return 0


if __name__ == '__main__':
    sys.exit(main())
