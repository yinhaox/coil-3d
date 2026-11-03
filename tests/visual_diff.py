#!/usr/bin/env python3
"""Compare two PNG files pixel by pixel, using only the Python standard library.

The tool is meant for screenshot regression checks: capture a candidate with the
studio capture command and compare it against a committed baseline. It prints the
differing pixel count and ratio, then exits 0 when the ratio is within the given
tolerance.

Usage:
    python tests/visual_diff.py \
        --baseline tests/baselines/arena-initial.png \
        --candidate production/qa/evidence/<story>/arena-initial.png \
        --tolerance 0.02

Exit codes:
    0   the difference ratio is at or below --tolerance
    1   the difference ratio is above --tolerance, or the image sizes differ
    2   a file is missing, unreadable, or not a supported non-interlaced 8-bit PNG
"""

from __future__ import annotations

import argparse
import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS_BY_COLOR_TYPE = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
BYTES_PER_CHANNEL = 1


class PngError(Exception):
    """A file that is not a PNG this tool can compare."""


def _read_chunks(data: bytes):
    """Yield (chunk_type, payload) for every chunk up to and including IEND."""
    if not data.startswith(PNG_SIGNATURE):
        raise PngError("not a PNG file (signature mismatch)")
    offset = len(PNG_SIGNATURE)
    while offset + 8 <= len(data):
        length, chunk_type = struct.unpack(">I4s", data[offset : offset + 8])
        offset += 8
        payload = data[offset : offset + length]
        if len(payload) != length:
            raise PngError("truncated PNG chunk %r" % chunk_type)
        offset += length
        if offset + 4 > len(data):
            raise PngError("truncated PNG chunk CRC")
        crc = struct.unpack(">I", data[offset : offset + 4])[0]
        offset += 4
        expected = zlib.crc32(chunk_type)
        expected = zlib.crc32(payload, expected) & 0xFFFFFFFF
        if crc != expected:
            raise PngError("PNG chunk %r has a bad CRC" % chunk_type)
        yield chunk_type, payload
        if chunk_type == b"IEND":
            return
    raise PngError("missing IEND chunk")


def _unfilter(raw: bytes, width: int, height: int, bytes_per_pixel: int) -> bytearray:
    """Undo the PNG scanline filters, returning the raw pixel bytes."""
    stride = width * bytes_per_pixel
    expected = (stride + 1) * height
    if len(raw) < expected:
        raise PngError("image data is shorter than the header describes")
    output = bytearray(stride * height)
    previous = bytearray(stride)
    offset = 0
    for row in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset : offset + stride])
        offset += stride
        if filter_type == 0:
            pass
        elif filter_type == 1:
            for index in range(bytes_per_pixel, stride):
                line[index] = (line[index] + line[index - bytes_per_pixel]) & 0xFF
        elif filter_type == 2:
            for index in range(stride):
                line[index] = (line[index] + previous[index]) & 0xFF
        elif filter_type == 3:
            for index in range(stride):
                left = line[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                line[index] = (line[index] + ((left + previous[index]) >> 1)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = line[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                up = previous[index]
                up_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
                line[index] = (line[index] + _paeth(left, up, up_left)) & 0xFF
        else:
            raise PngError("unknown PNG filter type %d" % filter_type)
        output[row * stride : (row + 1) * stride] = line
        previous = line
    return output


def _paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    distance_left = abs(estimate - left)
    distance_up = abs(estimate - up)
    distance_up_left = abs(estimate - up_left)
    if distance_left <= distance_up and distance_left <= distance_up_left:
        return left
    if distance_up <= distance_up_left:
        return up
    return up_left


class PngImage:
    """An 8-bit PNG decoded to RGBA bytes, one 4-byte pixel per entry."""

    def __init__(self, width: int, height: int, pixels: bytearray) -> None:
        self.width = width
        self.height = height
        self.pixels = pixels

    def pixel_count(self) -> int:
        return self.width * self.height


def read_png(path: str) -> PngImage:
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError as exc:
        raise PngError("cannot read %s: %s" % (path, exc)) from exc

    width = height = bit_depth = color_type = interlace = None
    palette = b""
    transparency = b""
    image_data = bytearray()
    for chunk_type, payload in _read_chunks(data):
        if chunk_type == b"IHDR":
            (width, height, bit_depth, color_type, compression, filter_method, interlace) = (
                struct.unpack(">IIBBBBB", payload)
            )
            if bit_depth != 8:
                raise PngError("unsupported bit depth %d; this tool compares 8-bit PNGs" % bit_depth)
            if compression != 0 or filter_method != 0:
                raise PngError("unsupported PNG compression or filter method")
            if interlace != 0:
                raise PngError("interlaced PNGs are not supported")
            if color_type not in CHANNELS_BY_COLOR_TYPE:
                raise PngError("unsupported PNG color type %d" % color_type)
        elif chunk_type == b"PLTE":
            palette = payload
        elif chunk_type == b"tRNS":
            transparency = payload
        elif chunk_type == b"IDAT":
            image_data.extend(payload)
    if width is None or width == 0 or height == 0:
        raise PngError("missing or empty IHDR chunk")
    if not image_data:
        raise PngError("no image data")

    channels = CHANNELS_BY_COLOR_TYPE[color_type]
    try:
        raw = zlib.decompress(bytes(image_data))
    except zlib.error as exc:
        raise PngError("cannot decompress image data: %s" % exc) from exc
    scanlines = _unfilter(raw, width, height, channels * BYTES_PER_CHANNEL)
    pixels = _to_rgba(scanlines, width, height, color_type, channels, palette, transparency)
    return PngImage(width, height, pixels)


def _to_rgba(
    scanlines: bytearray,
    width: int,
    height: int,
    color_type: int,
    channels: int,
    palette: bytes,
    transparency: bytes,
) -> bytearray:
    """Expand any supported 8-bit PNG color type to one RGBA pixel per entry."""
    pixels = bytearray(width * height * 4)
    for index in range(width * height):
        source = index * channels
        target = index * 4
        if color_type == 0:
            gray = scanlines[source]
            pixels[target : target + 4] = bytes((gray, gray, gray, 255))
        elif color_type == 2:
            pixels[target : target + 3] = scanlines[source : source + 3]
            pixels[target + 3] = 255
        elif color_type == 3:
            palette_index = scanlines[source]
            palette_offset = palette_index * 3
            if palette_offset + 3 > len(palette):
                raise PngError("palette index %d is outside PLTE" % palette_index)
            pixels[target : target + 3] = palette[palette_offset : palette_offset + 3]
            alpha = transparency[palette_index] if palette_index < len(transparency) else 255
            pixels[target + 3] = alpha
        elif color_type == 4:
            gray = scanlines[source]
            pixels[target : target + 4] = bytes((gray, gray, gray, scanlines[source + 1]))
        else:  # color_type == 6
            pixels[target : target + 4] = scanlines[source : source + 4]
    return pixels


def compare(baseline: PngImage, candidate: PngImage) -> tuple[int, float]:
    """Return (differing pixel count, ratio over the total pixel count)."""
    if baseline.width != candidate.width or baseline.height != candidate.height:
        raise PngError(
            "image sizes differ: baseline %dx%d, candidate %dx%d"
            % (baseline.width, baseline.height, candidate.width, candidate.height)
        )
    total = baseline.pixel_count()
    first = baseline.pixels
    second = candidate.pixels
    if first == second:
        return 0, 0.0
    differing = 0
    for offset in range(0, len(first), 4):
        if first[offset : offset + 4] != second[offset : offset + 4]:
            differing += 1
    return differing, differing / total


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare two PNG screenshots and fail when they differ too much.",
    )
    parser.add_argument("--baseline", required=True, help="reference PNG committed with the tests")
    parser.add_argument("--candidate", required=True, help="newly captured PNG to compare")
    parser.add_argument(
        "--tolerance",
        required=True,
        type=float,
        help="largest allowed difference ratio, for example 0.02 (2%% of the pixels)",
    )
    args = parser.parse_args(argv)
    if not 0.0 <= args.tolerance <= 1.0:
        parser.error("--tolerance must be between 0.0 and 1.0")
    return args


def main(argv=None) -> int:
    args = parse_args(argv)
    try:
        baseline = read_png(args.baseline)
        candidate = read_png(args.candidate)
        differing, ratio = compare(baseline, candidate)
    except PngError as exc:
        print("visual_diff: error: %s" % exc, file=sys.stderr)
        return 2

    print("baseline: %s (%dx%d)" % (args.baseline, baseline.width, baseline.height))
    print("candidate: %s (%dx%d)" % (args.candidate, candidate.width, candidate.height))
    print("total pixels: %d" % baseline.pixel_count())
    print("differing pixels: %d" % differing)
    print("difference ratio: %.6f" % ratio)
    print("tolerance: %.6f" % args.tolerance)
    if ratio > args.tolerance:
        print("result: FAIL (exit 1)")
        return 1
    print("result: PASS (exit 0)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
