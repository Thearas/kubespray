#!/bin/bash

# this script is inspired by https://github.com/bhuanand/rps-rfs-configuration.
# unfortunately rps-rfs-configuration cannot be used directly, but the code is a good reference.

set -euo pipefail

disable_irqbalance() {
    systemctl disable irqbalance
    systemctl stop irqbalance
}

# set_irq_smp_affinity tries to distribute irqs evenly on CPU NUMA/Socket/Core/Threads
set_irq_smp_affinity() {
    local ifce1="$1"
    local ifce2="$2"

    # FIXME: need a not silly approach, it is basically all hardcoding now

    # set ifce1 smp affinity
    # numa1_cpus=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71)
    # numa2_cpus=(24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95)
    # i.e. cpus=(numa1core1 numa2core1 numa1core2 ...)
    cpus=(0 24 1 25 2 26 3 27 4 28 5 29 6 30 7 31 8 32 9 33 10 34 11 35 12 36 13 37 14 38 15 39 16 40 17 41 18 42 19 43 20 44 21 45 22 46 23 47 48 72 49 73 50 74 51 75 52 76 53 77 54 78 55 79 56 80 57 81 58 82 59 83 60 84 61 85 62 86 63 87 64 88 65 89 66 90 67 91 68 92 69 93 70 94 71 95)
    local irq_numbers=($(ls /sys/class/net/$ifce1/device/msi_irqs | sort -n)) # NOTE: assumes NIC uses msix irq
    for i in ${!irq_numbers[@]}; do
        echo ${cpus[$i]} > /proc/irq/${irq_numbers[$i]}/smp_affinity_list
    done

    # set ifce2 smp affinity
    # reverse cpus array
    cpus=(95 71 94 70 93 69 92 68 91 67 90 66 89 65 88 64 87 63 86 62 85 61 84 60 83 59 82 58 81 57 80 56 79 55 78 54 77 53 76 52 75 51 74 50 73 49 72 48 47 23 46 22 45 21 44 20 43 19 42 18 41 17 40 16 39 15 38 14 37 13 36 12 35 11 34 10 33 9 32 8 31 7 30 6 29 5 28 4 27 3 26 2 25 1 24 0)
    local irq_numbers=($(ls /sys/class/net/$ifce2/device/msi_irqs)) # NOTE: assumes NIC uses msix irq
    for i in ${!irq_numbers[@]}; do
        echo ${cpus[$i]} > /proc/irq/${irq_numbers[$i]}/smp_affinity_list
    done
}

configure_rps() {
    local ifce_name="$1"
    local cpu_mask_string="ffffffff,ffffffff,ffffffff" # FIXME: dynamically generate cpu mask by cpu count

    local rx_queues=($(ls "/sys/class/net/$ifce_name/queues/" | grep rx-))
    for q in ${rx_queues[@]}; do
        rps_cpu_file="/sys/class/net/$ifce_name/queues/$q/rps_cpus"
        echo $cpu_mask_string > $rps_cpu_file
    done
}

configure_rfs() {
    local ifce_name="$1"
    local SOCK_FLOW_ENTRIES=32768
    local rps_flow_cnt=1024

    echo $SOCK_FLOW_ENTRIES > /proc/sys/net/core/rps_sock_flow_entries

    local rx_queues=($(ls "/sys/class/net/$ifce_name/queues/" | grep rx-))
    for q in ${rx_queues[@]}; do
        rps_flow_cnt_file="/sys/class/net/$ifce_name/queues/$q/rps_flow_cnt"
        echo $rps_flow_cnt > $rps_flow_cnt_file
    done

    # enable ntuple(for aRFS)
    ethtool -K $ifce_name ntuple on
}

main() {
    local ifce1="eth0"
    local ifce2="eth1"

    disable_irqbalance
    set_irq_smp_affinity $ifce1 $ifce2
    configure_rps $ifce1
    configure_rfs $ifce1
    configure_rps $ifce2
    configure_rfs $ifce2
}

main
