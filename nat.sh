iptables -t nat -A POSTROUTING -j MASQUERADE -o eth2 -s /24

iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 1001 --to 192.168.130.101:22
iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 2001 --to 192.168.130.102:22
