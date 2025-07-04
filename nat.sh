iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1 -s 192.168.130.0/24

iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 101 --to 192.168.130.101:80
iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 102 --to 192.168.130.102:80
