#!/usr/bin/env bash
pid="37745"

# bash -x -c '. ./actions/stapxx.actions.sh;stapxx-run'
function stapxx-run () {
    sudo rm -rf ./stapxx-*
    local sxx="./wg-samples/5-luajit-backtrace-stack.sxx"
    local time=300
    local flag=" -v -D MAXMAPENTRIES=200000  -D MAXSKIPPED=200000 -x $pid  --arg time=$time"
    rm -rf ./out
    mkdir -p ./out
    sudo ./stap++ $sxx  $flag |tee ./out/stap.log
    sudo chmod a+r ./stapxx-* 
    sudo chmod -R 755 $(ls |grep stapxx-)
    stapxx-svg ./out/stap.log
    firefox ./out/stacks.svg &!
}

function stapxx-svg () {
    local log=$1
    cat $log |grep -a 'report:' |sed 's/report://g' > ./out/stacks.bt
    sed -i 's/|lb|/\n/g' ./out/stacks.bt
    sed -i 's/|stack-fs|/\n/g' ./out/stacks.bt
    sed -i 's/|stack-fe|//g' ./out/stacks.bt
    sed -i 's/|fe|/\n/g' ./out/stacks.bt
    sed -i 's/|pf-s|//g' ./out/stacks.bt
    sed -i 's/|pf-e|//g' ./out/stacks.bt
    sed -i 's/|vm_c|//g' ./out/stacks.bt
    sed -i 's/|trace-f|//g' ./out/stacks.bt
    sed -i 's/|stack|//g' ./out/stacks.bt
    sed -i 's/|lt|/\n\t/g' ./out/stacks.bt
    ./actions/fix-lua-bt ./out/stacks.bt > ./out/stacks.fix.bt
    ./actions/stackcollapse-stap.pl  ./out/stacks.fix.bt >  ./out/stacks.cbt
    ./actions/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              ./out/stacks.cbt > ./out/stacks.svg
}