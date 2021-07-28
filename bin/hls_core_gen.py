"""
Generates a fusesoc core for HLS modules
"""
import sys
import glob
import os
PROJECT_NAME = sys.argv[1]
CORE_NAME = sys.argv[2] # get from sys_args
# PROJECT_NAME = "1"
# CORE_NAME = "2" # get from sys_args


header=\
"""\
CAPI=2:

name: cri:{0}:{1}
""".format(PROJECT_NAME,CORE_NAME)

path = "build/"

# print(files)
vhdfiles  = glob.glob(path+"*.vhd")
print(vhdfiles)
filestring = ""
for vhd in vhdfiles:
    vhd = os.path.basename(vhd)
    filestring += "{:>12}- {}\n".format("",vhd)


filesets=\
"""\
filesets:
    rtl:
        file_type: vhdlSource-2008
        files:
{}
""".format(filestring)
print(filesets)

targets=\
"""\
targets:
    default:
        filesets:
           - rtl
"""



core = header + filesets + targets

f = open("build/{}.core".format(CORE_NAME), "w+")
f.write(core)
f.close()
