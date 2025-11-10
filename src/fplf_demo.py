#!/usr/bin/env python3
"""
Standalone FPLF (Fill Preferred Link First) Algorithm Demo
Uses Dijkstra's algorithm to compute priority-based routes

No Mininet, no Ryu - just pure algorithm demonstration
"""

import networkx as nx


class FPLFRouter:
    def __init__(self):
        self.topology = nx.Graph()
        self.link_loads = {}

        # Traffic priorities
        self.priorities = {
            'VIDEO': 4,    # Highest priority
            'SSH': 3,
            'HTTP': 2,
            'FTP': 1,
            'DEFAULT': 0   # Lowest priority
        }

    def add_link(self, src, dst, capacity=100):
        """Add a bidirectional link"""
        self.topology.add_edge(src, dst, capacity=capacity)
        self.link_loads[(src, dst)] = 0
        self.link_loads[(dst, src)] = 0

    def compute_fplf_path(self, src, dst, traffic_type='DEFAULT'):
        """
        Compute path using FPLF with Dijkstra's algorithm

        FPLF Algorithm:
        - Weight = link_load × (5 - priority) + 1
        - Higher priority traffic → lower weight multiplier → prefers less-loaded links more strongly
        - Lower priority traffic → higher weight multiplier → less sensitive to load
        """
        if src == dst:
            return [src]

        priority = self.priorities.get(traffic_type, 0)

        # Set edge weights based on FPLF formula
        for u, v in self.topology.edges():
            load = self.link_loads.get((u, v), 0)
            # FPLF weight: higher priority → stronger preference for low-load links
            weight = load * (5 - priority) + 1
            self.topology[u][v]['weight'] = weight

        try:
            # Use Dijkstra's algorithm
            path = nx.dijkstra_path(self.topology, src, dst, weight='weight')

            # Update link loads for chosen path
            for i in range(len(path) - 1):
                link = (path[i], path[i+1])
                self.link_loads[link] = self.link_loads.get(link, 0) + 10  # Add 10 units of load

            return path
        except nx.NetworkXNoPath:
            return None

    def print_topology(self):
        """Print current topology state"""
        print("\n" + "="*60)
        print("NETWORK TOPOLOGY")
        print("="*60)
        print(f"Nodes: {list(self.topology.nodes())}")
        print(f"Links:")
        for u, v in self.topology.edges():
            load_uv = self.link_loads.get((u, v), 0)
            print(f"  {u} <-> {v}: load={load_uv}")
        print("="*60 + "\n")


def demo_linear_topology():
    """Demo: Linear topology s1 -- s2 -- s3"""
    print("\n" + "#"*60)
    print("# FPLF Demo: Linear Topology (s1 -- s2 -- s3)")
    print("#"*60)

    router = FPLFRouter()

    # Build topology
    router.add_link('s1', 's2')
    router.add_link('s2', 's3')

    router.print_topology()

    # Compute routes for different traffic types
    traffic_types = ['VIDEO', 'SSH', 'HTTP', 'FTP']

    print("COMPUTING FPLF ROUTES:")
    print("-" * 60)

    for traffic_type in traffic_types:
        path = router.compute_fplf_path('s1', 's3', traffic_type)
        priority = router.priorities[traffic_type]
        print(f"{traffic_type:8} (priority={priority}): {' -> '.join(path)}")

    router.print_topology()


def demo_mesh_topology():
    """Demo: Mesh topology with multiple paths"""
    print("\n" + "#"*60)
    print("# FPLF Demo: Mesh Topology with Multiple Paths")
    print("#"*60)
    print("""
    Topology:
           s2
          /  \\
        s1    s4
          \\  /
           s3
    """)

    router = FPLFRouter()

    # Build mesh topology
    router.add_link('s1', 's2')
    router.add_link('s1', 's3')
    router.add_link('s2', 's4')
    router.add_link('s3', 's4')

    router.print_topology()

    # Simulate multiple flows
    flows = [
        ('s1', 's4', 'VIDEO'),
        ('s1', 's4', 'VIDEO'),
        ('s1', 's4', 'HTTP'),
        ('s1', 's4', 'FTP'),
        ('s1', 's4', 'SSH'),
    ]

    print("COMPUTING FPLF ROUTES (sequential flows):")
    print("-" * 60)

    for i, (src, dst, traffic_type) in enumerate(flows, 1):
        path = router.compute_fplf_path(src, dst, traffic_type)
        priority = router.priorities[traffic_type]
        print(f"Flow {i} - {traffic_type:8} (priority={priority}): {' -> '.join(path)}")

    router.print_topology()


def demo_custom_topology():
    """Demo: Custom topology matching the ML-SDN setup"""
    print("\n" + "#"*60)
    print("# FPLF Demo: Custom 3-Switch Topology")
    print("#"*60)
    print("""
    Topology (matching custom_topo.py):
        h1,h2,h3 -- s1 -- s2 -- h4,h5,h6
                           |
                          s3 -- h7,h8,h9
    """)

    router = FPLFRouter()

    # Build topology (switches only, hosts are implicit)
    router.add_link('s1', 's2')
    router.add_link('s2', 's3')

    router.print_topology()

    # Simulate traffic between different switch domains
    scenarios = [
        ("Hosts on s1 → Hosts on s2", 's1', 's2'),
        ("Hosts on s1 → Hosts on s3", 's1', 's3'),
        ("Hosts on s2 → Hosts on s3", 's2', 's3'),
    ]

    print("COMPUTING FPLF ROUTES FOR DIFFERENT SCENARIOS:")
    print("-" * 60)

    for scenario_name, src, dst in scenarios:
        print(f"\n{scenario_name}:")
        for traffic_type in ['VIDEO', 'HTTP', 'FTP']:
            path = router.compute_fplf_path(src, dst, traffic_type)
            priority = router.priorities[traffic_type]
            print(f"  {traffic_type:8} (priority={priority}): {' -> '.join(path)}")

    router.print_topology()


if __name__ == '__main__':
    print("\n" + "="*60)
    print(" FPLF (Fill Preferred Link First) Algorithm Demonstration")
    print(" Using Dijkstra's Algorithm with Priority-Based Weighting")
    print("="*60)

    # Run all demos
    demo_linear_topology()
    demo_mesh_topology()
    demo_custom_topology()

    print("\n" + "="*60)
    print(" KEY INSIGHTS:")
    print("="*60)
    print("""
1. FPLF Weight Formula: weight = link_load × (5 - priority) + 1

2. Higher priority traffic (VIDEO, priority=4):
   - Weight multiplier = (5-4) = 1
   - Strongly prefers less-loaded links

3. Lower priority traffic (FTP, priority=1):
   - Weight multiplier = (5-1) = 4
   - Less sensitive to link load

4. As links become loaded, FPLF dynamically routes new flows
   to less-loaded paths, "filling" preferred links first.

5. This ensures high-priority traffic gets the best paths while
   lower-priority traffic adapts to available capacity.
""")
    print("="*60 + "\n")
