{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<style>
    .traffic-stats {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
        margin-bottom: 20px;
    }
    .traffic-stat-card {
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 8px;
        padding: 15px;
        text-align: center;
    }
    .traffic-stat-card .stat-value {
        font-size: 1.8em;
        font-weight: 700;
        margin: 5px 0;
    }
    .traffic-stat-card .stat-label {
        font-size: 0.85em;
        opacity: 0.7;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
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
        font-size: 0.9em;
        background-color: transparent;
        color: inherit;
    }
    .filter-bar select option {
        background-color: #2b2b2b;
        color: #e0e0e0;
    }
    .chart-container {
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 8px;
        padding: 15px;
        margin-bottom: 15px;
    }
    .chart-container h4 {
        margin-top: 0;
        font-weight: 400;
        opacity: 0.9;
    }
    .charts-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 15px;
        margin-bottom: 15px;
    }
    .port-bar {
        display: flex;
        align-items: center;
        margin: 4px 0;
        font-size: 0.85em;
    }
    .port-bar .port-name {
        width: 140px;
        font-family: monospace;
    }
    .port-bar .port-fill {
        height: 18px;
        background: rgba(91,192,222,0.7);
        border-radius: 3px;
        min-width: 2px;
        transition: width 0.3s;
    }
    .port-bar .port-count {
        margin-left: 8px;
        opacity: 0.7;
    }
    .action-badge {
        display: inline-block;
        padding: 1px 8px;
        border-radius: 10px;
        font-size: 0.75em;
        font-weight: 600;
    }
    .action-badge.block { background: rgba(217,83,79,0.2); color: #d9534f; }
    .action-badge.pass { background: rgba(92,184,92,0.2); color: #5cb85c; }
    @media (max-width: 992px) {
        .charts-grid { grid-template-columns: 1fr; }
    }
</style>

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-exchange"></i> {{ lang._('Traffic Analysis') }}
</h2>

<div class="filter-bar">
    <select id="tf-time">
        <option value="1h">Last 1 Hour</option>
        <option value="24h" selected>Last 24 Hours</option>
        <option value="7d">Last 7 Days</option>
        <option value="30d">Last 30 Days</option>
    </select>
    <select id="tf-protocol">
        <option value="">All Protocols</option>
        <option value="tcp">TCP</option>
        <option value="udp">UDP</option>
        <option value="icmp">ICMP</option>
    </select>
    <button class="btn btn-primary btn-sm" id="btn-tf-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
</div>

<!-- Stats Cards -->
<div class="traffic-stats" id="traffic-stats-row">
    <div class="traffic-stat-card">
        <div class="stat-label">Total Flows</div>
        <div class="stat-value" id="ts-flows">—</div>
    </div>
    <div class="traffic-stat-card">
        <div class="stat-label">Unique Sources</div>
        <div class="stat-value" id="ts-sources">—</div>
    </div>
    <div class="traffic-stat-card">
        <div class="stat-label">Unique Destinations</div>
        <div class="stat-value" id="ts-destinations">—</div>
    </div>
    <div class="traffic-stat-card">
        <div class="stat-label"><i class="fa fa-ban" style="color:#d9534f"></i> Blocked</div>
        <div class="stat-value" id="ts-blocked" style="color:#d9534f">—</div>
    </div>
    <div class="traffic-stat-card">
        <div class="stat-label"><i class="fa fa-check" style="color:#5cb85c"></i> Allowed</div>
        <div class="stat-value" id="ts-allowed" style="color:#5cb85c">—</div>
    </div>
</div>

<!-- Charts Row -->
<div class="charts-grid">
    <div class="chart-container">
        <h4><i class="fa fa-area-chart"></i> {{ lang._('Traffic Timeline') }}</h4>
        <canvas id="traffic-timeline-chart" height="220"></canvas>
    </div>
    <div class="chart-container">
        <h4><i class="fa fa-pie-chart"></i> {{ lang._('Protocol Distribution') }}</h4>
        <canvas id="protocol-chart" height="220"></canvas>
    </div>
</div>

<div class="charts-grid">
    <div class="chart-container">
        <h4><i class="fa fa-plug"></i> {{ lang._('Top Destination Ports') }}</h4>
        <div id="port-list"></div>
    </div>
    <div class="chart-container">
        <h4><i class="fa fa-server"></i> {{ lang._('Interface Distribution') }}</h4>
        <canvas id="interface-chart" height="220"></canvas>
    </div>
</div>

<!-- Flows Table -->
<h3 style="font-weight:300; margin-top:20px;"><i class="fa fa-random"></i> {{ lang._('Network Flows') }}</h3>
<table id="grid-flows" class="table table-condensed table-hover table-striped">
    <thead>
        <tr>
            <th data-column-id="src_ip" data-type="string" data-width="130px">{{ lang._('Source IP') }}</th>
            <th data-column-id="dst_ip" data-type="string" data-width="130px">{{ lang._('Dest IP') }}</th>
            <th data-column-id="dst_port" data-type="string" data-width="80px">{{ lang._('Port') }}</th>
            <th data-column-id="protocol" data-type="string" data-width="70px">{{ lang._('Proto') }}</th>
            <th data-column-id="count" data-type="numeric" data-order="desc" data-width="80px">{{ lang._('Count') }}</th>
            <th data-column-id="actions" data-type="string" data-formatter="actionfmt" data-width="100px">{{ lang._('Action') }}</th>
            <th data-column-id="first_seen" data-type="string" data-width="140px">{{ lang._('First Seen') }}</th>
            <th data-column-id="last_seen" data-type="string" data-width="140px">{{ lang._('Last Seen') }}</th>
        </tr>
    </thead>
    <tbody></tbody>
</table>

<script>
$(document).ready(function() {
    var timelineChart, protocolChart, interfaceChart;
    var chartTextColor = getComputedStyle(document.body).color || '#ccc';

    function fmt(n) {
        if (n >= 1000000) return (n/1000000).toFixed(1) + 'M';
        if (n >= 1000) return (n/1000).toFixed(1) + 'K';
        return n;
    }

    function loadStats() {
        var tr = $('#tf-time').val();
        $.get('/api/siemlite/traffic/stats', {timeRange: tr}, function(data) {
            $('#ts-flows').text(fmt(data.total_flows || 0));
            $('#ts-sources').text(fmt(data.unique_sources || 0));
            $('#ts-destinations').text(fmt(data.unique_destinations || 0));
            $('#ts-blocked').text(fmt(data.blocked || 0));
            $('#ts-allowed').text(fmt(data.allowed || 0));

            renderTimeline(data.timeline || []);
            renderProtocols(data.protocols || []);
            renderInterfaces(data.interfaces || []);
        });

        $.get('/api/siemlite/traffic/topports', {timeRange: tr}, function(data) {
            renderPorts(data.ports || []);
        });
    }

    function renderTimeline(timeline) {
        var ctx = document.getElementById('traffic-timeline-chart').getContext('2d');
        if (timelineChart) timelineChart.destroy();
        timelineChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: timeline.map(function(t) { return t.label; }),
                datasets: [
                    {
                        label: 'Allowed',
                        data: timeline.map(function(t) { return t.allowed || 0; }),
                        backgroundColor: 'rgba(92,184,92,0.6)',
                        borderWidth: 0
                    },
                    {
                        label: 'Blocked',
                        data: timeline.map(function(t) { return t.blocked || 0; }),
                        backgroundColor: 'rgba(217,83,79,0.6)',
                        borderWidth: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { stacked: true, ticks: { color: chartTextColor, maxRotation: 45 }, grid: { display: false } },
                    y: { stacked: true, beginAtZero: true, ticks: { color: chartTextColor }, grid: { color: 'rgba(128,128,128,0.1)' } }
                },
                plugins: { legend: { labels: { color: chartTextColor } } }
            }
        });
    }

    function renderProtocols(protocols) {
        var ctx = document.getElementById('protocol-chart').getContext('2d');
        if (protocolChart) protocolChart.destroy();
        var colors = ['#5bc0de','#5cb85c','#f0ad4e','#d9534f','#9b59b6','#3498db','#e67e22','#1abc9c','#e74c3c','#95a5a6'];
        protocolChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: protocols.map(function(p) { return p.name; }),
                datasets: [{
                    data: protocols.map(function(p) { return p.count; }),
                    backgroundColor: colors.slice(0, protocols.length),
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: 'right', labels: { color: chartTextColor, padding: 12 } } }
            }
        });
    }

    function renderInterfaces(interfaces) {
        var ctx = document.getElementById('interface-chart').getContext('2d');
        if (interfaceChart) interfaceChart.destroy();
        var colors = ['#3498db','#2ecc71','#e74c3c','#f39c12','#9b59b6','#1abc9c'];
        interfaceChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: interfaces.map(function(i) { return i.name; }),
                datasets: [{
                    data: interfaces.map(function(i) { return i.count; }),
                    backgroundColor: colors.slice(0, interfaces.length),
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: 'right', labels: { color: chartTextColor, padding: 12 } } }
            }
        });
    }

    function renderPorts(ports) {
        var $list = $('#port-list').empty();
        if (!ports.length) { $list.html('<em style="opacity:0.5">No port data</em>'); return; }
        var max = ports[0].count;
        $.each(ports, function(i, p) {
            var svc = p.service ? p.service + ' (' + p.port + ')' : ':' + p.port;
            var pct = Math.max(2, (p.count / max) * 100);
            var actions = (p.actions || '').split(',');
            var badges = '';
            $.each(actions, function(j, a) {
                a = $.trim(a);
                if (a) badges += ' <span class="action-badge ' + a + '">' + a + '</span>';
            });
            $list.append(
                '<div class="port-bar">' +
                '<span class="port-name">' + svc + '</span>' +
                '<div class="port-fill" style="width:' + pct + '%"></div>' +
                '<span class="port-count">' + fmt(p.count) + ' (' + p.unique_sources + ' src)' + badges + '</span>' +
                '</div>'
            );
        });
    }

    // Flows table
    var $grid = $("#grid-flows").UIBootgrid({
        ajax: true,
        url: '/api/siemlite/traffic/flows',
        formatters: {
            actionfmt: function(col, row) {
                var parts = (row.actions || '').split(',');
                var h = '';
                $.each(parts, function(i, a) {
                    a = $.trim(a);
                    if (a) h += '<span class="action-badge ' + a + '">' + a + '</span> ';
                });
                return h || '—';
            }
        },
        requestHandler: function(request) {
            request.timeRange = $('#tf-time').val();
            request.protocol = $('#tf-protocol').val();
            return request;
        }
    });

    // Controls
    $('#tf-time, #tf-protocol').change(function() { loadStats(); $grid.bootgrid('reload'); });
    $('#btn-tf-refresh').click(function() { loadStats(); $grid.bootgrid('reload'); });

    loadStats();
});
</script>
