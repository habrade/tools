#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-only
# Original author: Walter F.J. Mueller <w.f.j.mueller@gsi.de>

while [[ $# -gt 0 && $1 == -* ]]; do
    case $1 in
        -C)
            if [[ -z $2 ]] || [[ ! -d $2 ]]; then
                echo "create_buildinfo-E: bad -C $2 option"
                exit 1
            fi
            shift
            cd $1
            shift
            ;;
        -h|--help)
            echo "usage: create_buildinfo [options]"
            echo -e "  Options"
            echo -e "    -C path  will cd to this path (usually relative)"
            exit
            ;;
        *)
            echo "create_buildinfo-E: invalid option, see -h"
            exit 1
    esac
done

set -e
set -o pipefail

#
# get pertinent data from environment and git
#
bdate=$(date '+%F %T')
bpath=$(git rev-parse --show-prefix)
#rdate=$(git show -s --format=%cd --date="format:%F %T")
rdate=$(date -d @$(git log -n1 --format="%at") +%F\ %T)
#
# when in GitLab CI use some data from CI_ environment
#
if [[ "$CI" == "true" ]]; then
    bci="true"
    bhost=$CI_RUNNER_DESCRIPTION
    buser=$GITLAB_USER_LOGIN
    rcommit=$CI_COMMIT_SHA
    rtag=$CI_COMMIT_SHORT_SHA
    rpath=$CI_PROJECT_PATH
    if [[ -n "$CI_MERGE_REQUEST_IID" ]]; then
        rbranch=$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME
    else
        rbranch=$CI_COMMIT_BRANCH
    fi
#
# otherwise obtain it from OS or git
#
else
    bci="false"
    bhost=$(hostname)
    buser=$USER
    rbranch=$(git rev-parse --abbrev-ref HEAD)
    rcommit=$(git show -s --format=%H)
    #    rtag=$(git describe --always --tags --dirty --broken --abbrev=8 --long)
    rtag=$(git describe --always --tags --dirty --abbrev=8 --long)
    rpath=$(git config --get remote.origin.url)
    if [[ "$rpath" == http* ]]; then
        rpath=${rpath#*//}              # drop proto:// prefix
        rpath=${rpath#*/}               # drop server part
    else
        rpath=${rpath#*:}               # drop node prefix
        rpath=${rpath%*.git}            # drop .git suffix
    fi
fi

echo "bci=$bci"             #  build in CI/CD ?
echo "bdate=$bdate"         #  build run timestamp
echo "bhost=$bhost"         #  build host (CI: runner host)
echo "buser=$buser"         #  build user (CI: user of commit)
echo "bpath=$bpath"         #  build path
echo "rbranch=$rbranch"     #  repo branch
echo "rcommit=$rcommit"     #  repo commit hash
echo "rtag=$rtag"           #  repo tag and commit info
echo "rdate=$rdate"         #  repo commit timestamp
echo "rpath=$rpath"         #  repo path

#
# when in GitLab CI provide additional information
#
if [[ "$CI" == "true" ]]; then
    echo "bjob=$CI_JOB_ID"
    #
    # when in merge request add merge information
    #
    if [[ -n "$CI_MERGE_REQUEST_IID" ]]; then
        echo "rmiid=$CI_MERGE_REQUEST_IID"
        echo "rmtarget=$CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
        echo "rmpath=$CI_MERGE_REQUEST_PROJECT_PATH"
    fi
fi
