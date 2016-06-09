#!/bin/bash
echo "Overclocking GPU Bus frequency..."
echo 852000000 > /sys/kernel/debug/clock/override.gbus/rate
echo 1 > /sys/kernel/debug/clock/override.gbus/state
echo "Current GPU Bus frequency:"
cat /sys/kernel/debug/clock/gbus/rate
echo "Overclocking GPU memory clock..."
echo 954000000 > /sys/kernel/debug/clock/override.emc/rate
echo 1 > /sys/kernel/debug/clock/override.emc/state
echo "Current GPU Memory clock frequency:"
cat /sys/kernel/debug/clock/emc/rate
