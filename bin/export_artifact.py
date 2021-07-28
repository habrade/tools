#!/usr/bin/python3
#
# SPDX-License-Identifier: GPL-3.0-only
# Original author: Walter F.J. Mueller <w.f.j.mueller@gsi.de>
#

import argparse
import textwrap
from pathlib import Path
import sys
import os
import re
import subprocess
import tempfile

# ----------------------------------------------------------------------------
def eprint(sev:str, text:str) -> None:
    """Print message to stderr"""
    print("export_artifacts-{}: {}".format(sev, text), file=sys.stderr)
    if sev == "E":
        sys.exit(1)

# ----------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create tarball with exported artifacts",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
        This script must be started in a project/<design> directory or started
        with a -C option pointing to such a directory and will create a tarball
        in the build directory with all artifacts
        """))
    parser.add_argument("-C", type=str, help="change directory to 'C'")
    args = parser.parse_args()

    # if -C given change directory
    if args.C:
        if not Path(args.C).is_dir():
            eprint("E", "{} given with -C not found".format(args.C))
        os.chdir(args.C)

    # check whether in proper context
    cwd = Path.cwd()
    if not (cwd / ".." / ".." / "projects").is_dir():
        eprint("E", "not in a projects directory")
    artdir = cwd / "build" / "artifacts"
    if not artdir.is_dir():
        eprint("E", "build/artifacts not found")
    if not (artdir / "buildinfo.txt").is_file():
        eprint("E", "build/artifacts/buildinfo.txt not found")
    logstgz = list(artdir.glob("*_logs.tgz"))
    if len(logstgz) == 0:
        eprint("E", "build/artifacts/*_logs.tgz not found")
    # determined buildname
    bname = re.sub(r"_logs.tgz$", "", str(logstgz[0].name))
    with open((artdir / "buildinfo.txt")) as file:
        for line in file:
            if re.search(r"^rtag=.*-dirty", line):
                bname += "-dirty"
    # now build the proper directory structure in a tempdir
    design = cwd.name
    with tempfile.TemporaryDirectory() as tmpdir:
        tmppath = Path(tmpdir)
        designpath = tmppath / "projects" / design
        designpath.mkdir(parents=True)
        (designpath / "artifacts").symlink_to(artdir)
        tarname = "build/{}.tgz".format(bname)
        subprocess.run(["tar", "--dereference", "-czf", tarname,
                        "-C", str(tmppath), "."], check=True)
    # finally print tgz name
    print(tarname)
    return

# ----------------------------------------------------------------------------
if __name__ == "__main__":
    main()
