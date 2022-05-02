#!/bin/bash
function stap-base() {
	local x=$(dirname $(dirname $(zmx-find-path-of-action)) )
	echo $x
}

function stap-nginx-flamegraph () {
	local pid=$1
	local time=10
	local base=$(stap-base)
	echo "capture nginx $pid"
	local bt=./nginx.$pid.lua
	sudo $base/stap++ $base/samples/lj-lua-stacks.sxx -x $pid  --arg time=$time |  tee $bt.stacks
	$base/openresty-systemtap-toolkit/fix-lua-bt $bt.stacks > $bt.stacks.fix
	$base/FlameGraph/stackcollapse-stap.pl $bt.stacks.fix > $bt.stackcollapse
	$base/FlameGraph/flamegraph.pl $bt.stackcollapse > $bt.svg
}
