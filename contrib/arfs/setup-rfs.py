#!/usr/bin/python3

# This script is inspired by https://github.com/bhuanand/rps-rfs-configuration
# Unfortunately we cannot use that script directly, because it parses /proc/interrupts differently to get IRQ: Queue mapping.
# And seems there isn't a general approach to do so (patterns in /proc/interrupts rely on NIC driver used).

import subprocess
import os
import typing
import re


def shell_cmd(cmd: str) -> str:
    print(f"bash: {cmd}")

    proc = subprocess.Popen(['bash', '-c', cmd],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            stdin=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode:
        raise Exception(proc.returncode, stdout.decode("utf8"), stderr.decode("utf8"), cmd)
    return stdout.decode("utf8")


RFS_SOCK_FLOW_ENTRIES = 32768
RFS_RPS_FLOW_CNT = 1024


def disable_irqbalance():
    shell_cmd("systemctl disable irqbalance")
    shell_cmd("systemctl stop irqbalance")


def iface_queues(iface: str, qtype: str = "rx") -> typing.List[str]:
    qs = os.listdir(f"/sys/class/net/{iface}/queues")
    return [q for q in qs if q.startswith(qtype)]


def configure_rps(iface: str):
    def rps_cpumask() -> str:
        return "ffffffff,ffffffff,ffffffff"  # FIXME: generates it

    cpumask = rps_cpumask()
    rx_queues = iface_queues(iface)
    for q in rx_queues:
        rps_cpu_file = f"/sys/class/net/{iface}/queues/{q}/rps_cpus"
        shell_cmd(f"echo {cpumask} > {rps_cpu_file}")


def configure_rfs(iface: str):
    rps_sock_flow_entries_file = "/proc/sys/net/core/rps_sock_flow_entries"
    shell_cmd(f"echo {RFS_SOCK_FLOW_ENTRIES} > {rps_sock_flow_entries_file}")

    rx_queues = iface_queues(iface)
    for q in rx_queues:
        rps_flow_count_file = f"/sys/class/net/{iface}/queues/{q}/rps_flow_cnt"
        shell_cmd(f"echo {RFS_RPS_FLOW_CNT} > {rps_flow_count_file}")

    # enable ntuple(for aRFS)
    shell_cmd(f"ethtool -K {iface} ntuple on")


def irq_nic_queue_mapping(iface_irq_pattern: str) -> typing.List[typing.Tuple[int, str]]:
    """
        gets a list of (network irq_number, NIC queue) tuples as a mapping
    """

    irq_mapping: typing.List[typing.Tuple[int, str]] = []
    with open("/proc/interrupts") as f:
        interrupt_data = f.readlines()

    for line in interrupt_data:
        match = re.search(iface_irq_pattern, line)
        if not match:
            continue

        if not match.groupdict()["irq"] or \
                not match.groupdict()["queue"]:
            raise Exception(f"irq or queue not found in line: {line}, match: {match}")

        irq, queue = int(match.groupdict()["irq"]), match.groupdict()["queue"]
        irq_mapping.append((irq, queue))

    return irq_mapping


def configure_irq_smp_affinity(iface_irq_pattern: str):
    cpu_list = [
        # NUMA1: 0-23,48-71, NUMA2: 24-47,72-95
        # cpu list is hardcoded here for getting CPU topology isn't so trivial
        list(range(0, 48)),
        list(range(48, 96))
    ]
    irq_queue_mapping = irq_nic_queue_mapping(iface_irq_pattern)

    for i in range(len(cpu_list[0])):
        cpu_thread0 = cpu_list[0][i]
        cpu_thread1 = cpu_list[1][i]
        irq_num, _ = irq_queue_mapping[i]
        shell_cmd(f"echo {cpu_thread0},{cpu_thread1} > /proc/irq/{irq_num}/smp_affinity_list")

    for i in range(len(cpu_list[0]), len(irq_queue_mapping)):
        # dump rest of NIC queues to core 0
        # NOTE: XPS will follow this configuration
        irq_num, _ = irq_queue_mapping[i]
        shell_cmd(f"echo 0 > /proc/irq/{irq_num}/smp_affinity_list")


def configure_xps(iface: str, iface_irq_pattern: str):
    irq_queue_mapping = irq_nic_queue_mapping(iface_irq_pattern)
    for i in range(len(irq_queue_mapping)):
        irq_num, queue = irq_queue_mapping[i]
        cpu_mask = shell_cmd(f"echo -n $(cat /proc/irq/{irq_num}/smp_affinity)")
        shell_cmd(f"echo {cpu_mask} > /sys/class/net/{iface}/queues/tx-{queue}/xps_cpus")


def main():
    iface0 = "eth0"
    iface0_irq_pattern = r"(?P<irq>\d+):.+mlx5_comp(?P<queue>\d+)@pci:0000:1a:00.0"
    iface1 = "eth1"
    iface1_irq_pattern = r"(?P<irq>\d+):.+mlx5_comp(?P<queue>\d+)@pci:0000:1a:00.1"

    disable_irqbalance()
    configure_rps(iface0)
    configure_rps(iface1)
    configure_rfs(iface0)
    configure_rfs(iface1)
    configure_irq_smp_affinity(iface0_irq_pattern)
    configure_irq_smp_affinity(iface1_irq_pattern)
    configure_xps(iface0, iface0_irq_pattern)
    configure_xps(iface1, iface1_irq_pattern)


if __name__ == '__main__':
    main()
