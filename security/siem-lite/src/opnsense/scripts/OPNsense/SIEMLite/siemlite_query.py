#!/usr/local/bin/python3

"""
SIEM-Lite: Query interface for the API controllers.
Handles event queries, alert queries, dashboard stats, alert management.

Copyright (C) 2024 Kuiper
"""

import base64
import json
import os
import sqlite3
import sys
from datetime import datetime, timedelta

DB_PATH = '/var/db/siemlite/siem.db'


def decode_params(raw):
    """Decode parameters from configd - handles JSON, quoted JSON, and base64."""
    if not raw or not isinstance(raw, str):
        return {}
    raw = raw.strip()
    # Try direct JSON
    try:
        result = json.loads(raw)
        if isinstance(result, dict):
            return result
    except (json.JSONDecodeError, ValueError):
        pass
    # Try stripping shell quotes
    for quote in ("'", '"'):
        if raw.startswith(quote) and raw.endswith(quote):
            try:
                result = json.loads(raw[1:-1])
                if isinstance(result, dict):
                    return result
            except (json.JSONDecodeError, ValueError):
                pass
    # Try base64
    try:
        decoded = base64.b64decode(raw).decode('utf-8')
        result = json.loads(decoded)
        if isinstance(result, dict):
            return result
    except Exception:
        pass
    return {}


def get_conn():
    if not os.path.exists(DB_PATH):
        print(json.dumps({'rows': [], 'total': 0}))
        sys.exit(0)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def time_range_to_seconds(tr):
    mapping = {'1h': 3600, '24h': 86400, '7d': 604800, '30d': 2592000}
    return mapping.get(tr, 86400)


def query_events(params):
    conn = get_conn()
    cursor = conn.cursor()
    p = decode_params(params)

    offset = int(p.get('offset', 0))
    limit = int(p.get('limit', 20))
    search = p.get('search', '')
    severity = p.get('severity', '')
    source = p.get('source', '')
    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(p.get('time_range', '24h')))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')

    where = ["timestamp >= ?"]
    args = [since_str]

    if search:
        where.append("(message LIKE ? OR src_ip LIKE ? OR dst_ip LIKE ?)")
        s = f"%{search}%"
        args.extend([s, s, s])
    if severity:
        where.append("severity = ?")
        args.append(severity)
    if source:
        where.append("source = ?")
        args.append(source)

    where_sql = " AND ".join(where)

    cursor.execute(f"SELECT COUNT(*) FROM events WHERE {where_sql}", args)
    total = cursor.fetchone()[0]

    cursor.execute(f"""
        SELECT id, timestamp, source, severity, src_ip, src_port,
               dst_ip, dst_port, protocol, interface, action, message,
               matched_rule, mitre_tactic, mitre_technique
        FROM events WHERE {where_sql}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """, args + [limit, offset])

    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    print(json.dumps({'rows': rows, 'total': total}))


def get_event(event_id):
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM events WHERE id = ?", (event_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        print(json.dumps(dict(row)))
    else:
        print(json.dumps({}))


def query_alerts(params):
    conn = get_conn()
    cursor = conn.cursor()
    p = decode_params(params)

    offset = int(p.get('offset', 0))
    limit = int(p.get('limit', 20))
    search = p.get('search', '')
    severity = p.get('severity', '')
    status = p.get('status', '')
    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(p.get('time_range', '24h')))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')

    where = ["timestamp >= ?"]
    args = [since_str]

    if search:
        where.append("(rule_title LIKE ? OR src_ip LIKE ? OR message LIKE ?)")
        s = f"%{search}%"
        args.extend([s, s, s])
    if severity:
        where.append("severity = ?")
        args.append(severity)
    if status:
        where.append("status = ?")
        args.append(status)

    where_sql = " AND ".join(where)

    cursor.execute(f"SELECT COUNT(*) FROM alerts WHERE {where_sql}", args)
    total = cursor.fetchone()[0]

    cursor.execute(f"""
        SELECT id, timestamp, severity, rule_title, source, src_ip,
               event_count, status, mitre, message
        FROM alerts WHERE {where_sql}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """, args + [limit, offset])

    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    print(json.dumps({'rows': rows, 'total': total}))


def ack_alert(alert_id):
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("UPDATE alerts SET status = 'acknowledged', updated_at = ? WHERE id = ? AND status = 'new'",
                  (datetime.utcnow().timestamp(), alert_id))
    conn.commit()
    affected = cursor.rowcount
    conn.close()
    print(json.dumps({'status': 'ok' if affected > 0 else 'not_found'}))


def close_alert(alert_id):
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("UPDATE alerts SET status = 'closed', updated_at = ? WHERE id = ? AND status != 'closed'",
                  (datetime.utcnow().timestamp(), alert_id))
    conn.commit()
    affected = cursor.rowcount
    conn.close()
    print(json.dumps({'status': 'ok' if affected > 0 else 'not_found'}))


def dashboard_stats(time_range='24h'):
    conn = get_conn()
    cursor = conn.cursor()
    since = datetime.utcnow() - timedelta(seconds=time_range_to_seconds(time_range))
    since_str = since.strftime('%Y-%m-%d %H:%M:%S')
    since_ts = since.timestamp()

    result = {}

    # Event & alert counts
    cursor.execute("SELECT COUNT(*) FROM events WHERE timestamp >= ?", (since_str,))
    result['total_events'] = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM alerts WHERE timestamp >= ? AND status != 'closed'", (since_str,))
    result['total_alerts'] = cursor.fetchone()[0]

    for sev in ('critical', 'high', 'medium', 'low'):
        cursor.execute("SELECT COUNT(*) FROM alerts WHERE severity = ? AND timestamp >= ? AND status != 'closed'",
                      (sev, since_str))
        result[f'{sev}_alerts'] = cursor.fetchone()[0]

    # Risk score
    cursor.execute("SELECT score FROM risk_history ORDER BY id DESC LIMIT 1")
    row = cursor.fetchone()
    result['risk_score'] = row[0] if row else 0

    # Top source IPs
    cursor.execute("""
        SELECT src_ip, COUNT(*) as cnt, country
        FROM events WHERE timestamp >= ? AND src_ip != ''
        GROUP BY src_ip ORDER BY cnt DESC LIMIT 10
    """, (since_str,))
    result['top_sources'] = [{'ip': r[0], 'count': r[1], 'country': r[2] or ''} for r in cursor.fetchall()]

    # Top destination IPs
    cursor.execute("""
        SELECT dst_ip, COUNT(*) as cnt
        FROM events WHERE timestamp >= ? AND dst_ip != ''
        GROUP BY dst_ip ORDER BY cnt DESC LIMIT 10
    """, (since_str,))
    result['top_destinations'] = [{'ip': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Top triggered rules
    cursor.execute("""
        SELECT rule_title, severity, COUNT(*) as cnt
        FROM alerts WHERE timestamp >= ?
        GROUP BY rule_title ORDER BY cnt DESC LIMIT 10
    """, (since_str,))
    result['top_rules'] = [{'title': r[0], 'severity': r[1], 'count': r[2]} for r in cursor.fetchall()]

    # Events timeline (hourly buckets)
    cursor.execute("""
        SELECT strftime('%Y-%m-%d %H:00', timestamp) as bucket,
               COUNT(*) as cnt,
               SUM(CASE WHEN severity IN ('critical','high') THEN 1 ELSE 0 END) as alert_cnt
        FROM events WHERE timestamp >= ?
        GROUP BY bucket ORDER BY bucket
    """, (since_str,))
    result['events_timeline'] = [
        {'label': r[0][-5:], 'count': r[1], 'has_alert': r[2] > 0}
        for r in cursor.fetchall()
    ]

    # Source distribution
    cursor.execute("""
        SELECT source, COUNT(*) as cnt
        FROM events WHERE timestamp >= ?
        GROUP BY source ORDER BY cnt DESC
    """, (since_str,))
    result['source_distribution'] = [{'source': r[0], 'count': r[1]} for r in cursor.fetchall()]

    # Geo data
    cursor.execute("""
        SELECT country, COUNT(*) as cnt
        FROM events WHERE timestamp >= ? AND country != '' AND country IS NOT NULL
        GROUP BY country ORDER BY cnt DESC LIMIT 10
    """, (since_str,))
    result['geo_data'] = [{'country': r[0], 'count': r[1]} for r in cursor.fetchall()]

    conn.close()
    print(json.dumps(result))


def risk_history():
    conn = get_conn()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT timestamp, score FROM risk_history
        ORDER BY id DESC LIMIT 288
    """)
    rows = [{'timestamp': r[0], 'score': r[1]} for r in cursor.fetchall()]
    conn.close()
    print(json.dumps({'history': list(reversed(rows))}))


def get_rules():
    """Get Sigma rules from OPNsense config XML."""
    try:
        import xml.etree.ElementTree as ET
        tree = ET.parse('/conf/config.xml')
        root = tree.getroot()
        rules_node = root.find('.//OPNsense/SIEMLite/sigmarule/rules')
        if rules_node is None:
            print(json.dumps([]))
            return

        rules = []
        for rule_node in rules_node:
            rule = {}
            rule['uuid'] = rule_node.tag if not rule_node.tag.startswith('rule') else rule_node.get('uuid', '')
            for child in rule_node:
                rule[child.tag] = child.text or ''
            rules.append(rule)

        print(json.dumps(rules))
    except Exception as ex:
        print(json.dumps([]))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'No command specified'}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == 'query-events':
        query_events(sys.argv[2] if len(sys.argv) > 2 else '{}')
    elif cmd == 'get-event':
        get_event(sys.argv[2] if len(sys.argv) > 2 else '0')
    elif cmd == 'query-alerts':
        query_alerts(sys.argv[2] if len(sys.argv) > 2 else '{}')
    elif cmd == 'ack-alert':
        ack_alert(sys.argv[2] if len(sys.argv) > 2 else '0')
    elif cmd == 'close-alert':
        close_alert(sys.argv[2] if len(sys.argv) > 2 else '0')
    elif cmd == 'dashboard-stats':
        dashboard_stats(sys.argv[2] if len(sys.argv) > 2 else '24h')
    elif cmd == 'risk-history':
        risk_history()
    elif cmd == 'get-rules':
        get_rules()
    else:
        print(json.dumps({'error': f'Unknown command: {cmd}'}))
