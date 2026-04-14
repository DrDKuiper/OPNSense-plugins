#!/usr/local/bin/python3

"""
SIEM-Lite: Packet capture, network inspection, and traffic analysis utility.
Provides active connections (pfctl), packet capture (tcpdump), ARP table,
DNS queries, interface listing, and traffic flow analysis.

Copyright (C) 2024 Kuiper
"""

import json
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta

DB_PATH = '/var/db/siemlite/siem.db'


def get_conn():
    if not os.path.exists(DB_PATH):
        return None
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def time_range_to_seconds(tr):
    mapping = {'1h': 3600, '24h': 86400, '7d': 604800, '30d': 2592000}
    return mapping.get(tr, 86400)


# ─── Active Connections (pfctl) ──────────────────────────────────────────────

def active_connections(params):
    p = json.loads(params) if isinstance(params, str) else params
    limit = int(p.get('limit', 200))
    filter_text = p.get('filter', '').lower()
    proto_filter = p.get('protocol', '').lower()
    state_filter = p.get('state', '').lower()

    try:
        result = subprocess.run(['pfctl', '-ss'], capture_output=True, text=True, timeout=10)
        lines = result.stdout.strip().split('\n')
    except Exception as ex:
        print(json.dumps({'rows': [], 'total': 0, 'error': str(ex)}))
        return

    connections = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        conn = parse_pf_state(line)
        if not conn:
            continue
        if filter_text and filter_text not in line.lower():
            continue
        if proto_filter and conn.get('proto', '').lower() != proto_filter:
            continue
        if state_filter and state_filter not in conn.get('state', '').lower():
            continue
        connections.append(conn)

    total = len(connections)
    print(json.dumps({'rows': connections[:limit], 'total': total}))


def parse_pf_state(line):
    """Parse a pfctl -ss state line into structured data."""
    conn = {'raw': line}
    parts = line.split()
    if len(parts) < 4:
        return None

    # Format: all|self <proto> <src> (<srcOS>)? -> <dst> <state>
    # or: all|self <proto> <src> <- <dst> <state>
    idx = 0

    # Skip interface/direction
    if parts[idx] in ('all', 'self') or '/' in parts[idx]:
        idx += 1

    # Protocol
    if idx < len(parts) and parts[idx].lower() in ('tcp', 'udp', 'icmp', 'igmp', 'esp', 'ah', 'gre', 'ipv6-icmp', 'carp'):
        conn['proto'] = parts[idx].upper()
        idx += 1
    else:
        conn['proto'] = '?'

    # Source
    if idx < len(parts):
        conn['src'] = parts[idx]
        src_parts = parts[idx].rsplit(':', 1)
        conn['src_ip'] = src_parts[0]
        conn['src_port'] = src_parts[1] if len(src_parts) > 1 else ''
        idx += 1

    # Direction arrow and destination
    if idx < len(parts) and parts[idx] in ('->', '<-', '<>'):
        conn['direction'] = parts[idx]
        idx += 1
        if idx < len(parts):
            conn['dst'] = parts[idx]
            dst_parts = parts[idx].rsplit(':', 1)
            conn['dst_ip'] = dst_parts[0]
            conn['dst_port'] = dst_parts[1] if len(dst_parts) > 1 else ''
            idx += 1

    # State
    state_parts = []
    while idx < len(parts):
        p = parts[idx]
        if ':' in p and any(s in p.upper() for s in [
            'ESTABLISHED', 'SYN_SENT', 'SYN_RCVD', 'FIN_WAIT', 'CLOSE_WAIT',
            'CLOSING', 'TIME_WAIT', 'CLOSED', 'SINGLE', 'MULTIPLE', 'NO_TRAFFIC',
            'LAST_ACK'
        ]):
            conn['state'] = p
            break
        idx += 1

    if 'state' not in conn:
        conn['state'] = ''

    # Extract TCP flags info
    if conn['proto'] == 'TCP' and conn.get('state'):
        state_pair = conn['state'].split(':')
        conn['client_state'] = state_pair[0] if len(state_pair) > 0 else ''
        conn['server_state'] = state_pair[1] if len(state_pair) > 1 else ''

    return conn


# ─── Packet Capture (tcpdump) ────────────────────────────────────────────────

def capture_packets(params):
    p = json.loads(params) if isinstance(params, str) else params
    interface = p.get('interface', 'em0')
    count = min(int(p.get('count', 25)), 100)
    bpf_filter = p.get('filter', '')

    # Validate interface
    if not re.match(r'^[a-zA-Z0-9_]+$', interface):
        print(json.dumps({'packets': [], 'total': 0, 'error': 'Invalid interface'}))
        return

    cmd = ['tcpdump', '-nn', '-tttt', '-vv', '-c', str(count), '-i', interface, '-l']
    if bpf_filter:
        if not re.match(r'^[a-zA-Z0-9\s\.\:\-\/\>\<\=\!\(\)\&\|and or not host port src dst net proto]+$', bpf_filter):
            print(json.dumps({'packets': [], 'total': 0, 'error': 'Invalid BPF filter'}))
            return
        cmd.extend(bpf_filter.split())

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        packets = parse_tcpdump_output(result.stdout)
        print(json.dumps({'packets': packets, 'total': len(packets)}))
    except subprocess.TimeoutExpired:
        print(json.dumps({'packets': [], 'total': 0, 'error': 'Capture timed out (30s)'}))
    except Exception as ex:
        print(json.dumps({'packets': [], 'total': 0, 'error': str(ex)}))


def parse_tcpdump_output(output):
    """Parse tcpdump -nn -tttt -vv output into structured packets."""
    packets = []
    current = None

    for line in output.split('\n'):
        line = line.rstrip()
        if not line:
            continue

        # New packet line starts with timestamp: 2026-04-14 01:41:08.123456
        ts_match = re.match(r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(.*)', line)
        if ts_match:
            if current:
                packets.append(current)
            current = {
                'timestamp': ts_match.group(1),
                'summary': ts_match.group(2),
                'details': [],
                'proto': '',
                'src': '',
                'dst': '',
                'flags': '',
                'length': 0,
                'info': ''
            }
            summary = ts_match.group(2)

            # Parse IP header: IP (tos 0x0, ttl 64, ...) src > dst: ...
            ip_match = re.match(r'IP\s*(?:\(([^)]+)\))?\s*(\S+)\s+>\s+(\S+?):\s*(.*)', summary)
            if ip_match:
                current['ip_header'] = ip_match.group(1) or ''
                current['src'] = ip_match.group(2)
                current['dst'] = ip_match.group(3)
                current['info'] = ip_match.group(4)
                current['proto'] = 'IP'

                # TCP flags
                tcp_flags = re.search(r'Flags\s+\[([^\]]+)\]', current['info'])
                if tcp_flags:
                    current['flags'] = tcp_flags.group(1)
                    current['proto'] = 'TCP'

                # Seq/Ack numbers
                seq_match = re.search(r'seq\s+(\d[\d:]*)', current['info'])
                if seq_match:
                    current['seq'] = seq_match.group(1)

                ack_match = re.search(r'ack\s+(\d+)', current['info'])
                if ack_match:
                    current['ack'] = ack_match.group(1)

                win_match = re.search(r'win\s+(\d+)', current['info'])
                if win_match:
                    current['window'] = win_match.group(1)

                # Length
                len_match = re.search(r'length\s+(\d+)', current['info'])
                if len_match:
                    current['length'] = int(len_match.group(1))

                # UDP detection
                if 'UDP' in summary or '.domain' in summary or re.search(r':\s+\d+\+', current['info']):
                    current['proto'] = 'UDP'

                # ICMP detection
                if 'ICMP' in summary:
                    current['proto'] = 'ICMP'

            # IPv6
            ip6_match = re.match(r'IP6\s+(\S+)\s+>\s+(\S+?):\s*(.*)', summary)
            if ip6_match:
                current['src'] = ip6_match.group(1)
                current['dst'] = ip6_match.group(2)
                current['info'] = ip6_match.group(3)
                current['proto'] = 'IPv6'

            # ARP
            if summary.startswith('ARP'):
                current['proto'] = 'ARP'
                current['info'] = summary

        elif current and line.startswith((' ', '\t')):
            # Continuation line (TCP options, payload, etc.)
            current['details'].append(line.strip())

            # Extract TCP options
            opts_match = re.search(r'options\s+\[([^\]]+)\]', line)
            if opts_match:
                current['tcp_options'] = opts_match.group(1)

            # Extract TTL, ID from IP header continuation
            ttl_match = re.search(r'ttl\s+(\d+)', line)
            if ttl_match:
                current['ttl'] = ttl_match.group(1)

            id_match = re.search(r'id\s+(\d+)', line)
            if id_match:
                current['ip_id'] = id_match.group(1)

    if current:
        packets.append(current)

    return packets


# ─── Interface Listing ───────────────────────────────────────────────────────

def list_interfaces():
    try:
        result = subprocess.run(['ifconfig', '-l'], capture_output=True, text=True, timeout=5)
        ifaces = result.stdout.strip().split()
        details = []
        for iface in ifaces:
            if iface.startswith(('lo', 'pflog', 'pfsync', 'enc', 'tun')):
                continue
            info = {'name': iface}
            try:
                r = subprocess.run(['ifconfig', iface], capture_output=True, text=True, timeout=5)
                out = r.stdout
                # Get status
                if 'status: active' in out:
                    info['status'] = 'active'
                elif 'status: no carrier' in out:
                    info['status'] = 'no carrier'
                else:
                    info['status'] = 'up' if 'UP' in out.split('\n')[0] else 'down'
                # IPv4
                ip_match = re.search(r'inet\s+(\S+)', out)
                if ip_match:
                    info['ip'] = ip_match.group(1)
                # MAC
                mac_match = re.search(r'ether\s+(\S+)', out)
                if mac_match:
                    info['mac'] = mac_match.group(1)
            except Exception:
                pass
            details.append(info)
        print(json.dumps({'interfaces': details}))
    except Exception as ex:
        print(json.dumps({'interfaces': [], 'error': str(ex)}))


# ─── DNS Queries (from Unbound) ──────────────────────────────────────────────

def dns_queries(limit=50):
    queries = []
    dns_log = '/var/log/resolver/latest.log'
    if not os.path.exists(dns_log):
        dns_log = '/var/log/resolver.log'
    if not os.path.exists(dns_log):
        print(json.dumps({'queries': []}))
        return

    try:
        result = subprocess.run(['tail', '-n', str(int(limit) * 3), dns_log],
                                capture_output=True, text=True, timeout=5)
        for line in result.stdout.strip().split('\n'):
            if not line.strip():
                continue
            # Parse Unbound log format
            q = parse_dns_line(line)
            if q:
                queries.append(q)

        queries = queries[-int(limit):]
        queries.reverse()
        print(json.dumps({'queries': queries}))
    except Exception as ex:
        print(json.dumps({'queries': [], 'error': str(ex)}))


def parse_dns_line(line):
    """Parse a DNS resolver log line."""
    # Unbound format: [timestamp] unbound[pid]: [id] query: name A IN client
    query_match = re.search(r'\]\s+\S+\[\d+\].*?(?:query|info).*?:\s+(\S+)\s+(\w+)\s+(\w+)\s*(?:from\s+)?(\S+)?', line)
    if query_match:
        return {
            'name': query_match.group(1),
            'type': query_match.group(2),
            'class': query_match.group(3),
            'client': query_match.group(4) or '',
            'raw': line[:200]
        }
    # Fallback: simpler parse
    parts = line.split()
    if len(parts) >= 3:
        return {'raw': line[:200], 'name': '', 'type': '', 'client': ''}
    return None


# ─── ARP Table ───────────────────────────────────────────────────────────────

def arp_table():
    try:
        result = subprocess.run(['arp', '-an'], capture_output=True, text=True, timeout=5)
        entries = []
        for line in result.stdout.strip().split('\n'):
            # Format: ? (192.168.1.1) at 00:11:22:33:44:55 on em0 expires in 1200 seconds [ethernet]
            m = re.match(r'\?\s+\((\S+)\)\s+at\s+(\S+)\s+on\s+(\S+)(.*)', line)
            if m:
                entry = {
                    'ip': m.group(1),
                    'mac': m.group(2),
                    'interface': m.group(3),
                    'info': m.group(4).strip()
                }
                # Vendor lookup placeholder
                if m.group(2) != '(incomplete)':
                    entries.append(entry)
        print(json.dumps({'entries': entries, 'total': len(entries)}))
    except Exception as ex:
        print(json.dumps({'entries': [], 'total': 0, 'error': str(ex)}))


# ─── Traffic Flow Analysis ───────────────────────────────────────────────────

def traffic_flows(params):
    conn = get_conn()
    if not conn:
        print(json.dumps({'rows': [], 'total': 0}))
        return

    p = json.loads(params) if isinstance(params, str) else params
    offset = int(p.get('offset', 0))
    limit = int(p.get('limit', 20))
    search = p.get('search', '')
    time_range = p.get('time_range', '24h')
    protocol = p.get('protocol', '')

    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(time_range))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')

    where = ["timestamp >= ?", "src_ip != ''", "dst_ip != ''"]
    args = [since_str]

    if search:
        where.append("(src_ip LIKE ? OR dst_ip LIKE ? OR message LIKE ?)")
        s = f"%{search}%"
        args.extend([s, s, s])
    if protocol:
        where.append("protocol = ?")
        args.append(protocol)

    where_sql = " AND ".join(where)
    cursor = conn.cursor()

    cursor.execute(f"""
        SELECT COUNT(*) FROM (
            SELECT src_ip, dst_ip, dst_port, protocol
            FROM events WHERE {where_sql}
            GROUP BY src_ip, dst_ip, dst_port, protocol
        )
    """, args)
    total = cursor.fetchone()[0]

    cursor.execute(f"""
        SELECT src_ip, dst_ip, dst_port, protocol,
               COUNT(*) as flow_count,
               MIN(timestamp) as first_seen,
               MAX(timestamp) as last_seen,
               GROUP_CONCAT(DISTINCT action) as actions,
               GROUP_CONCAT(DISTINCT severity) as severities,
               GROUP_CONCAT(DISTINCT interface) as interfaces
        FROM events WHERE {where_sql}
        GROUP BY src_ip, dst_ip, dst_port, protocol
        ORDER BY flow_count DESC
        LIMIT ? OFFSET ?
    """, args + [limit, offset])

    rows = []
    for r in cursor.fetchall():
        rows.append({
            'src_ip': r[0], 'dst_ip': r[1], 'dst_port': r[2] or '',
            'protocol': r[3] or '', 'count': r[4],
            'first_seen': r[5], 'last_seen': r[6],
            'actions': r[7] or '', 'severities': r[8] or '',
            'interfaces': r[9] or ''
        })

    conn.close()
    print(json.dumps({'rows': rows, 'total': total}))


def traffic_stats(time_range='24h'):
    conn = get_conn()
    if not conn:
        print(json.dumps({}))
        return

    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(time_range))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')
    cursor = conn.cursor()
    result = {}

    # Total flows
    cursor.execute("""
        SELECT COUNT(DISTINCT src_ip || '->' || dst_ip || ':' || COALESCE(dst_port,''))
        FROM events WHERE timestamp >= ? AND src_ip != '' AND dst_ip != ''
    """, (since_str,))
    result['total_flows'] = cursor.fetchone()[0]

    # Unique source IPs
    cursor.execute("SELECT COUNT(DISTINCT src_ip) FROM events WHERE timestamp >= ? AND src_ip != ''", (since_str,))
    result['unique_sources'] = cursor.fetchone()[0]

    # Unique destination IPs
    cursor.execute("SELECT COUNT(DISTINCT dst_ip) FROM events WHERE timestamp >= ? AND dst_ip != ''", (since_str,))
    result['unique_destinations'] = cursor.fetchone()[0]

    # Blocked events
    cursor.execute("SELECT COUNT(*) FROM events WHERE timestamp >= ? AND action = 'block'", (since_str,))
    result['blocked'] = cursor.fetchone()[0]

    # Allowed events
    cursor.execute("SELECT COUNT(*) FROM events WHERE timestamp >= ? AND action = 'pass'", (since_str,))
    result['allowed'] = cursor.fetchone()[0]

    # Protocol distribution
    cursor.execute("""
        SELECT protocol, COUNT(*) as cnt
        FROM events WHERE timestamp >= ? AND protocol != ''
        GROUP BY protocol ORDER BY cnt DESC LIMIT 10
    """, (since_str,))
    result['protocols'] = [{'name': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Action distribution
    cursor.execute("""
        SELECT action, COUNT(*) as cnt
        FROM events WHERE timestamp >= ? AND action != ''
        GROUP BY action ORDER BY cnt DESC
    """, (since_str,))
    result['actions'] = [{'name': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Interface distribution
    cursor.execute("""
        SELECT interface, COUNT(*) as cnt
        FROM events WHERE timestamp >= ? AND interface != ''
        GROUP BY interface ORDER BY cnt DESC
    """, (since_str,))
    result['interfaces'] = [{'name': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Timeline (hourly)
    cursor.execute("""
        SELECT strftime('%Y-%m-%d %H:00', timestamp) as bucket,
               COUNT(*) as total,
               SUM(CASE WHEN action = 'block' THEN 1 ELSE 0 END) as blocked,
               SUM(CASE WHEN action = 'pass' THEN 1 ELSE 0 END) as allowed
        FROM events WHERE timestamp >= ?
        GROUP BY bucket ORDER BY bucket
    """, (since_str,))
    result['timeline'] = [{
        'label': r[0][-5:], 'total': r[1], 'blocked': r[2], 'allowed': r[3]
    } for r in cursor.fetchall()]

    conn.close()
    print(json.dumps(result))


def traffic_ports(time_range='24h'):
    conn = get_conn()
    if not conn:
        print(json.dumps({'ports': []}))
        return

    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(time_range))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')
    cursor = conn.cursor()

    well_known = {
        '22': 'SSH', '23': 'Telnet', '25': 'SMTP', '53': 'DNS', '67': 'DHCP',
        '68': 'DHCP', '80': 'HTTP', '110': 'POP3', '123': 'NTP', '143': 'IMAP',
        '161': 'SNMP', '443': 'HTTPS', '465': 'SMTPS', '500': 'IKE', '587': 'Submission',
        '993': 'IMAPS', '995': 'POP3S', '1194': 'OpenVPN', '1723': 'PPTP',
        '3306': 'MySQL', '3389': 'RDP', '5060': 'SIP', '5432': 'PostgreSQL',
        '5900': 'VNC', '8080': 'HTTP-Alt', '8443': 'HTTPS-Alt', '8883': 'MQTT-TLS',
        '51820': 'WireGuard'
    }

    cursor.execute("""
        SELECT dst_port, COUNT(*) as cnt,
               COUNT(DISTINCT src_ip) as unique_sources,
               GROUP_CONCAT(DISTINCT action) as actions
        FROM events WHERE timestamp >= ? AND dst_port != '' AND dst_port IS NOT NULL
        GROUP BY dst_port ORDER BY cnt DESC LIMIT 25
    """, (since_str,))

    ports = []
    for r in cursor.fetchall():
        port = r[0]
        ports.append({
            'port': port,
            'service': well_known.get(str(port), ''),
            'count': r[1],
            'unique_sources': r[2],
            'actions': r[3] or ''
        })

    conn.close()
    print(json.dumps({'ports': ports}))


# ─── Topology Data ───────────────────────────────────────────────────────────

def topology_data(time_range='24h', min_count='2'):
    conn = get_conn()
    if not conn:
        print(json.dumps({'nodes': [], 'edges': []}))
        return

    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(time_range))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')
    min_c = int(min_count)
    cursor = conn.cursor()

    # Get edges (connections between IPs)
    cursor.execute("""
        SELECT src_ip, dst_ip, COUNT(*) as cnt,
               GROUP_CONCAT(DISTINCT protocol) as protocols,
               GROUP_CONCAT(DISTINCT action) as actions,
               MAX(CASE WHEN severity='critical' THEN 4
                        WHEN severity='high' THEN 3
                        WHEN severity='medium' THEN 2
                        WHEN severity='low' THEN 1
                        ELSE 0 END) as max_severity
        FROM events WHERE timestamp >= ? AND src_ip != '' AND dst_ip != ''
        GROUP BY src_ip, dst_ip
        HAVING cnt >= ?
        ORDER BY cnt DESC
        LIMIT 200
    """, (since_str, min_c))

    edges = []
    node_set = {}
    for r in cursor.fetchall():
        src, dst = r[0], r[1]
        edges.append({
            'source': src, 'target': dst, 'count': r[2],
            'protocols': r[3] or '', 'actions': r[4] or '',
            'severity': r[5]
        })
        node_set[src] = node_set.get(src, 0) + r[2]
        node_set[dst] = node_set.get(dst, 0) + r[2]

    # Build nodes with metadata
    nodes = []
    for ip, event_count in node_set.items():
        node = {'id': ip, 'count': event_count, 'type': 'external'}

        # Classify node type
        if ip.startswith(('192.168.', '10.', '172.16.', '172.17.', '172.18.', '172.19.',
                          '172.20.', '172.21.', '172.22.', '172.23.', '172.24.', '172.25.',
                          '172.26.', '172.27.', '172.28.', '172.29.', '172.30.', '172.31.')):
            node['type'] = 'internal'
        elif ip.startswith('127.'):
            node['type'] = 'localhost'

        # Max severity for this IP
        cursor.execute("""
            SELECT MAX(CASE WHEN severity='critical' THEN 4
                            WHEN severity='high' THEN 3
                            WHEN severity='medium' THEN 2
                            WHEN severity='low' THEN 1
                            ELSE 0 END) as sev
            FROM events WHERE timestamp >= ? AND (src_ip = ? OR dst_ip = ?)
        """, (since_str, ip, ip))
        sev_row = cursor.fetchone()
        node['severity'] = sev_row[0] if sev_row and sev_row[0] else 0

        nodes.append(node)

    conn.close()
    print(json.dumps({'nodes': nodes, 'edges': edges}))


def node_detail(ip):
    conn = get_conn()
    if not conn:
        print(json.dumps({}))
        return

    cursor = conn.cursor()
    result = {'ip': ip}

    # Recent events
    cursor.execute("""
        SELECT timestamp, source, severity, action, message
        FROM events WHERE src_ip = ? OR dst_ip = ?
        ORDER BY created_at DESC LIMIT 20
    """, (ip, ip))
    result['recent_events'] = [dict(r) for r in cursor.fetchall()]

    # Connected peers
    cursor.execute("""
        SELECT dst_ip as peer, COUNT(*) as cnt
        FROM events WHERE src_ip = ? AND dst_ip != ''
        GROUP BY dst_ip ORDER BY cnt DESC LIMIT 10
    """, (ip,))
    result['outbound_peers'] = [{'ip': r[0], 'count': r[1]} for r in cursor.fetchall()]

    cursor.execute("""
        SELECT src_ip as peer, COUNT(*) as cnt
        FROM events WHERE dst_ip = ? AND src_ip != ''
        GROUP BY src_ip ORDER BY cnt DESC LIMIT 10
    """, (ip,))
    result['inbound_peers'] = [{'ip': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Port usage
    cursor.execute("""
        SELECT dst_port, COUNT(*) as cnt
        FROM events WHERE src_ip = ? AND dst_port != ''
        GROUP BY dst_port ORDER BY cnt DESC LIMIT 10
    """, (ip,))
    result['ports_accessed'] = [{'port': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Severity breakdown
    cursor.execute("""
        SELECT severity, COUNT(*) as cnt
        FROM events WHERE src_ip = ? OR dst_ip = ?
        GROUP BY severity
    """, (ip, ip))
    result['severity_breakdown'] = {r[0]: r[1] for r in cursor.fetchall()}

    conn.close()
    print(json.dumps(result))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'No command specified'}))
        sys.exit(1)

    cmd = sys.argv[1]
    arg = sys.argv[2] if len(sys.argv) > 2 else '{}'
    arg2 = sys.argv[3] if len(sys.argv) > 3 else ''

    if cmd == 'active-connections':
        active_connections(arg)
    elif cmd == 'capture-packets':
        capture_packets(arg)
    elif cmd == 'list-interfaces':
        list_interfaces()
    elif cmd == 'dns-queries':
        dns_queries(arg)
    elif cmd == 'arp-table':
        arp_table()
    elif cmd == 'traffic-flows':
        traffic_flows(arg)
    elif cmd == 'traffic-stats':
        traffic_stats(arg)
    elif cmd == 'traffic-ports':
        traffic_ports(arg)
    elif cmd == 'topology-data':
        topology_data(arg, arg2 if arg2 else '2')
    elif cmd == 'node-detail':
        node_detail(arg)
    else:
        print(json.dumps({'error': f'Unknown command: {cmd}'}))
