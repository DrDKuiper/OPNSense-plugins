{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<style>
    .pi-tabs { border-bottom: 2px solid rgba(128,128,128,0.2); margin-bottom: 15px; }
    .pi-tabs .nav-tabs > li > a {
        border: none;
        color: inherit;
        opacity: 0.6;
        padding: 10px 18px;
    }
    .pi-tabs .nav-tabs > li.active > a,
    .pi-tabs .nav-tabs > li > a:hover {
        opacity: 1;
        border: none;
        border-bottom: 2px solid #5bc0de;
        background: transparent;
        color: inherit;
    }
    .capture-form {
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 8px;
        padding: 15px;
        margin-bottom: 15px;
        display: flex;
        gap: 10px;
        align-items: end;
        flex-wrap: wrap;
    }
    .capture-form .form-group { margin-bottom: 0; }
    .capture-form label { font-size: 0.8em; opacity: 0.7; display: block; margin-bottom: 3px; }
    .capture-form select, .capture-form input {
        padding: 6px 10px;
        border: 1px solid rgba(128,128,128,0.3);
        border-radius: 4px;
        background: transparent;
        color: inherit;
    }
    .capture-form select option { background-color: #2b2b2b; color: #e0e0e0; }
    .packet-card {
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 6px;
        margin-bottom: 8px;
        overflow: hidden;
    }
    .packet-header {
        padding: 8px 12px;
        cursor: pointer;
        display: flex;
        align-items: center;
        gap: 10px;
        font-family: 'Consolas', 'Monaco', monospace;
        font-size: 0.85em;
    }
    .packet-header:hover { background: rgba(128,128,128,0.08); }
    .packet-body {
        display: none;
        padding: 12px;
        border-top: 1px solid rgba(128,128,128,0.15);
        font-family: 'Consolas', 'Monaco', monospace;
        font-size: 0.82em;
    }
    .packet-body.show { display: block; }
    .proto-badge {
        display: inline-block;
        padding: 1px 8px;
        border-radius: 10px;
        font-size: 0.75em;
        font-weight: 700;
        min-width: 40px;
        text-align: center;
    }
    .proto-badge.TCP { background: rgba(52,152,219,0.2); color: #3498db; }
    .proto-badge.UDP { background: rgba(46,204,113,0.2); color: #2ecc71; }
    .proto-badge.ICMP { background: rgba(155,89,182,0.2); color: #9b59b6; }
    .proto-badge.ARP { background: rgba(243,156,18,0.2); color: #f39c12; }
    .proto-badge.IP,
    .proto-badge.IPv6 { background: rgba(149,165,166,0.2); color: #95a5a6; }
    .tcp-flags {
        display: inline-flex;
        gap: 3px;
    }
    .tcp-flag {
        display: inline-block;
        width: 22px;
        height: 22px;
        line-height: 22px;
        text-align: center;
        font-size: 0.7em;
        font-weight: 700;
        border-radius: 3px;
        background: rgba(128,128,128,0.15);
        opacity: 0.3;
    }
    .tcp-flag.active {
        opacity: 1;
    }
    .tcp-flag.SYN.active { background: rgba(46,204,113,0.3); color: #2ecc71; }
    .tcp-flag.ACK.active { background: rgba(52,152,219,0.3); color: #3498db; }
    .tcp-flag.FIN.active { background: rgba(243,156,18,0.3); color: #f39c12; }
    .tcp-flag.RST.active { background: rgba(231,76,60,0.3); color: #e74c3c; }
    .tcp-flag.PSH.active { background: rgba(155,89,182,0.3); color: #9b59b6; }
    .tcp-flag.URG.active { background: rgba(230,126,34,0.3); color: #e67e22; }
    .detail-row { display: flex; gap: 20px; margin: 3px 0; }
    .detail-label { opacity: 0.6; min-width: 100px; }
    .conn-state {
        display: inline-block;
        padding: 1px 8px;
        border-radius: 10px;
        font-size: 0.75em;
        font-weight: 600;
    }
    .conn-state.established { background: rgba(46,204,113,0.2); color: #2ecc71; }
    .conn-state.syn_sent, .conn-state.syn_rcvd { background: rgba(243,156,18,0.2); color: #f39c12; }
    .conn-state.fin_wait, .conn-state.close_wait, .conn-state.closing, .conn-state.time_wait,
    .conn-state.last_ack, .conn-state.closed { background: rgba(231,76,60,0.2); color: #e74c3c; }
    .conn-state.single, .conn-state.multiple { background: rgba(52,152,219,0.2); color: #3498db; }
    .filter-bar {
        padding: 12px 15px;
        border-radius: 6px;
        margin-bottom: 15px;
        display: flex;
        gap: 10px;
        align-items: center;
        flex-wrap: wrap;
        border: 1px solid rgba(128,128,128,0.2);
    }
    .filter-bar select, .filter-bar input {
        padding: 5px 10px;
        border: 1px solid rgba(128,128,128,0.3);
        border-radius: 4px;
        background: transparent;
        color: inherit;
    }
    .filter-bar select option { background-color: #2b2b2b; color: #e0e0e0; }
    .arp-table td, .dns-table td { font-family: 'Consolas', 'Monaco', monospace; font-size: 0.85em; }
    .spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid rgba(128,128,128,0.3);
        border-top-color: #5bc0de; border-radius: 50%; animation: spin 0.6s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .capture-status { padding: 10px 15px; border-radius: 6px; margin-bottom: 15px;
        border: 1px solid rgba(91,192,222,0.3); display: none; }
</style>

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-search"></i> {{ lang._('Packet Inspector') }}
</h2>

<div class="pi-tabs">
    <ul class="nav nav-tabs" role="tablist">
        <li role="presentation" class="active"><a href="#tab-connections" role="tab" data-toggle="tab"><i class="fa fa-plug"></i> {{ lang._('Active Connections') }}</a></li>
        <li role="presentation"><a href="#tab-capture" role="tab" data-toggle="tab"><i class="fa fa-download"></i> {{ lang._('Packet Capture') }}</a></li>
        <li role="presentation"><a href="#tab-arp" role="tab" data-toggle="tab"><i class="fa fa-sitemap"></i> {{ lang._('ARP Table') }}</a></li>
        <li role="presentation"><a href="#tab-dns" role="tab" data-toggle="tab"><i class="fa fa-globe"></i> {{ lang._('DNS Queries') }}</a></li>
    </ul>
</div>

<div class="tab-content">
    <!-- Active Connections Tab -->
    <div role="tabpanel" class="tab-pane active" id="tab-connections">
        <div class="filter-bar">
            <select id="conn-proto">
                <option value="">All Protocols</option>
                <option value="tcp">TCP</option>
                <option value="udp">UDP</option>
                <option value="icmp">ICMP</option>
            </select>
            <select id="conn-state">
                <option value="">All States</option>
                <option value="established">ESTABLISHED</option>
                <option value="syn_sent">SYN_SENT</option>
                <option value="fin_wait">FIN_WAIT</option>
                <option value="time_wait">TIME_WAIT</option>
                <option value="closed">CLOSED</option>
                <option value="single">SINGLE</option>
                <option value="no_traffic">NO_TRAFFIC</option>
            </select>
            <input type="text" id="conn-filter" placeholder="Filter by IP or port..." style="min-width:200px"/>
            <button class="btn btn-primary btn-sm" id="btn-conn-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
            <span id="conn-count" style="opacity:0.6; margin-left:auto;"></span>
        </div>
        <table id="grid-connections" class="table table-condensed table-hover table-striped">
            <thead>
                <tr>
                    <th style="width:70px">{{ lang._('Proto') }}</th>
                    <th style="width:200px">{{ lang._('Source') }}</th>
                    <th style="width:40px">{{ lang._('Dir') }}</th>
                    <th style="width:200px">{{ lang._('Destination') }}</th>
                    <th>{{ lang._('State') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>

    <!-- Packet Capture Tab -->
    <div role="tabpanel" class="tab-pane" id="tab-capture">
        <div class="capture-form">
            <div class="form-group">
                <label>{{ lang._('Interface') }}</label>
                <select id="cap-interface"></select>
            </div>
            <div class="form-group">
                <label>{{ lang._('Packet Count') }}</label>
                <select id="cap-count">
                    <option value="10">10</option>
                    <option value="25" selected>25</option>
                    <option value="50">50</option>
                    <option value="100">100</option>
                </select>
            </div>
            <div class="form-group">
                <label>{{ lang._('BPF Filter') }}</label>
                <input type="text" id="cap-filter" placeholder="e.g. tcp port 443 or host 10.0.0.1" style="min-width:300px"/>
            </div>
            <button class="btn btn-success btn-sm" id="btn-capture" style="margin-bottom:0">
                <i class="fa fa-play"></i> {{ lang._('Start Capture') }}
            </button>
        </div>

        <div class="capture-status" id="capture-status">
            <span class="spinner"></span> {{ lang._('Capturing packets... Please wait.') }}
        </div>

        <div id="packet-results"></div>
    </div>

    <!-- ARP Table Tab -->
    <div role="tabpanel" class="tab-pane" id="tab-arp">
        <div style="margin-bottom:10px;">
            <button class="btn btn-primary btn-sm" id="btn-arp-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
            <span id="arp-count" style="opacity:0.6; margin-left:10px;"></span>
        </div>
        <table class="table table-condensed table-hover table-striped arp-table" id="arp-table">
            <thead>
                <tr>
                    <th>{{ lang._('IP Address') }}</th>
                    <th>{{ lang._('MAC Address') }}</th>
                    <th>{{ lang._('Interface') }}</th>
                    <th>{{ lang._('Info') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>

    <!-- DNS Queries Tab -->
    <div role="tabpanel" class="tab-pane" id="tab-dns">
        <div style="margin-bottom:10px;">
            <button class="btn btn-primary btn-sm" id="btn-dns-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
            <span id="dns-count" style="opacity:0.6; margin-left:10px;"></span>
        </div>
        <table class="table table-condensed table-hover table-striped dns-table" id="dns-table">
            <thead>
                <tr>
                    <th>{{ lang._('Query Name') }}</th>
                    <th>{{ lang._('Type') }}</th>
                    <th>{{ lang._('Client') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
</div>

<script>
$(document).ready(function() {
    // ─── Active Connections ──────────────────────────────────────────
    function loadConnections() {
        $.post('/api/siemlite/packetinspector/connections', {
            searchPhrase: $('#conn-filter').val(),
            protocol: $('#conn-proto').val(),
            state: $('#conn-state').val(),
            rowCount: 200
        }, function(data) {
            var rows = data.rows || [];
            $('#conn-count').text(rows.length + ' of ' + (data.total || 0) + ' connections');
            var $tbody = $('#grid-connections tbody').empty();
            $.each(rows, function(i, c) {
                var stateClass = (c.state || '').split(':')[0].toLowerCase().replace(/ /g,'_');
                $tbody.append(
                    '<tr>' +
                    '<td><span class="proto-badge ' + (c.proto||'') + '">' + (c.proto||'?') + '</span></td>' +
                    '<td style="font-family:monospace;font-size:0.85em">' + $('<span>').text(c.src||'').html() + '</td>' +
                    '<td>' + (c.direction||'->') + '</td>' +
                    '<td style="font-family:monospace;font-size:0.85em">' + $('<span>').text(c.dst||'').html() + '</td>' +
                    '<td><span class="conn-state ' + stateClass + '">' + $('<span>').text(c.state||'').html() + '</span></td>' +
                    '</tr>'
                );
            });
        });
    }

    $('#btn-conn-refresh').click(loadConnections);
    $('#conn-proto, #conn-state').change(loadConnections);
    var connTimer;
    $('#conn-filter').on('input', function() {
        clearTimeout(connTimer);
        connTimer = setTimeout(loadConnections, 400);
    });

    // ─── Packet Capture ─────────────────────────────────────────────
    // Load interfaces
    $.get('/api/siemlite/packetinspector/interfaces', function(data) {
        var $sel = $('#cap-interface').empty();
        $.each(data.interfaces || [], function(i, iface) {
            var label = iface.name;
            if (iface.ip) label += ' (' + iface.ip + ')';
            if (iface.status) label += ' [' + iface.status + ']';
            $sel.append('<option value="' + iface.name + '">' + label + '</option>');
        });
    });

    function renderTcpFlags(flagStr) {
        // tcpdump flags: S=SYN, .=ACK, F=FIN, R=RST, P=PSH, U=URG
        var flags = {S:'SYN', '.':'ACK', F:'FIN', R:'RST', P:'PSH', U:'URG'};
        var active = {};
        if (flagStr) {
            for (var c of flagStr) {
                if (flags[c]) active[flags[c]] = true;
            }
        }
        var html = '<div class="tcp-flags">';
        $.each(['SYN','ACK','FIN','RST','PSH','URG'], function(i, f) {
            html += '<span class="tcp-flag ' + f + (active[f] ? ' active' : '') + '" title="' + f + '">' + f[0] + '</span>';
        });
        html += '</div>';
        return html;
    }

    $('#btn-capture').click(function() {
        var $btn = $(this);
        $btn.prop('disabled', true).html('<span class="spinner"></span> Capturing...');
        $('#capture-status').show();
        $('#packet-results').empty();

        $.post('/api/siemlite/packetinspector/capture', {
            interface: $('#cap-interface').val(),
            count: $('#cap-count').val(),
            filter: $('#cap-filter').val()
        }, function(data) {
            $btn.prop('disabled', false).html('<i class="fa fa-play"></i> Start Capture');
            $('#capture-status').hide();

            if (data.error) {
                $('#packet-results').html('<div class="alert alert-danger"><i class="fa fa-exclamation-triangle"></i> ' +
                    $('<span>').text(data.error).html() + '</div>');
                return;
            }

            var packets = data.packets || [];
            if (!packets.length) {
                $('#packet-results').html('<div class="alert alert-info">No packets captured.</div>');
                return;
            }

            var $results = $('#packet-results');
            $.each(packets, function(i, pkt) {
                var flagsHtml = (pkt.proto === 'TCP' && pkt.flags) ? renderTcpFlags(pkt.flags) : '';
                var $card = $(
                    '<div class="packet-card">' +
                    '<div class="packet-header" data-idx="' + i + '">' +
                    '<span style="opacity:0.4;min-width:30px">#' + (i+1) + '</span>' +
                    '<span class="proto-badge ' + (pkt.proto||'IP') + '">' + (pkt.proto||'IP') + '</span>' +
                    '<span style="min-width:180px">' + $('<span>').text(pkt.src||'').html() + '</span>' +
                    '<i class="fa fa-long-arrow-right" style="opacity:0.4"></i>' +
                    '<span style="min-width:180px">' + $('<span>').text(pkt.dst||'').html() + '</span>' +
                    flagsHtml +
                    '<span style="margin-left:auto;opacity:0.5;font-size:0.85em">' +
                    (pkt.length ? pkt.length + ' bytes' : '') + '</span>' +
                    '</div>' +
                    '<div class="packet-body" id="pkt-body-' + i + '"></div>' +
                    '</div>'
                );

                // Build detail body
                var $body = $card.find('.packet-body');
                var details = '<div class="detail-row"><span class="detail-label">Timestamp</span><span>' +
                    $('<span>').text(pkt.timestamp||'').html() + '</span></div>';
                if (pkt.ip_header) {
                    details += '<div class="detail-row"><span class="detail-label">IP Header</span><span>' +
                        $('<span>').text(pkt.ip_header).html() + '</span></div>';
                }
                if (pkt.ttl) {
                    details += '<div class="detail-row"><span class="detail-label">TTL</span><span>' + pkt.ttl + '</span></div>';
                }
                if (pkt.ip_id) {
                    details += '<div class="detail-row"><span class="detail-label">IP ID</span><span>' + pkt.ip_id + '</span></div>';
                }
                if (pkt.seq) {
                    details += '<div class="detail-row"><span class="detail-label">Seq</span><span>' + pkt.seq + '</span></div>';
                }
                if (pkt.ack) {
                    details += '<div class="detail-row"><span class="detail-label">Ack</span><span>' + pkt.ack + '</span></div>';
                }
                if (pkt.window) {
                    details += '<div class="detail-row"><span class="detail-label">Window</span><span>' + pkt.window + '</span></div>';
                }
                if (pkt.tcp_options) {
                    details += '<div class="detail-row"><span class="detail-label">TCP Options</span><span>' +
                        $('<span>').text(pkt.tcp_options).html() + '</span></div>';
                }
                if (pkt.flags) {
                    details += '<div class="detail-row"><span class="detail-label">TCP Flags</span>' + renderTcpFlags(pkt.flags) + '</div>';
                }
                if (pkt.details && pkt.details.length) {
                    details += '<div style="margin-top:8px;opacity:0.6;">Raw Details:</div>' +
                        '<pre style="font-size:0.8em;max-height:200px;overflow:auto;background:rgba(0,0,0,0.2);padding:8px;border-radius:4px">' +
                        $('<span>').text(pkt.details.join('\n')).html() + '</pre>';
                }
                details += '<div class="detail-row" style="margin-top:5px"><span class="detail-label">Summary</span><span style="word-break:break-all">' +
                    $('<span>').text(pkt.summary||'').html() + '</span></div>';
                $body.html(details);
                $results.append($card);
            });

            // Toggle packet details
            $(document).on('click', '.packet-header', function() {
                var idx = $(this).data('idx');
                $('#pkt-body-' + idx).toggleClass('show');
            });
        }).fail(function() {
            $btn.prop('disabled', false).html('<i class="fa fa-play"></i> Start Capture');
            $('#capture-status').hide();
            $('#packet-results').html('<div class="alert alert-danger">Capture request failed.</div>');
        });
    });

    // ─── ARP Table ──────────────────────────────────────────────────
    function loadArp() {
        $.get('/api/siemlite/packetinspector/arptable', function(data) {
            var entries = data.entries || [];
            $('#arp-count').text(entries.length + ' entries');
            var $tbody = $('#arp-table tbody').empty();
            $.each(entries, function(i, e) {
                $tbody.append(
                    '<tr><td>' + $('<span>').text(e.ip).html() + '</td>' +
                    '<td>' + $('<span>').text(e.mac).html() + '</td>' +
                    '<td>' + $('<span>').text(e.interface).html() + '</td>' +
                    '<td style="opacity:0.6">' + $('<span>').text(e.info||'').html() + '</td></tr>'
                );
            });
        });
    }
    $('#btn-arp-refresh').click(loadArp);

    // ─── DNS Queries ────────────────────────────────────────────────
    function loadDns() {
        $.get('/api/siemlite/packetinspector/dnsquery', {limit: 50}, function(data) {
            var queries = data.queries || [];
            $('#dns-count').text(queries.length + ' queries');
            var $tbody = $('#dns-table tbody').empty();
            $.each(queries, function(i, q) {
                $tbody.append(
                    '<tr><td>' + $('<span>').text(q.name||q.raw||'').html() + '</td>' +
                    '<td>' + $('<span>').text(q.type||'').html() + '</td>' +
                    '<td>' + $('<span>').text(q.client||'').html() + '</td></tr>'
                );
            });
        });
    }
    $('#btn-dns-refresh').click(loadDns);

    // Tab change handlers
    $('a[data-toggle="tab"]').on('shown.bs.tab', function(e) {
        var target = $(e.target).attr('href');
        if (target === '#tab-connections') loadConnections();
        else if (target === '#tab-arp') loadArp();
        else if (target === '#tab-dns') loadDns();
    });

    // Initial load
    loadConnections();
});
</script>
