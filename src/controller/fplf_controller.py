"""
FPLF (Fill Preferred Link First) Routing Controller
Priority-based routing using traffic classification results
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ipv4, tcp, udp, arp
from ryu.topology import event
from ryu.topology.api import get_switch, get_link
import networkx as nx
import pandas as pd
import os


class FPLFController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(FPLFController, self).__init__(*args, **kwargs)

        # MAC to host mapping
        self.mac_to_port = {}
        self.mac_to_dpid = {}

        # Network topology
        self.topology = nx.DiGraph()
        self.datapaths = {}

        # Traffic priorities (higher = more important)
        self.traffic_priorities = {
            'VIDEO': 4,  # Highest - real-time streaming
            'SSH': 3,    # High - interactive
            'HTTP': 2,   # Medium
            'FTP': 1     # Low - bulk transfer
        }

        # Link loads (track bandwidth usage)
        self.link_loads = {}  # (src_dpid, dst_dpid) -> load

        # Flow routes cache
        self.flow_routes = {}

        # Track inter-switch ports (don't learn host MACs from these)
        self.inter_switch_ports = set()  # (dpid, port_no)

        # Load classified flows
        self.classified_flows = self._load_classified_flows()

        self.logger.info("FPLF Controller initialized")
        self.logger.info(f"Loaded {len(self.classified_flows)} classified flows")

    def _load_classified_flows(self):
        """Load classified flows from CSV"""
        csv_path = os.path.join(
            os.path.dirname(__file__),
            '../../data/processed/host_to_host_flows.csv'
        )

        flows = {}
        if os.path.exists(csv_path):
            df = pd.read_csv(csv_path)
            for _, row in df.iterrows():
                key = (row['src_host'], row['dst_host'],
                       int(row['dst_port']), row['protocol'])
                flows[key] = {
                    'traffic_type': row['traffic_type'],
                    'priority': self.traffic_priorities.get(row['traffic_type'], 0),
                    'bandwidth': float(row['total_bytes']) / float(row['flow_duration'])
                }
            self.logger.info(f"Loaded flows from {csv_path}")
        else:
            self.logger.warning(f"Flow classification file not found: {csv_path}")

        return flows

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch connection"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        # Install table-miss flow entry (send all unmatched packets to controller)
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                          ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

        self.datapaths[datapath.id] = datapath
        self.logger.info(f"Switch {datapath.id} connected - table-miss flow installed (priority=0, match=all, action=CONTROLLER)")

    def add_flow(self, datapath, priority, match, actions, buffer_id=None, idle_timeout=0):
        """Add flow entry to switch"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]

        if buffer_id:
            mod = parser.OFPFlowMod(
                datapath=datapath, buffer_id=buffer_id,
                priority=priority, match=match, instructions=inst,
                idle_timeout=idle_timeout
            )
        else:
            mod = parser.OFPFlowMod(
                datapath=datapath, priority=priority,
                match=match, instructions=inst,
                idle_timeout=idle_timeout
            )
        datapath.send_msg(mod)

    @set_ev_cls(event.EventSwitchEnter)
    def switch_enter_handler(self, ev):
        """Handle switch entering topology"""
        self.logger.info(f"Switch entered: {ev.switch.dp.id}")
        self._update_topology()

    @set_ev_cls(event.EventLinkAdd)
    def link_add_handler(self, ev):
        """Handle link addition"""
        src = ev.link.src
        dst = ev.link.dst
        self.logger.info(f"*** LINK DISCOVERED: s{src.dpid} port {src.port_no} <--> s{dst.dpid} port {dst.port_no} ***")
        self._update_topology()

    def _update_topology(self):
        """Update network topology graph"""
        switches = get_switch(self, None)
        links = get_link(self, None)

        # Clear and rebuild topology
        self.topology.clear()

        # Add switches as nodes
        for switch in switches:
            self.topology.add_node(switch.dp.id)

        # Add links as edges with bandwidth capacity
        for link in links:
            src_dpid = link.src.dpid
            dst_dpid = link.dst.dpid

            # Initialize link load if not exists
            if (src_dpid, dst_dpid) not in self.link_loads:
                self.link_loads[(src_dpid, dst_dpid)] = 0

            # Add edge with weight (for shortest path)
            self.topology.add_edge(src_dpid, dst_dpid,
                                   port=link.src.port_no,
                                   load=self.link_loads[(src_dpid, dst_dpid)])

        # FALLBACK: If LLDP discovery fails, manually build topology
        num_switches = self.topology.number_of_nodes()
        num_links = self.topology.number_of_edges()

        if num_links == 0 and num_switches >= 2:
            self.logger.warning(f"LLDP discovery failed ({num_switches} switches connected, {num_links} links) - manually building topology")

            # Clear old inter-switch ports and MAC learning before rebuilding
            # (MACs may have been learned with incorrect port configs from earlier topologies)
            self.inter_switch_ports.clear()
            self.mac_to_dpid.clear()
            self.mac_to_port.clear()

            # CRITICAL: Clear all flow tables on all switches to remove stale flows
            # from previous topology builds (2-switch, 3-switch, etc.)
            self._clear_all_flows()

            if num_switches == 4:
                # Demo topology: 4 switches with multiple paths
                # Hosts: s1(h1=1,h2=2), s2(h3=1,h4=2), s3(h5=1), s4(h6=1)
                # Switch links added after hosts get sequential ports
                manual_links = [
                    (1, 2, 3), (2, 1, 3),  # s1 port 3 <-> s2 port 3
                    (1, 3, 4), (3, 1, 2),  # s1 port 4 <-> s3 port 2
                    (2, 4, 4), (4, 2, 2),  # s2 port 4 <-> s4 port 2
                    (3, 4, 3), (4, 3, 3),  # s3 port 3 <-> s4 port 3
                    (1, 4, 5), (4, 1, 4),  # s1 port 5 <-> s4 port 4
                ]
            elif num_switches == 2:
                # Simple 2-switch topology: s1 <-> s2
                # Mininet auto-assigns ports: first host links get low numbers, then switch links
                manual_links = [
                    (1, 2, 2), (2, 1, 2),  # s1 port 2 <-> s2 port 2
                ]
            elif num_switches == 3:
                # Simple 3-switch line: s1 <-> s2 <-> s3
                manual_links = [
                    (1, 2, 2), (2, 1, 2),  # s1 <-> s2
                    (2, 3, 3), (3, 2, 2),  # s2 <-> s3
                ]
            else:
                # Default: linear topology (daisy chain)
                manual_links = []
                for i in range(1, num_switches):
                    manual_links.append((i, i+1, i+1))
                    manual_links.append((i+1, i, i))

            for src, dst, port in manual_links:
                if (src, dst) not in self.link_loads:
                    self.link_loads[(src, dst)] = 0
                self.topology.add_edge(src, dst, port=port, load=0)
                # Track as inter-switch port (don't learn host MACs from these)
                self.inter_switch_ports.add((src, port))
            self.logger.info(f"Manual topology: {num_switches} switches, {self.topology.number_of_edges()} links")
            self.logger.info(f"Inter-switch ports: {sorted(self.inter_switch_ports)}")

        self.logger.info(f"Topology updated: {self.topology.number_of_nodes()} switches, "
                        f"{self.topology.number_of_edges()} links")

    def _clear_all_flows(self):
        """Clear all flow entries from all switches"""
        for dpid, datapath in self.datapaths.items():
            ofproto = datapath.ofproto
            parser = datapath.ofproto_parser

            # Delete all flows
            match = parser.OFPMatch()
            mod = parser.OFPFlowMod(
                datapath=datapath,
                command=ofproto.OFPFC_DELETE,
                out_port=ofproto.OFPP_ANY,
                out_group=ofproto.OFPG_ANY,
                match=match
            )
            datapath.send_msg(mod)
            self.logger.info(f"Cleared all flows on switch {dpid}")

            # Re-install table-miss flow
            match = parser.OFPMatch()
            actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                              ofproto.OFPCML_NO_BUFFER)]
            self.add_flow(datapath, 0, match, actions)

            # Install proactive ARP flooding rule (priority 100, higher than table-miss)
            match = parser.OFPMatch(eth_type=0x0806)  # ARP ethertype
            actions = [
                parser.OFPActionOutput(ofproto.OFPP_CONTROLLER, ofproto.OFPCML_NO_BUFFER),
                parser.OFPActionOutput(ofproto.OFPP_FLOOD)
            ]
            self.add_flow(datapath, 100, match, actions)
            self.logger.info(f"Re-installed table-miss and ARP flooding flows on switch {dpid}")

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Handle packet-in messages"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        dpid = datapath.id

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocol(ethernet.ethernet)

        if eth.ethertype == 0x88cc:  # LLDP
            return

        # Log packets for debugging (increased limit to see ping traffic)
        if not hasattr(self, '_packet_count'):
            self._packet_count = 0
        self._packet_count += 1
        if self._packet_count <= 500:  # Increased to see all ping traffic
            eth_type_name = {
                0x0800: 'IPv4',
                0x0806: 'ARP',
                0x86dd: 'IPv6',
                0x88cc: 'LLDP'
            }.get(eth.ethertype, 'Unknown')
            self.logger.info(f"Packet #{self._packet_count}: dpid={dpid}, port={in_port}, eth_type=0x{eth.ethertype:04x} ({eth_type_name})")

        dst = eth.dst
        src = eth.src

        # Learn MAC addresses BEFORE any early returns
        # BUT: Don't learn from inter-switch ports (avoid incorrect host location)
        if (dpid, in_port) not in self.inter_switch_ports:
            self.mac_to_dpid[src] = dpid
            self.mac_to_port.setdefault(dpid, {})
            self.mac_to_port[dpid][src] = in_port
        else:
            # Don't learn host MACs from packets transiting inter-switch links
            if self._packet_count <= 100:
                self.logger.debug(f"Skipping MAC learning from inter-switch port {dpid}:{in_port}")

        # Handle ARP packets
        arp_pkt = pkt.get_protocol(arp.arp)
        if arp_pkt:
            opcode_name = 'Request' if arp_pkt.opcode == 1 else 'Reply'
            self.logger.info(f"[s{dpid} port {in_port}] ARP {opcode_name}: {arp_pkt.src_ip} ({src}) -> {arp_pkt.dst_ip}")

            # For ARP replies, if we know the destination, send directly
            # For ARP requests, always flood
            if arp_pkt.opcode == 2 and dst in self.mac_to_dpid:
                # ARP Reply - send directly to destination (don't flood!)
                dst_dpid = self.mac_to_dpid[dst]
                if dst_dpid == dpid:
                    # Destination on same switch
                    out_port = self.mac_to_port[dpid][dst]
                    self.logger.info(f"  → s{dpid}: Sending ARP reply directly to port {out_port}")
                    actions = [parser.OFPActionOutput(out_port)]
                else:
                    # Need to route through network - flood
                    self.logger.info(f"  → s{dpid}: Flooding ARP reply (dst on different switch)")
                    actions = [parser.OFPActionOutput(ofproto.OFPP_FLOOD)]
            else:
                # ARP Request or unknown destination - flood to ALL ports
                # Send SEPARATE PacketOut for each port to ensure proper delivery
                flood_ports = []
                for port_no in datapath.ports.keys():
                    if port_no != in_port and port_no != ofproto.OFPP_LOCAL:
                        flood_ports.append(port_no)
                        # Send individual PacketOut for this port
                        actions = [parser.OFPActionOutput(port_no)]
                        out = parser.OFPPacketOut(
                            datapath=datapath,
                            buffer_id=ofproto.OFP_NO_BUFFER,
                            in_port=in_port,
                            actions=actions,
                            data=msg.data
                        )
                        datapath.send_msg(out)
                self.logger.info(f"  → s{dpid}: Flooded ARP to {len(flood_ports)} ports {flood_ports} (excluding in_port={in_port})")
                return

            # Send PacketOut for direct forwarding (ARP replies)
            out = parser.OFPPacketOut(
                datapath=datapath,
                buffer_id=ofproto.OFP_NO_BUFFER,
                in_port=in_port,
                actions=actions,
                data=msg.data
            )
            datapath.send_msg(out)
            return

        # Extract IP information first (for logging and routing decisions)
        ip_pkt = pkt.get_protocol(ipv4.ipv4)

        # Get destination
        if dst in self.mac_to_dpid:
            dst_dpid = self.mac_to_dpid[dst]

            # Process IP packets for FPLF routing
            if ip_pkt:
                src_ip = self._ip_to_host(ip_pkt.src)
                dst_ip = self._ip_to_host(ip_pkt.dst)

                tcp_pkt = pkt.get_protocol(tcp.tcp)
                udp_pkt = pkt.get_protocol(udp.udp)

                if tcp_pkt:
                    dst_port = tcp_pkt.dst_port
                    protocol = 'TCP'
                elif udp_pkt:
                    dst_port = udp_pkt.dst_port
                    protocol = 'UDP'
                else:
                    dst_port = 0
                    protocol = 'OTHER'

                # Get flow info from classification
                flow_key = (src_ip, dst_ip, dst_port, protocol)
                flow_info = self.classified_flows.get(flow_key, {
                    'traffic_type': 'UNKNOWN',
                    'priority': 0,
                    'bandwidth': 0
                })

                # Calculate path using FPLF
                path = self._fplf_routing(dpid, dst_dpid, flow_info)

                if path:
                    self._install_path(path, src, dst, in_port, msg, flow_info)
                    path_str = ' -> '.join([f's{dpid}' for dpid in path])
                    self.logger.info(f"═══ FPLF ROUTE ═══")
                    self.logger.info(f"  Flow: {src_ip} → {dst_ip}:{dst_port} ({protocol})")
                    self.logger.info(f"  Type: {flow_info['traffic_type']} (Priority {flow_info['priority']})")
                    self.logger.info(f"  Path: {path_str}")
                    self.logger.info(f"════════════════")
                    return
                else:
                    self.logger.warning(f"No path found: {dpid} -> {dst_dpid}")

        # Flood if no path found
        if ip_pkt:
            src_ip = self._ip_to_host(ip_pkt.src)
            dst_ip = self._ip_to_host(ip_pkt.dst)
            if src_ip.startswith('h') and dst_ip.startswith('h'):
                self.logger.debug(f"Flooding: {src_ip} -> {dst_ip} (dst MAC {dst} not learned)")

        out_port = ofproto.OFPP_FLOOD
        actions = [parser.OFPActionOutput(out_port)]

        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                  in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)

    def _ip_to_host(self, ip):
        """Convert IP to host name (e.g., 10.0.0.1 -> h1)"""
        if '.' in ip:
            parts = ip.split('.')
            if len(parts) == 4 and parts[0] == '10' and parts[1] == '0' and parts[2] == '0':
                try:
                    return f'h{int(parts[3])}'
                except ValueError:
                    pass
        return ip

    def _fplf_routing(self, src_dpid, dst_dpid, flow_info):
        """
        FPLF: Fill Preferred Link First routing using Dijkstra's algorithm
        Routes high-priority flows on preferred (least loaded) paths
        """
        if src_dpid == dst_dpid:
            return [src_dpid]

        try:
            priority = flow_info.get('priority', 0)
            bandwidth = flow_info.get('bandwidth', 0)

            # FPLF Algorithm using Dijkstra's:
            # Set edge weights based on current load and traffic priority
            # Weight = link_load × (5 - priority)
            # High priority (VIDEO=4) → weight multiplier = 1 (strongly prefers low-load)
            # Low priority (FTP=1) → weight multiplier = 4 (less sensitive to load)

            # Temporarily set edge weights for this traffic type
            for u, v in self.topology.edges():
                link = (u, v)
                current_load = self.link_loads.get(link, 0)
                # Weight formula: load × (5 - priority) + small constant to prefer shorter paths
                self.topology[u][v]['weight'] = current_load * (5 - priority) + 1

            # Use Dijkstra's algorithm to find shortest weighted path
            best_path = nx.dijkstra_path(self.topology, src_dpid, dst_dpid, weight='weight')

            # Update link loads for chosen path
            if best_path:
                for i in range(len(best_path) - 1):
                    link = (best_path[i], best_path[i + 1])
                    self.link_loads[link] = self.link_loads.get(link, 0) + bandwidth

            return best_path

        except nx.NetworkXNoPath:
            return None

    def _install_path(self, path, src_mac, dst_mac, in_port, msg, flow_info):
        """Install flow rules along the computed path"""
        priority = 10 + flow_info.get('priority', 0)  # Higher traffic priority = higher flow priority

        for i in range(len(path)):
            dpid = path[i]
            datapath = self.datapaths.get(dpid)

            if not datapath:
                continue

            parser = datapath.ofproto_parser

            # Determine output port
            if i == len(path) - 1:
                # Last switch - output to destination host
                out_port = self.mac_to_port[dpid][dst_mac]
            else:
                # Intermediate switch - output to next switch
                next_dpid = path[i + 1]
                out_port = self.topology[dpid][next_dpid]['port']

            actions = [parser.OFPActionOutput(out_port)]

            # Match on eth_dst/eth_src only (don't match in_port on intermediate switches)
            # This allows the flow to work regardless of which port it enters from
            match = parser.OFPMatch(eth_dst=dst_mac, eth_src=src_mac)

            # Install flow with timeout
            self.add_flow(datapath, priority, match, actions, idle_timeout=30)

            # For first switch, send packet out
            if i == 0:
                data = None
                if msg.buffer_id == datapath.ofproto.OFP_NO_BUFFER:
                    data = msg.data

                out = parser.OFPPacketOut(
                    datapath=datapath, buffer_id=msg.buffer_id,
                    in_port=in_port, actions=actions, data=data
                )
                datapath.send_msg(out)
