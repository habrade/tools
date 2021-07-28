#!/usr/bin/bash
#
# Based on https://gist.github.com/pkuczynski/8665367

set -e
set -o pipefail

declare -A variable_array=()

parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
	-e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
	    awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}

echo Generating zeropage ROM
echo -----------------------
parse_yaml $1
eval $(parse_yaml $1)

buildpath=$(pwd)
mkdir -p $files_root/build/

rm -f $files_root/build/buildinfo.txt
echo "# data from create_buildinfo.sh" > $files_root/build/buildinfo.txt
$files_root/../../../tools/bin/create_buildinfo.sh -C $files_root/.. \
      >> $files_root/build/buildinfo.txt

if [ -r $files_root/DesignInfo.txt ]; then
    echo "# data from DesignInfo.txt" >> $files_root/build/buildinfo.txt
    cat $files_root/DesignInfo.txt >> $files_root/build/buildinfo.txt
fi

echo "BuildInfo, also under config/build/buildinfo.txt --------------------"
cat $files_root/build/buildinfo.txt
echo "---------------------------------------------------------------------"

$files_root/../../../tools/bin/zeropage_rom_generator.py \
    -m 8 \
    < $files_root/build/buildinfo.txt \
    > $files_root/build/zeropage_rom_pkg.vhd

echo "CAPI=2:
filesets:
  rtl:
    file_type: vhdlSource-93
    files: 
    - $files_root/build/zeropage_rom_pkg.vhd
name: $vlnv
targets:
  default:
    filesets:
    - rtl" > $buildpath/zeropage_rom_pkg.core
