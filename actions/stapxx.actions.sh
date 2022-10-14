#!/usr/bin/bash

# bash -x -c '. ./actions/stapxx.actions.sh;stapxx-run'
function stapxx-run() (
    local pid=$1
    sudo rm -rf ./stapxx-*
    local sxx="./wg-samples/j-stap-1-luajit-backtrace-stack.sxx"
    local time=120
    local flag=" -v -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000  -x $pid  --arg time=$time"
    rm -rf $out
    mkdir -p $out
    sudo ./stap++ $sxx  $flag |tee $out/stap.log
    sudo chmod a+r ./stapxx-* 
    sudo chmod -R 755 $(ls |grep stapxx-)
    IGNORE_RAW_PROBEFN=true
    stapxx-svg $out/stap.log
    firefox $out/stacks.svg &!
)

function stapxx-find-dpath() {
    local dpaths=$(cat $1)
    local base=$2
    local out=""
    while  read -d "|" -r sopath
	do
        sudo test -f $sopath
        local has_raw=$?
        # echo "$has_raw"
        if [[ "$has_raw" == "0" ]];then
            out="$out -d $sopath"
            # echo $sopath "raw"
            continue
        fi
        sopath="$base$sopath"
        sudo test -f $sopath
        local has_proc=$?
        if [[ "$has_proc" == "0" ]];then
            out="$out -d $sopath"
            continue
        fi
    done <<<$(echo $dpaths) 
    echo $out
}

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

function stapxx-run-docker-nginx() (
    # set -x
    local cname=$1 #nginx container id, the fd 1 process must be nginx master.
    sudo rm -rf ./stapxx-* || true
    local time=120
    local base=$(docker inspect $cname  | jq -r '.[0].GraphDriver.Data.MergedDir')
    local nginx_master=$(docker-get-pid-by-container-name-or-uuid $cname)
    local pid=$(ps-list-child $nginx_master | tail -n 1 | awk '{print $2}')
    echo $base
    echo $pid
    local sxx="./wg-samples/docker/j-stap-1-luajit-backtrace-stack.sxx"
    local sxx="./wg-samples/docker/2-get_l_m_vmstate.sxx"
    local sxx="./wg-samples/docker/j-stap-1-luajit-backtrace-stack.sxx"
    sudo rm -rf $out
    mkdir -p $out

    sudo rm -rf ./stap-raw
    mkdir -p ./stap-raw
    ./stap++ -dump-src -base=/proc/$pid/root -dump-src-out=./stap-raw/nginx.stap $sxx --sample-pid $pid -exec=/proc/$pid/root/openresty-wg/target/nginx/sbin/nginx --arg time=$time
    echo '#!/bin/bash' >> ./stap-raw/run.sh
    echo "sudo wg-stap ./stap-raw/nginx.stap \\" >> ./stap-raw/run.sh
    echo " -s 160 \\" >> ./stap-raw/run.sh
    while read -r dpath;do
        echo " -d $dpath \\" >> ./stap-raw/run.sh
    done <<<$(stapxx-find-dependency $cname)
    echo " -v -D MAXMAPENTRIES=2000000  -D MAXSKIPPED=200000  -DDEBUG_TASK_FINDER=9 -DDEBUG_UPROBES=9 -DDEBUG_TASK_FINDER_VMA=9 \\" >>./stap-raw/run.sh
    echo " --sysroot=/proc/$pid/root  -x $pid" >>./stap-raw/run.sh
    cat ./stap-raw/run.sh
    chmod a+x ./stap-raw/run.sh

    local exec_path=$(stapxx-find-dependency $cname |grep nginx)
    local lua_path=$(stapxx-find-dependency $cname |grep luajit)
    echo "exec_path: $exec_path"
    echo "lua_path $lua_path"
    sed -i "s|$\^exec_path|$exec_path|g" ./stap-raw/nginx.stap 
    sed -i "s|$\^libluajit_path|$lua_path|g" ./stap-raw/nginx.stap 
    ./stap-raw/run.sh 2>&1 | tee ./stap-raw/stap.log
    mkdir -p ./stap-raw/out
    stapxx-svg ./stap-raw/stap.log  ./stap-raw/out
    ls ./stap-raw/out
    # firefox  ./stap-raw/out/stacks.svg
)

function stapxx-svg () (
    local log=$1
    local out=$2
    cat $log |grep -a 'report:' |sed 's/report://g' > $out/stacks.bt
    sed -i 's/|lb|/\n/g' $out/stacks.bt
    sed -i 's/|stack-fs|/\n/g' $out/stacks.bt
    sed -i 's/|stack-fe|//g' $out/stacks.bt
    sed -i 's/|fe|/\n/g' $out/stacks.bt
    sed -i 's/|vm_c|//g' $out/stacks.bt
    sed -i 's/|trace-f|//g' $out/stacks.bt
    sed -i 's/|stack|//g' $out/stacks.bt
    sed -i 's/|lt|/\n\t/g' $out/stacks.bt

    if [ -n "$IGNORE_RAW_PROBEFN" ] ; then
        sed -i 's/|pf-s|0x.*|pf-e|/|pf-s|unresolved|pf-e|/g' $out/stacks.bt
    fi
    sed -i 's/|pf-s|//g' $out/stacks.bt
    sed -i 's/|pf-e|//g' $out/stacks.bt
    # TODO
    sed -i 's|@/|/proc/2091042/root/|g' $out/stacks.bt
    ./actions/fix-lua-bt $out/stacks.bt > $out/stacks.fix.bt
    ./actions/stackcollapse-stap.pl  $out/stacks.fix.bt >  $out/stacks.cbt
    ./actions/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              $out/stacks.cbt > $out/stacks.svg
)

function shark-tmux-init () (
    tmux kill-session -t shark
    tmuxp load -d -y ./shark/shark.tmuxp.yaml
) 