ROOT := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOT_DIR := $(dir $(ROOT))..
# PWD := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
# CORE_NAME=$(PWD)
# BUILD_DIR=build


ifndef INC_DIR
	INC_DIR = .
endif



SNAME=script.tcl
SOURCES=$(wildcard src/*.cpp)
SOURCES+=$(wildcard src/*.h)
TB:=$(wildcard src/tb/*.*)
PART ?= xcku115-flvf1924-2-e
test:="-trace_level"

## Clocks added here !(in a new variable) also have to be added in the tcl script generation
CL0 := create_clock -period 6.25 -name default


all: impl

build-dir: $(BUILD_DIR)
$(BUILD_DIR): 
	mkdir -p $(BUILD_DIR)

ip-dir: $(BUILD_DIR) $(BUILD_DIR)/$(IP_DIR)
$(BUILD_DIR)/$(IP_DIR):
		@test -d "$(BUILD_DIR)/$(IP_DIR)" || mkdir -p "$(BUILD_DIR)/$(IP_DIR)"

sim: tcl_script
	cd $(BUILD_DIR);vivado_hls script.tcl -tclargs csim_design
cosim: tcl_script synth
	cd $(BUILD_DIR);vivado_hls script.tcl -tclargs cosim_design

synth: $(BUILD_DIR) $(BUILD_DIR)/$(SNAME) $(BUILD_DIR)/$(CORE_NAME)/solution1/syn/
$(BUILD_DIR)/$(CORE_NAME)/solution1/syn/: src/*.cpp src/*.h*
	cd $(BUILD_DIR);vivado_hls script.tcl -tclargs csynth_design


impl: $(BUILD_DIR) $(BUILD_DIR)/$(IP_DIR) $(BUILD_DIR)/$(CORE_NAME)/solution1/impl/
$(BUILD_DIR)/$(CORE_NAME)/solution1/impl/: synth
	cd $(BUILD_DIR);vivado_hls script.tcl -tclargs export_design
	# @test -e "wrapper_gen.py" && python wrapper_gen.py $(LINKS) && cp $(CORE_NAME)_wrapper.vhd $(BUILD_DIR)/$(IP_DIR) || break
	@echo "\nCopying generated build files into build/ip"
	@cp $@/vhdl/*.vhd $(BUILD_DIR)/
	# @cp $@/constraints/*.xdc $(BUILD_DIR)/ #for ooc I guess.
	@python $(ROOT_DIR)/bin/hls_core_gen.py $(DESIGN) $(CORE_NAME)


tcl_script: $(BUILD_DIR) $(BUILD_DIR)/$(SNAME) 
$(BUILD_DIR)/$(SNAME): $(SOURCES) $(TB) Makefile
	$(file > 	$(BUILD_DIR)/$(SNAME), ### Auto Generated ###)
	$(file >> $(BUILD_DIR)/$(SNAME), open_project $(CORE_NAME))
	$(file >> $(BUILD_DIR)/$(SNAME), set_top $(CORE_NAME))
	$(foreach O, $(SOURCES), $(file >> $(BUILD_DIR)/$(SNAME), add_files ../$O -cflags "-I$(INC_DIR)"))
	$(foreach O, $(TB), $(file >> $(BUILD_DIR)/$(SNAME), add_files -tb ../$O -cflags "-I$(SRC_DIR) -I$(INC_DIR)"))
	$(file >> $(BUILD_DIR)/$(SNAME), open_solution "solution1")
	$(file >> $(BUILD_DIR)/$(SNAME), set_part $(PART))
	$(file >> $(BUILD_DIR)/$(SNAME), $(CL0))
	$(file >> $(BUILD_DIR)/$(SNAME), if {[lindex $$argv 0]=="cosim_design"} {)
	$(file >> $(BUILD_DIR)/$(SNAME), 		cosim_design -trace_level all)
	$(file >> $(BUILD_DIR)/$(SNAME), } else { )
	$(file >> $(BUILD_DIR)/$(SNAME),   [lindex $$argv 0] )
	$(file >> $(BUILD_DIR)/$(SNAME), } )

clean:
	rm -rf $(BUILD_DIR)

# report:
# 	python ../report.py 1 $(CORE_NAME)

.PHONY: sim clean tcl_script
