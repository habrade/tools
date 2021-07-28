# SPDX-License-Identifier: GPL-3.0-only
# (C) Copyright 2021 GSI Helmholtzzentrum für Schwerionenforschung
# Original author: Walter F.J. Mueller <w.f.j.mueller@gsi.de>

#
all : flake8 mypy
#
flake8 :
	python3 -m flake8 --config=../../.flake8
#
mypy :
	export MYPYPATH=;\
	mypy --config=../../.mypy.ini *.py
