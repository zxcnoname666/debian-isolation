#!/bin/bash
# usage: sudo ./clear_cache.sh [1|2|3]
level=${1:-3}
sync
echo $level | sudo tee /proc/sys/vm/drop_caches
free -h
