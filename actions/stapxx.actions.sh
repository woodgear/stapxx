#!/usr/bin/env bash

# bash -x -c '. ./actions/stapxx.actions.sh;stapxx-run'
function stapxx-run() (
    local pid=$1
    sudo rm -rf ./stapxx-*
    local sxx="./wg-samples/j-stap-1-luajit-backtrace-stack.sxx"
    local time=120
    local flag=" -v -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000 -x $pid  --arg time=$time"
    rm -rf ./out
    mkdir -p ./out
    sudo ./stap++ $sxx  $flag |tee ./out/stap.log
    sudo chmod a+r ./stapxx-* 
    sudo chmod -R 755 $(ls |grep stapxx-)
    IGNORE_RAW_PROBEFN=true
    stapxx-svg ./out/stap.log
    firefox ./out/stacks.svg &!
)

function stapxx-run-docker-nginx() (
    set -x
    local cname=$1 #nginx container id, the fd 1 process must be nginx master.
    sudo rm -rf ./stapxx-*
    local time=120
    local base=$(docker inspect $cid  | jq -r '.[0].GraphDriver.Data.MergedDir')
    local nginx_master=$(docker-get-pid-by-container-name-or-uuid $cname)
    local nginx_worker=$(ps-list-child $nginx_master | tail -n 1 | awk '{print $2}')
    echo $base
    echo $nginx_worker

    local sxx="./wg-samples/docker/j-stap-1-luajit-backtrace-stack.sxx"
    local cfg="-v -DDEBUG_TASK_FINDER=9 -DDEBUG_UPROBES=9 -DDEBUG_TASK_FINDER_VMA=9"
    # TODO stapxx 不认 --sysroot，需要改他的代码。。很麻烦。。
    local flag=" -v  -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000 -exec=/proc/2091042/root/openresty-wg/target/nginx/sbin/nginx -x $nginx_worker  --arg time=$time"
    sudo rm -rf ./out
    mkdir -p ./out
    echo "xx"
    local cmd="sudo ./stap++ $sxx  $flag"
    eval $cmd |tee ./out/stap.log
    # sudo wg-stap ./wg-samples/docker/2-get_l_m_vmstate.stap -s 160  -v -DDEBUG_TASK_FINDER=9 -DDEBUG_UPROBES=9 --sysroot=/proc/2091042/root  -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000 -x 2091042 
    # sudo wg-stap ./wg-samples/docker/2-get_l_m_vmstate.stap -s 160  -v  -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000 -x 2091042 
)

function stapxx-svg () (
    local log=$1
    cat $log |grep -a 'report:' |sed 's/report://g' > ./out/stacks.bt
    sed -i 's/|lb|/\n/g' ./out/stacks.bt
    sed -i 's/|stack-fs|/\n/g' ./out/stacks.bt
    sed -i 's/|stack-fe|//g' ./out/stacks.bt
    sed -i 's/|fe|/\n/g' ./out/stacks.bt
    sed -i 's/|vm_c|//g' ./out/stacks.bt
    sed -i 's/|trace-f|//g' ./out/stacks.bt
    sed -i 's/|stack|//g' ./out/stacks.bt
    sed -i 's/|lt|/\n\t/g' ./out/stacks.bt

    if [ -n "$IGNORE_RAW_PROBEFN" ] ; then
        sed -i 's/|pf-s|0x.*|pf-e|/|pf-s|unresolved|pf-e|/g' ./out/stacks.bt
    fi
    sed -i 's/|pf-s|//g' ./out/stacks.bt
    sed -i 's/|pf-e|//g' ./out/stacks.bt

    sed -i 's|@/|/proc/2091042/root/|g' ./out/stacks.bt
    ./actions/fix-lua-bt ./out/stacks.bt > ./out/stacks.fix.bt
    ./actions/stackcollapse-stap.pl  ./out/stacks.fix.bt >  ./out/stacks.cbt
    ./actions/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              ./out/stacks.cbt > ./out/stacks.svg
)