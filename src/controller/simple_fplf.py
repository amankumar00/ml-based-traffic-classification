"""
Simple FPLF (Fill Preferred Link First) Controller
Uses Dijkstra's algorithm for priority-based routing
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ipv4, tcp, udp
from ryu.topology import event
from ryu.topology.api import get_switch, get_link
from ryu.topology import switches as topology_switches
import networkx as nx


class SimpleFPLFController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]
    _CONTEXTS = {
        'switches': topology_switches.Switches
    }

    def __init__(self, *args, **kwargs):
        super(SimpleFPLFController, self).__init__(*args, **kwargs)

        # Network topology graph
        self.topology = nx.Graph()

        # MAC address learning
        self.mac_to_port = {}  # {dpid: {mac: port}}

        # Link load tracking for FPLF
        self.link_loads = {}  # {(src_dpid, dst_dpid): load_value}

        # Traffic priorities (for future use)
        self.priorities = {
            'VIDEO': 4,
            'SSH': 3,
            'HTTP': 2,
            'FTP': 1,
            'DEFAULT': 0
        }

        self.datapaths = {}
        self.logger.info("Simple FPLF Controller initialized")

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch connection"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id

        # Store datapath
        self.datapaths[dpid] = datapath

        # Install table-miss flow: send to controller
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER, ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

        self.logger.info(f"Switch s{dpid} connected")

    def add_flow(self, datapath, priority, match, actions, idle_timeout=0, hard_timeout=0):
        """Install a flow entry"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        mod = parser.OFPFlowMod(
            datapath=datapath,
            priority=priority,
            match=match,
            instructions=inst,
            idle_timeout=idle_timeout,
            hard_timeout=hard_timeout
        )
        datapath.send_msg(mod)

    @set_ev_cls(event.EventSwitchEnter)
    def switch_enter_handler(self, ev):
        """Handle switch entering topology"""
        switch = ev.switch
        self.topology.add_node(switch.dp.id)
        self.logger.info(f"Switch s{switch.dp.id} entered topology")
        self._log_topology()

    @set_ev_cls(event.EventLinkAdd)
    def link_add_handler(self, ev):
        """Handle link addition"""
        link = ev.link
        src = link.src
        dst = link.dst

        # Add bidirectional edge
        self.topology.add_edge(src.dpid, dst.dpid, src_port=src.port_no, dst_port=dst.port_no)

        # Initialize link loads
        self.link_loads[(src.dpid, dst.dpid)] = 0
        self.link_loads[(dst.dpid, src.dpid)] = 0

        self.logger.info(f"Link added: s{src.dpid}:port{src.port_no} <-> s{dst.dpid}:port{dst.port_no}")
        self._log_topology()

    def discover_topology(self):
        """Manually discover topology using get_link API"""
        links = get_link(self)

        if not links:
            self.logger.warning("No links discovered via LLDP yet")
            return

        for link in links:
            src = link.src
            dst = link.dst

            if not self.topology.has_edge(src.dpid, dst.dpid):
                self.topology.add_edge(src.dpid, dst.dpid, src_port=src.port_no, dst_port=dst.port_no)
                self.link_loads[(src.dpid, dst.dpid)] = 0
                self.link_loads[(dst.dpid, src.dpid)] = 0
                self.logger.info(f"Discovered link: s{src.dpid}:port{src.port_no} <-> s{dst.dpid}:port{dst.port_no}")

        self._log_topology()

    def _log_topology(self):
        """Log current topology state"""
        num_switches = self.topology.number_of_nodes()
        num_links = self.topology.number_of_edges()
        self.logger.info(f"Topology: {num_switches} switches, {num_links} links")

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Handle PacketIn messages"""
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

        # If we have switches but no links, try to discover topology
        if not hasattr(self, '_topology_discovered'):
            self._topology_discovered = False

        if not self._topology_discovered and self.topology.number_of_nodes() > 0 and self.topology.number_of_edges() == 0:
            self.logger.info("Attempting manual topology discovery...")
            self.discover_topology()
            if self.topology.number_of_edges() > 0:
                self._topology_discovered = True

        dst = eth.dst
        src = eth.src

        # Learn MAC address
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src] = in_port

        # Check if we know destination
        if dst in self._get_all_macs():
            # Find destination switch
            dst_dpid = self._find_mac_switch(dst)

            if dst_dpid is None:
                # Flood
                out_port = ofproto.OFPP_FLOOD
            elif dst_dpid == dpid:
                # Same switch - forward directly
                out_port = self.mac_to_port[dpid][dst]
            else:
                # Different switch - compute path with FPLF
                path = self._compute_fplf_path(dpid, dst_dpid, priority=0)

                if path and len(path) > 1:
                    # Install flows along the path
                    self._install_path(path, src, dst, msg.data)
                    self.logger.info(f"FPLF Path: {src} -> {dst}: {' -> '.join([f's{s}' for s in path])}")
                    return
                else:
                    out_port = ofproto.OFPP_FLOOD
        else:
            # Unknown destination - flood
            out_port = ofproto.OFPP_FLOOD

        # Send packet out
        actions = [parser.OFPActionOutput(out_port)]
        data = msg.data if msg.buffer_id == ofproto.OFP_NO_BUFFER else None
        out = parser.OFPPacketOut(
            datapath=datapath,
            buffer_id=msg.buffer_id,
            in_port=in_port,
            actions=actions,
            data=data
        )
        datapath.send_msg(out)

    def _get_all_macs(self):
        """Get all learned MAC addresses"""
        macs = set()
        for switch_macs in self.mac_to_port.values():
            macs.update(switch_macs.keys())
        return macs

    def _find_mac_switch(self, mac):
        """Find which switch has this MAC"""
        for dpid, macs in self.mac_to_port.items():
            if mac in macs:
                return dpid
        return None

    def _compute_fplf_path(self, src_dpid, dst_dpid, priority=0):
        """
        Compute path using FPLF with Dijkstra's algorithm

        FPLF: Fill Preferred Link First
        - Higher priority traffic prefers less loaded links
        - Weight = link_load × (5 - priority) + 1
        """
        if src_dpid == dst_dpid:
            return [src_dpid]

        if src_dpid not in self.topology or dst_dpid not in self.topology:
            return None

        try:
            # Set edge weights based on FPLF algorithm
            for u, v in self.topology.edges():
                load = self.link_loads.get((u, v), 0)
                # FPLF weight formula: higher priority → lower weight multiplier
                weight = load * (5 - priority) + 1
                self.topology[u][v]['weight'] = weight

            # Use Dijkstra's algorithm
            path = nx.dijkstra_path(self.topology, src_dpid, dst_dpid, weight='weight')

            # Update link loads for chosen path
            for i in range(len(path) - 1):
                link = (path[i], path[i+1])
                self.link_loads[link] = self.link_loads.get(link, 0) + 1

            return path

        except nx.NetworkXNoPath:
            self.logger.warning(f"No path from s{src_dpid} to s{dst_dpid}")
            return None

    def _install_path(self, path, src_mac, dst_mac, data=None):
        """Install flows along the computed path"""
        for i in range(len(path)):
            dpid = path[i]
            datapath = self.datapaths.get(dpid)

            if datapath is None:
                continue

            parser = datapath.ofproto_parser
            ofproto = datapath.ofproto

            # Determine output port
            if i == len(path) - 1:
                # Last switch - output to host
                out_port = self.mac_to_port[dpid][dst_mac]
            else:
                # Intermediate switch - output to next switch
                next_dpid = path[i + 1]
                # Find port connecting to next switch
                edge_data = self.topology[dpid][next_dpid]
                out_port = edge_data['src_port']

            # Install flow: match on dst MAC, forward to out_port
            actions = [parser.OFPActionOutput(out_port)]
            match = parser.OFPMatch(eth_dst=dst_mac)
            self.add_flow(datapath, 10, match, actions, idle_timeout=30)

            # For first switch, send the packet out
            if i == 0 and data:
                out = parser.OFPPacketOut(
                    datapath=datapath,
                    buffer_id=ofproto.OFP_NO_BUFFER,
                    in_port=ofproto.OFPP_CONTROLLER,
                    actions=actions,
                    data=data
                )
                datapath.send_msg(out)
