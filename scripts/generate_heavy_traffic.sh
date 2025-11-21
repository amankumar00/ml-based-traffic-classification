#!/bin/bash
# Generate heavy traffic to create congestion for FPLF testing

echo "================================================================"
echo "HEAVY TRAFFIC GENERATOR - Creates actual congestion"
echo "================================================================"
echo ""
echo "This script generates continuous heavy traffic to create"
echo "link congestion, forcing FPLF to make routing decisions."
echo ""
echo "Usage: Run this INSIDE mininet CLI:"
echo "  mininet> source scripts/generate_heavy_traffic.sh"
echo ""
echo "Or paste these commands at mininet> prompt:"
echo "================================================================"
echo ""

cat << 'EOF'
# Start iperf servers on h1, h2, h4, h7
h1 iperf -s -p 5001 -u &
h2 iperf -s -p 5002 -u &
h4 iperf -s -p 5003 -u &
h7 iperf -s -p 5004 -u &
h8 iperf -s -p 22 -u &
h9 iperf -s -p 80 -u &

# Wait for servers to start
sh sleep 2

# Generate VIDEO traffic (h3->h1:5001, h6->h2:5002) - High bandwidth, low tolerance
h3 iperf -c 10.0.0.1 -p 5001 -u -b 8M -t 120 &
h6 iperf -c 10.0.0.2 -p 5002 -u -b 8M -t 120 &

# Generate SSH traffic (h5->h8:22) - Medium bandwidth, medium tolerance
h5 iperf -c 10.0.0.8 -p 22 -u -b 3M -t 120 &

# Generate HTTP traffic (h7->h9:80) - Medium bandwidth
h1 iperf -c 10.0.0.9 -p 80 -u -b 5M -t 120 &

# Generate FTP traffic (h2->h4:5003, h8->h7:5004) - High bandwidth, high tolerance
h2 iperf -c 10.0.0.4 -p 5003 -u -b 9M -t 120 &
h8 iperf -c 10.0.0.7 -p 5004 -u -b 9M -t 120 &

# Monitor: In another terminal run:
# tail -f data/fplf_monitoring/link_utilization.csv
# tail -f data/fplf_monitoring/fplf_routes.csv

EOF

echo ""
echo "================================================================"
echo "Copy the commands above and paste at mininet> prompt"
echo "================================================================"
