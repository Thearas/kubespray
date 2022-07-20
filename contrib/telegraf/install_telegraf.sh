cd /root/
yum localinstall telegraf-1.17.0-1.x86_64.rpm -y

systemctl enable telegraf 

 # Get config
FILE="/etc/telegraf/telegraf.conf"

# Get private IP
IP=$(ip route get 1.2.3.4 | awk '{print $7}')
# IP=$(ip route get 1 | awk '{print $NF;exit}')
# Empty the file first
> $FILE

  # Write the config
cat << EOF > $FILE
[agent]
  hostname = "${IP}"
  flush_interval = "15s"
  interval = "15s"


# Input Plugins
[[inputs.cpu]]
    percpu = true
    totalcpu = true
    collect_cpu_time = false
    report_active = false
[[inputs.disk]]
    ignore_fs = ["tmpfs", "devtmpfs", "devfs"]
[[inputs.io]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.processes]]
[[inputs.kernel]]

# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = "k8s"
  urls = [ "http://172.16.5.25:8086" ] 
  username = "telegraf"
  password = "opennova"
EOF

systemctl restart telegraf
