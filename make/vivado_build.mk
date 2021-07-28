# setup job limit based on host capabilities (limit to 8)
NJOBMAX = 8
NJOBS = $(shell bash -c "echo $$((`nproc`>$(NJOBMAX) ? $(NJOBMAX) : `nproc`))")

# generic vivado build flow ----------------------
ART_DIR = build/artifacts
VIV_DIR = build/$(DESIGN)_0/$(DESIGN)-vivado
VIV_RUNDIR = $(VIV_DIR)/$(DESIGN)_0.runs
FILE_NAME = $(DESIGN)_$(DATE_STAMP)_$(GIT_BRANCH)_$(GIT_COMMIT)

default :
	@echo "No default action defined, use one of"
	@echo "  setup       create all fusesoc generated files"
	@echo "  project     create Vivado project (implies setup)"
	@echo "  build       run Vivado to build bitfile (implies project)"
	@echo "  vivado      start Vivado GUI session (implies project)"
	@echo "  artifacts   collects artifacts for gitlab-ci (after build)"
	@echo "  clean       remove all generated files"

#
# agwb: run fusesoc
#
agwb :
	fusesoc --monochrome --cores-root ../../ run --no-export --setup \
		--target agwb ::$(DESIGN)

#
# setup: run fusesoc
#
setup : $(VIV_DIR)/Makefile

$(VIV_DIR)/Makefile :
	fusesoc --monochrome --cores-root ../../ run --no-export --setup \
		--target $(DESIGN) ::$(DESIGN)
#
# project: create Vivado project
#
project : setup
	make -C $(VIV_DIR) $(DESIGN)_0.xpr

#
# reset: recreate Vivado project
#        (e.g. after core file changes)
#
reset : 
	rm -f $(VIV_DIR)/Makefile


#
# build: run vivado
#   not using fusesoc --build, calls fusesoc generarted Makefile directly
#   this allows to patch the run script
#
build : export XDG_CACHE_HOME = $(PWD)/fusesoc_cache/
build : project
	(cd $(VIV_DIR); sed -i.bak 's/launch_runs impl_1 -to_step write_bitstream$$/launch_runs impl_1 -to_step write_bitstream -jobs $(NJOBS)/' $(DESIGN)_0_run.tcl)
	make -C $(VIV_DIR) $(DESIGN)_0.bit
#
# vivado: run fusesoc and start Vivado GUI session
#
vivado : project
	make -C $(VIV_DIR) build-gui
#
# clean: remove all build dirs
#
clean :
	rm -rf build
	rm -rf config/build
	(cd ../../submodules; find -type d -name "build" | xargs rm -rf)
	(cd ../../common; find -type d -name "build" | xargs rm -rf)
	(cd ../../externals; find -type d -name "build" | xargs rm -rf)
	if [ -d "src/hls" ]; then (cd src/hls; find -type d -name "build" | xargs rm -rf); fi
#
# artifacts: collect all artifacts
#
DATE_STAMP = $(shell date "+%F")
ifneq ($(CI),)
  GIT_BRANCH = $(CI_COMMIT_REF_NAME)
  GIT_COMMIT = $(CI_COMMIT_SHORT_SHA)
else
  GIT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
  GIT_COMMIT = $(shell git describe --always --abbrev=8)
endif
#
artifacts : artifacts_manifest artifacts_bitfile artifacts_logs artifacts_ila \
	    artifacts_agwb

artifacts_manifest :
	@mkdir -p build/artifacts
	printenv | egrep -v '(KEY|TOKEN|PASSWORD|SECRET|CI_JOB_JWT)' \
	  > build/artifacts/printenv.log
	if [ -f config/build/buildinfo.txt ]; then \
	  cp config/build/buildinfo.txt build/artifacts; \
	fi

artifacts_bitfile :
	@mkdir -p build/artifacts
	if [ -f $(VIV_DIR)/$(DESIGN)_0.bit ]; then \
	  cp -p $(VIV_DIR)/$(DESIGN)_0.bit $(ART_DIR)/$(FILE_NAME).bit; \
	  gzip -f $(ART_DIR)/$(FILE_NAME).bit; \
	fi

artifacts_logs :
	@mkdir -p build/artifacts
	(cd $(VIV_DIR); find -name "*.log" -or -name "*.rpt" | \
	  grep -v "job.id.log" | \
	  tar -T - -czf $(FILE_NAME)_logs.tgz)
	mv $(VIV_DIR)/$(FILE_NAME)_logs.tgz $(ART_DIR)

artifacts_ila :
	@mkdir -p build/artifacts
	(cd $(VIV_RUNDIR); find -name "*.ltx" | \
	  tar -T - -czf $(FILE_NAME)_ila.tgz)
	mv $(VIV_RUNDIR)/$(FILE_NAME)_ila.tgz $(ART_DIR)

artifacts_agwb :
	@mkdir -p build/artifacts
	tar -czf $(ART_DIR)/$(FILE_NAME)_agwb.tgz -C config/build/agwb .

.PHONY : default
.PHONY : setup build project vivado artifacts clean
.PHONY : artifacts_manifest
.PHONY : artifacts_bitfile artifacts_logs artifacts_ila artifacts_agwb
