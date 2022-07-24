#!/usr/bin/env bash

function stapxx-run () {
    sudo rm -rf ./stapxx-*
    sudo ./stap++ -v ./samples/lj-lua-stacks.sxx -x 2887528 -D MAXSKIPPED=200000 --arg time=50
    sudo chmod a+r ./stapxx-* 
    sudo chmod -R 755 $(ls |grep stapxx-)
}
# sudo rm -rf ./stapxx-* ;sudo ./stap++   -v ./wg-samples/3-luajit-backtrace.sxx  -D MAXSKIPPED=200000  -x 2887528  --arg time=1 |tee stap.log