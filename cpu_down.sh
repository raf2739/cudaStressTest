#!/bin/bash
str="$(cat /proc/cpuinfo | grep k1)"
if [ "${str}" ]; then
	echo 0 > /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/enable
	echo 0 > /sys/devices/system/cpu/cpu1/online
	echo 0 > /sys/devices/system/cpu/cpu2/online
	echo 0 > /sys/devices/system/cpu/cpu3/online
	echo LP > /sys/kernel/cluster/active
else
	echo "x1 commands"
fi
