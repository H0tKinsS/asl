iptables -t nat -A POSTROUTING -j MASQUERADE -o eth2 -s 10.21.130.0/24

iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 1001 --to 10.21.130.11:22
iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 2002 --to 10.21.130.12:22

iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 8016 --to 10.21.130.11:80
iptables -t nat -I PREROUTING -j DNAT -p tcp -d 192.168.76.130 --dport 8006 --to 10.21.130.12:80
