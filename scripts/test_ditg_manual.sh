#!/bin/bash
# Test D-ITG manually in Mininet CLI
# This lets us run D-ITG commands interactively to see what's happening

echo "=========================================="
echo "  D-ITG Manual Test in Mininet"
echo "=========================================="
echo ""
echo "This will start a simple 2-host topology."
echo "You can then manually test D-ITG commands."
echo ""
echo "Commands to try in Mininet CLI:"
echo "  h2 ITGRecv -l /tmp/recv.log &"
echo "  h1 ITGSend -a 10.0.0.2 -t 30000 -C 100 -c 500 -T TCP -l /tmp/send.log &"
echo ""
echo "Check traffic:"
echo "  h1 ping -c 3 h2"
echo "  h2 netstat -tuln | grep 8999"
echo "  h1 tcpdump -i h1-eth0 -n -c 20"
echo ""
echo "Press Ctrl+D to exit Mininet when done."
echo ""

sudo mn --controller=none --switch=ovsk --topo=single,2 --link=tc,bw=10
