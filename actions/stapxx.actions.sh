#!/usr/bin/bash

function stapxx-find-dependency() {
    local cname=$1
    local nginx_master=$(docker-get-pid-by-container-name-or-uuid $cname)
    local pid=$(ps-list-child $nginx_master | tail -n 1 | awk '{print $2}')
    local files=$(sudo cat /proc/$pid/maps| awk '{print $6}' |grep \s |grep -v 'delete' |grep '^/.*'| sort | uniq)
    local base=/proc/$pid/root
    local out=""
    while read -r sopath
	do
        # echo "ss $sopath"
        procsopath="$base$sopath"
        sudo test -f $procsopath
        local has_proc=$?
        if [[ "$has_proc" == "0" ]];then
            out="$out\n$procsopath"
            continue
        fi
        sudo test -f $sopath
        local has_raw=$?
        # echo "$has_raw"
        if [[ "$has_raw" == "0" ]];then
            out="$out\n$sopath"
            # echo $sopath "raw"
            continue
        fi
    done <<<$(echo $files) 
    echo $out | grep \s
}

function shark-docker() (
    # set -x
    local cname=$1 #nginx container id, the fd 1 process must be nginx master.
    local sxx="$2"
    sudo rm -rf ./stapxx-* || true
    local time=120
    local base=$(docker inspect $cname  | jq -r '.[0].GraphDriver.Data.MergedDir')
    local nginx_master=$(docker-get-pid-by-container-name-or-uuid $cname)
    local pid=$(ps-list-child $nginx_master | tail -n 1 | awk '{print $2}')
    local id=${3:=$RANDOM}
    echo $base
    echo $pid
    echo $id
    # local sxx="./wg-samples/docker/fnname.sxx"
    local base=./stap-raw/$id
    mkdir -p $base || true
    echo "trans"
    ./stap++ -dump-src  -dump-src-out=$base/nginx.stap $sxx  --arg time=$time
    rm  $base/run.sh
    echo '#!/bin/bash' >> $base/run.sh
    echo "sudo wg-stap $base/nginx.stap \\" >> $base/run.sh
    echo " -s 160 \\" >> $base/run.sh
    while read -r dpath;do
        # echo " -d $dpath \\" >> ./stap-raw/run.sh
    done <<<$(stapxx-find-dependency $cname)

    echo " -v -D MAXMAPENTRIES=2000  -D MAXSKIPPED=200000  -DDEBUG_TASK_FINDER=9 -DDEBUG_UPROBES=9 -DDEBUG_TASK_FINDER_VMA=9 \\" >>$base/run.sh
    echo " --sysroot=/proc/$pid/root  -x $pid" >>$base/run.sh
    cat $base/run.sh
    chmod a+x $base/run.sh

    local exec_path=$(stapxx-find-dependency $cname |grep nginx)
    local lua_path=$(stapxx-find-dependency $cname |grep luajit)
    echo "exec_path: $exec_path"
    echo "lua_path $lua_path"
    sed -i "s|$\^exec_path|$exec_path|g" $base/nginx.stap 
    sed -i "s|$\^libluajit_path|$lua_path|g" $base/nginx.stap 
    mkdir $base
    $base/run.sh 2>&1 | tee $base/stap.log
)

function shark-docker-flamegraph() (
    local cname=$1 #nginx container id, the fd 1 process must be nginx master.
    local sxx="$2"
    local name=${3:=$(date +%s%N)}
    local nginx_master=$(docker-get-pid-by-container-name-or-uuid $cname)
    local pid=$(ps-list-child $nginx_master | tail -n 1 | awk '{print $2}')
    echo $cname $sxx $name $pid
    shark-docker $cname $sxx $name
    set -x
    stapxx-svg ./stap-raw/$name/stap.log  ./stap-raw/$name/out /proc/$pid/root
    set +x
    ls ./stap-raw/$name/out
    # firefox  ./stap-raw/$name/out/out/stacks.svg
)

function stapxx-svg () (
    local log=$1
    local out=$2
    local base=$3
    rm -rf $out
    mkdir -p $out
    cat $log |grep -a 'report:' |sed 's/report://g' > $out/stacks.bt
    # if [ -n "$MERGE_RAW_PROBEFN" ] ; then
        sed -i 's/|pf-s|0x.*|pf-e|/|pf-s|unresolved|pf-e|/g' $out/stacks.bt
    # fi

    # if [ -n "$IGNORE_RAW_PROBEFN" ] ; then
        #  sed -i '/|pf-s|unresolved|pf-e||lb||vm_c|err:none-frame/d' $out/stacks.bt
        #  sed -i '/|pf-s|unresolved|pf-e||lb|err:vm_xstate_interp/d' $out/stacks.bt

    # fi

    sed -i 's/|lb|/\n/g' $out/stacks.bt
    sed -i 's/|stack-fs|/\n/g' $out/stacks.bt
    sed -i 's/|stack-fe|//g' $out/stacks.bt
    sed -i 's/|fe|/\n/g' $out/stacks.bt
    sed -i 's/|vm_c|//g' $out/stacks.bt
    sed -i 's/|trace-f|//g' $out/stacks.bt
    sed -i 's/|stack|//g' $out/stacks.bt
    sed -i 's/|lt|/\n\t/g' $out/stacks.bt

    sed -i 's/|pf-s|//g' $out/stacks.bt
    sed -i 's/|pf-e|//g' $out/stacks.bt
    sed -i "s|@/|$base|g" $out/stacks.bt
    # TODO
    ./actions/fix-lua-bt $out/stacks.bt > $out/stacks.fix.bt
    ./actions/stackcollapse-stap.pl  $out/stacks.fix.bt >  $out/stacks.cbt
    sed -i "s|$base||g" $out/stacks.cbt
    ./actions/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              $out/stacks.cbt > $out/stacks.svg
)

function shark-tmux-init () (
    tmux kill-session -t shark
    tmuxp load -d -y ./shark/shark.tmuxp.yaml
) 