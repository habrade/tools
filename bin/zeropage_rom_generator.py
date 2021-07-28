#!/usr/bin/python3
#
# SPDX-License-Identifier: GPL-3.0-only
# Original author: Walter F.J. Mueller <w.f.j.mueller@gsi.de>
#

from typing import Any, Dict                                # noqa: F401

import argparse
import textwrap
import re
import sys

# ----------------------------------------------------------------------------
def eprint(sev:str, text:str) -> None:
    """Print message to stderr"""
    print("zeropage-rom-generator-{}: {}".format(sev, text), file=sys.stderr)
    if sev == "E":
        sys.exit(1)

# ----------------------------------------------------------------------------
def fprint(ofile:Any, text:str) -> None:
    """Print to ofile"""
    print(text, file=ofile)

# ----------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a VHDL ROM from key=values pairs text file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
        Creates a VHDL package with a 32 bit word ROM array filled with text
        data received from stdin or an input file. The package name can be
        customized with the -p option.

        The input data must
        - be printable ASCII (>=32 and <128)
        - be in the format of one key=value pair per line
        - have unique key names contain only \w characters [0-9a-zA-Z_]

        Empty input lines or lines starting with '#' are ignored.

        The ROM contains the text packed into 32 bit words in little endian
        byte order. The key=value pairs are joined with a \n separator byte,
        the last key=value pair ends with a \0 byte. This ensures simple and
        unambiguous unpacking of the ROM data.

        The ROM size can be fixed or automatically determined.
        When the -w option is used, a ROM with this address width is created.
        Without -w option the ROM is auto-sized, with a maximum size given by
        the -m option.

        The generator can be used as a filter, reading from stdin and writing
        to stdout. Alternatively, an input and output file can be specified.

        Typical use is in a pipeline, one program provides key=value pairs,
        one per line, as data, and this generator converts this into VHDL.
        """))

    parser.add_argument("filename", nargs="?")
    parser.add_argument("-p", type=str, default="buildinfo",
                        help="package name component, default is 'buildinfo'")
    parser.add_argument("-m", type=int,
                        help="maximal ROM address width, must be in 4 to 12")
    parser.add_argument("-w", type=int,
                        help="fixed ROM address width, must be in 4 to 12")
    parser.add_argument("-o", type=str,
                        help="output file name")

    args = parser.parse_args()

    # check -s, -m and -w options
    maxwidth = 8
    fixwidth = 0

    if args.m:
        maxwidth = args.m
        if maxwidth < 4 or maxwidth > 12:
            eprint("E","-m must be in 4 to 12, seen {}".format(args.m))

    if args.w:
        fixwidth = args.w
        maxwidth = fixwidth
        if args.m:
            eprint("E","-w can't be combined with -m")

        if fixwidth < 4 or fixwidth > 10:
            eprint("E","-w must be in 4 to 10, seen {}".format(args.w))

    # open input and output files unless stdin and stdout used
    ifile = sys.stdin
    ofile = sys.stdout
    try:
        if args.filename:
            ifile = open(args.filename, mode='rt')
        if args.o:
            ofile = open(args.o, mode='wt')
    except Exception as err:
        eprint("E","{}".format(err))

    # read input lines, check non-ASCII chars and key uniqueness
    keymap = {}                 # type: Dict[str, str]
    for line in ifile:
        line = line.rstrip("\n")        # drop trailing \n
        line = line.strip()             # drop leading/traing whitespace
        if len(line) == 0 or line[0] == "#":   # skip empty or comment lines
            continue
        if not all(ord(c) >= 32 and ord(c) < 128 for c in line):
            eprint("E","non-ASCII character in '{}'".format(line))
        match = re.search(r"^(\w+)=(.*)$", line)
        if match is None:
            eprint("E","bad key-value pair in '{}'".format(line))
        key = match.group(1)
        val = match.group(2)
        if key in keymap:
            eprint("E","duplicate key in '{}'".format(line))
        keymap[key] = val

    # now build ROM data
    romchars = "\n".join([key+"="+keymap[key] for key in sorted(keymap.keys())])
    rombytes = romchars.encode() + b'\x00'

    # determine minimal address width and check size
    ubyte = len(rombytes)       # used bytes (incl trailing \0 !)
    uword = ((ubyte-1)>>2)+1    # used words
    wrest = uword-1
    curwidth = 0
    while wrest > 0:
        curwidth += 1
        wrest >>= 1
        if wrest == 0:
            break

    if curwidth > maxwidth:
        eprint("E","data size {} larger than ROM size {}"
               .format(ubyte, 4<<maxwidth))

    # now fix ROM size
    if fixwidth == 0:           # if auto-sizing
        fixwidth = max(4,curwidth)
    nbyte = 4<<fixwidth
    nword = nbyte>>2
    # and zero-padded up to written ROM size
    rombytes += b'\x00' * (nbyte-len(rombytes))

    # and finally write out the VHDL package
    fprint(ofile, "-- generated by zeropage_rom_generator")
    fprint(ofile, "--   called with: {}".format(" ".join(sys.argv[1:])))
    fprint(ofile, "--   data size: {} bytes, {} words".format(ubyte, uword))
    fprint(ofile, "--   ROM address width: {}".format(fixwidth))
    fprint(ofile, "-- for data (with sorted keys):")
    for ind,key in enumerate(sorted(keymap.keys())):
        fprint(ofile, "--   {:3d}: {}={}".format(ind,key,keymap[key]))
    fprint(ofile, "")
    fprint(ofile, "library ieee;")
    fprint(ofile, "use ieee.std_logic_1164.all;")
    fprint(ofile, "use ieee.numeric_std.all;")
    fprint(ofile, "")

    fprint(ofile, "package zeropage_{}_pkg is".format(args.p))
    fprint(ofile, "  type {}_rom_array is array (integer range <>)"
           .format(args.p))
    fprint(ofile, "       of std_logic_vector(31 downto 0);")
    fprint(ofile, "")
    fprint(ofile, "  constant c_{}_addr_width : integer := {};"
           .format(args.p, fixwidth))
    fprint(ofile, "  constant {0}_rom : {0}_rom_array(0 to {1}) := ("
           .format(args.p, nword-1))

    for i in range(nword):
        chunk = rombytes[4*i:4*(i+1)]                       # get 4 bytes
        data = int.from_bytes(chunk, byteorder="little")    # to int
        text = "" if chunk == b"\x00\x00\x00\x00" else str(chunk)
        sep = ", " if i < nword-1 else ");"
        fprint(ofile, "    x\"{:08x}\"{}    -- {:3d}  {}"
               .format(data,sep,i,text))

    fprint(ofile, "")
    fprint(ofile, "end zeropage_{}_pkg;".format(args.p))
    return

# ----------------------------------------------------------------------------
if __name__ == "__main__":
    main()
