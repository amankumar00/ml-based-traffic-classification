"""
Ryu SDN Controller for Traffic Monitoring and Classification
Monitors network traffic and collects flow statistics for ML-based classification
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, DEAD_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ipv4, tcp, udp, icmp
# IPv6 support temporarily disabled for debugging
try:
    from ryu.lib.packet import ipv6
    IPV6_AVAILABLE = True
except ImportError:
    IPV6_AVAILABLE = False
from ryu.lib import hub
import time
import json
import os


class TrafficMonitorController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(TrafficMonitorController, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
        self.datapaths = {}
        self.monitor_thread = hub.spawn(self._monitor)
        self.save_thread = hub.spawn(self._periodic_save)

        # Traffic statistics storage
        self.flow_stats = {}
        self.port_stats = {}

        # Packet capture buffer
        self.captured_packets = []
        self.max_packets = 10000

        # Output directory for collected data
        self.data_dir = os.path.join(os.path.dirname(__file__), '../../data/raw')
        os.makedirs(self.data_dir, exist_ok=True)

        # Log IPv6 support status
        if IPV6_AVAILABLE:
            self.logger.info("IPv6 support: ENABLED")
        else:
            self.logger.info("IPv6 support: DISABLED")

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch connection and install table-miss flow entry"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        # Install table-miss flow entry
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                          ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

        self.logger.info("Switch connected: %016x", datapath.id)

    def add_flow(self, datapath, priority, match, actions, buffer_id=None):
        """Add a flow entry to the switch"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,
                                             actions)]
        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                    priority=priority, match=match,
                                    instructions=inst)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                    match=match, instructions=inst)
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Handle incoming packets"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        dst = eth.dst
        src = eth.src
        dpid = datapath.id

        # Learn MAC address to avoid flooding
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src] = in_port

        # Determine output port
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [parser.OFPActionOutput(out_port)]

        # DISABLED: Install flow to avoid packet_in next time
        # We want ALL packets to come to controller for ML classification
        # if out_port != ofproto.OFPP_FLOOD:
        #     match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src)
        #     if msg.buffer_id != ofproto.OFP_NO_BUFFER:
        #         self.add_flow(datapath, 1, match, actions, msg.buffer_id)
        #         return
        #     else:
        #         self.add_flow(datapath, 1, match, actions)

        # Extract packet features for ML
        self._extract_packet_features(pkt, dpid, in_port)

        # Send packet out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                  in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)

    def _extract_packet_features(self, pkt, dpid, in_port):
        """Extract features from packet for ML classification"""
        try:
            eth = pkt.get_protocol(ethernet.ethernet)
            if not eth:
                return

            # Check for both IPv4 and IPv6
            ip_pkt = pkt.get_protocol(ipv4.ipv4)
            ipv6_pkt = pkt.get_protocol(ipv6.ipv6) if IPV6_AVAILABLE else None
            tcp_pkt = pkt.get_protocol(tcp.tcp)
            udp_pkt = pkt.get_protocol(udp.udp)
            icmp_pkt = pkt.get_protocol(icmp.icmp)

            packet_info = {
                'timestamp': time.time(),
                'dpid': dpid,
                'in_port': in_port,
                'eth_src': eth.src,
                'eth_dst': eth.dst,
                'eth_type': eth.ethertype,
                'packet_size': len(pkt.data) if hasattr(pkt, 'data') else 0
            }

            # Extract IPv4 information
            if ip_pkt:
                packet_info.update({
                    'ip_src': ip_pkt.src,
                    'ip_dst': ip_pkt.dst,
                    'ip_proto': ip_pkt.proto,
                    'ip_tos': ip_pkt.tos,
                    'ip_ttl': ip_pkt.ttl,
                    'ip_length': ip_pkt.total_length,
                    'ip_version': 4
                })
            # Extract IPv6 information
            elif ipv6_pkt and IPV6_AVAILABLE:
                try:
                    packet_info.update({
                        'ip_src': ipv6_pkt.src,
                        'ip_dst': ipv6_pkt.dst,
                        'ip_proto': ipv6_pkt.nxt,
                        'ip_ttl': ipv6_pkt.hop_limit,
                        'ip_length': ipv6_pkt.payload_length,
                        'ip_version': 6
                    })
                except AttributeError as e:
                    self.logger.debug(f"IPv6 packet missing attribute: {e}")

            if tcp_pkt:
                packet_info.update({
                    'protocol': 'TCP',
                    'src_port': tcp_pkt.src_port,
                    'dst_port': tcp_pkt.dst_port,
                    'tcp_flags': tcp_pkt.bits,
                    'tcp_window': tcp_pkt.window_size
                })
            elif udp_pkt:
                packet_info.update({
                    'protocol': 'UDP',
                    'src_port': udp_pkt.src_port,
                    'dst_port': udp_pkt.dst_port
                })
            elif icmp_pkt:
                packet_info.update({
                    'protocol': 'ICMP',
                    'icmp_type': icmp_pkt.type,
                    'icmp_code': icmp_pkt.code
                })
            else:
                packet_info['protocol'] = 'OTHER'

            # Store packet info
            self.captured_packets.append(packet_info)

            # Limit buffer size
            if len(self.captured_packets) > self.max_packets:
                self._save_captured_packets()
                self.captured_packets = []

        except Exception as e:
            self.logger.error(f"Error extracting packet features: {e}")
            import traceback
            self.logger.error(traceback.format_exc())

    @set_ev_cls(ofp_event.EventOFPStateChange, [MAIN_DISPATCHER, DEAD_DISPATCHER])
    def state_change_handler(self, ev):
        """Track datapath state changes"""
        datapath = ev.datapath
        if ev.state == MAIN_DISPATCHER:
            if datapath.id not in self.datapaths:
                self.logger.info('Register datapath: %016x', datapath.id)
                self.datapaths[datapath.id] = datapath
        elif ev.state == DEAD_DISPATCHER:
            if datapath.id in self.datapaths:
                self.logger.info('Unregister datapath: %016x', datapath.id)
                del self.datapaths[datapath.id]

    def _monitor(self):
        """Periodic monitoring thread to request flow stats"""
        while True:
            try:
                for dp in self.datapaths.values():
                    self._request_stats(dp)
            except Exception as e:
                self.logger.error(f"Error in monitor thread: {e}")
            hub.sleep(10)

    def _periodic_save(self):
        """Periodically save captured packets every 30 seconds"""
        while True:
            try:
                hub.sleep(30)
                if self.captured_packets:
                    self._save_captured_packets()
                    self.captured_packets = []
                    self.logger.info("Periodic save completed")
            except Exception as e:
                self.logger.error(f"Error in periodic save thread: {e}")

    def _request_stats(self, datapath):
        """Request flow and port statistics from switch"""
        self.logger.debug('Send stats request to datapath: %016x', datapath.id)
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        req = parser.OFPFlowStatsRequest(datapath)
        datapath.send_msg(req)

        req = parser.OFPPortStatsRequest(datapath, 0, ofproto.OFPP_ANY)
        datapath.send_msg(req)

    @set_ev_cls(ofp_event.EventOFPFlowStatsReply, MAIN_DISPATCHER)
    def flow_stats_reply_handler(self, ev):
        """Handle flow statistics replies"""
        body = ev.msg.body
        dpid = ev.msg.datapath.id

        flows = []
        for stat in body:
            flows.append({
                'table_id': stat.table_id,
                'duration_sec': stat.duration_sec,
                'priority': stat.priority,
                'idle_timeout': stat.idle_timeout,
                'hard_timeout': stat.hard_timeout,
                'flags': stat.flags,
                'cookie': stat.cookie,
                'packet_count': stat.packet_count,
                'byte_count': stat.byte_count,
                'match': stat.match
            })

        self.flow_stats[dpid] = flows

    @set_ev_cls(ofp_event.EventOFPPortStatsReply, MAIN_DISPATCHER)
    def port_stats_reply_handler(self, ev):
        """Handle port statistics replies"""
        body = ev.msg.body
        dpid = ev.msg.datapath.id

        ports = []
        for stat in body:
            ports.append({
                'port_no': stat.port_no,
                'rx_packets': stat.rx_packets,
                'tx_packets': stat.tx_packets,
                'rx_bytes': stat.rx_bytes,
                'tx_bytes': stat.tx_bytes,
                'rx_dropped': stat.rx_dropped,
                'tx_dropped': stat.tx_dropped,
                'rx_errors': stat.rx_errors,
                'tx_errors': stat.tx_errors
            })

        self.port_stats[dpid] = ports

    def _save_captured_packets(self):
        """Save captured packets to file"""
        if not self.captured_packets:
            return

        try:
            timestamp = int(time.time())
            filename = os.path.join(self.data_dir, f'captured_packets_{timestamp}.json')

            with open(filename, 'w') as f:
                json.dump(self.captured_packets, f, indent=2)

            self.logger.info(f"Saved {len(self.captured_packets)} packets to {filename}")
        except Exception as e:
            self.logger.error(f"Error saving packets: {e}")
            import traceback
            self.logger.error(traceback.format_exc())

    def save_all_data(self):
        """Save all collected data before shutdown"""
        self._save_captured_packets()

        # Save flow stats
        if self.flow_stats:
            filename = os.path.join(self.data_dir, f'flow_stats_{int(time.time())}.json')
            with open(filename, 'w') as f:
                # Convert OFPMatch objects to dict for JSON serialization
                serializable_stats = {}
                for dpid, flows in self.flow_stats.items():
                    serializable_stats[dpid] = []
                    for flow in flows:
                        flow_copy = flow.copy()
                        flow_copy['match'] = str(flow['match'])
                        serializable_stats[dpid].append(flow_copy)
                json.dump(serializable_stats, f, indent=2)
