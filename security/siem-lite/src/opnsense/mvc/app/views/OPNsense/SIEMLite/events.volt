{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<style>
    .filter-bar {
        background: #f8f9fa;
        padding: 12px 15px;
        border-radius: 6px;
        margin-bottom: 15px;
        display: flex;
        gap: 10px;
        align-items: center;
        flex-wrap: wrap;
    }
    .filter-bar select, .filter-bar input {
        padding: 5px 10px;
        border: 1px solid #ddd;
        border-radius: 4px;
        font-size: 0.9em;
    }
    .filter-bar select { min-width: 120px; }
    .filter-bar input[type="text"] { min-width: 250px; }
    .severity-dot {
        display: inline-block;
        width: 10px; height: 10px;
        border-radius: 50%;
        margin-right: 5px;
    }
    .severity-dot.critical { background: #d9534f; }
    .severity-dot.high { background: #f0ad4e; }
    .severity-dot.medium { background: #5bc0de; }
    .severity-dot.low { background: #5cb85c; }
    .event-detail-modal .modal-body pre {
        max-height: 400px;
        overflow-y: auto;
        background: #f5f5f5;
        padding: 10px;
        border-radius: 4px;
        font-size: 0.85em;
    }
</style>

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-list-alt"></i> {{ lang._('Security Events') }}
</h2>

<div class="filter-bar">
    <select id="filter-source">
        <option value="">All Sources</option>
        <option value="firewall">Firewall</option>
        <option value="ids">IDS/IPS</option>
        <option value="proxy">Web Proxy</option>
        <option value="vpn">VPN</option>
        <option value="auth">Authentication</option>
        <option value="system">System</option>
        <option value="webui">Web UI</option>
    </select>
    <select id="filter-severity">
        <option value="">All Severities</option>
        <option value="critical">Critical</option>
        <option value="high">High</option>
        <option value="medium">Medium</option>
        <option value="low">Low</option>
        <option value="informational">Informational</option>
    </select>
    <select id="filter-time">
        <option value="1h">Last 1 Hour</option>
        <option value="24h" selected>Last 24 Hours</option>
        <option value="7d">Last 7 Days</option>
        <option value="30d">Last 30 Days</option>
    </select>
    <input type="text" id="filter-search" placeholder="Search events..."/>
    <button class="btn btn-primary btn-sm" id="btn-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
</div>

<table id="grid-events" class="table table-condensed table-hover table-striped">
    <thead>
        <tr>
            <th data-column-id="timestamp" data-type="string" data-order="desc" data-width="160px">{{ lang._('Timestamp') }}</th>
            <th data-column-id="severity" data-type="string" data-formatter="severity" data-width="90px">{{ lang._('Severity') }}</th>
            <th data-column-id="source" data-type="string" data-width="100px">{{ lang._('Source') }}</th>
            <th data-column-id="src_ip" data-type="string" data-width="130px">{{ lang._('Source IP') }}</th>
            <th data-column-id="dst_ip" data-type="string" data-width="130px">{{ lang._('Dest IP') }}</th>
            <th data-column-id="action" data-type="string" data-width="80px">{{ lang._('Action') }}</th>
            <th data-column-id="message" data-type="string">{{ lang._('Message') }}</th>
            <th data-column-id="id" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            <th data-column-id="commands" data-formatter="eventcommands" data-sortable="false" data-width="60px">{{ lang._('') }}</th>
        </tr>
    </thead>
    <tbody></tbody>
</table>

<!-- Event Detail Modal -->
<div class="modal fade event-detail-modal" id="eventDetailModal" tabindex="-1" role="dialog">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal"><span>&times;</span></button>
                <h4 class="modal-title"><i class="fa fa-search"></i> {{ lang._('Event Detail') }}</h4>
            </div>
            <div class="modal-body">
                <div class="row">
                    <div class="col-md-6">
                        <table class="table table-condensed" id="event-detail-meta"></table>
                    </div>
                    <div class="col-md-6">
                        <table class="table table-condensed" id="event-detail-network"></table>
                    </div>
                </div>
                <h5>{{ lang._('Raw Log') }}</h5>
                <pre id="event-detail-raw"></pre>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('Close') }}</button>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    var $grid = $("#grid-events").UIBootgrid({
        ajax: true,
        url: '/api/siemlite/event/search',
        formatters: {
            severity: function(column, row) {
                var s = row.severity || 'informational';
                return '<span class="severity-dot ' + s + '"></span>' + s;
            },
            eventcommands: function(column, row) {
                return '<button type="button" class="btn btn-xs btn-default event-detail-btn" data-id="' +
                    row.id + '" title="View details"><i class="fa fa-eye"></i></button>';
            }
        },
        requestHandler: function(request) {
            request.source = $('#filter-source').val();
            request.severity = $('#filter-severity').val();
            request.timeRange = $('#filter-time').val();
            request.searchPhrase = $('#filter-search').val();
            return request;
        }
    });

    // Filters trigger reload
    $('#filter-source, #filter-severity, #filter-time').change(function() {
        $grid.bootgrid('reload');
    });
    var searchTimer;
    $('#filter-search').on('input', function() {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(function() { $grid.bootgrid('reload'); }, 400);
    });
    $('#btn-refresh').click(function() { $grid.bootgrid('reload'); });

    // Event detail
    $(document).on('click', '.event-detail-btn', function() {
        var eventId = $(this).data('id');
        $.get('/api/siemlite/event/get/' + eventId, function(data) {
            var $meta = $('#event-detail-meta').empty();
            var fields = [
                ['Timestamp', data.timestamp], ['Source', data.source],
                ['Severity', data.severity], ['Action', data.action],
                ['Rule', data.matched_rule || '—'],
                ['MITRE', data.mitre_tactic ? data.mitre_tactic + ' / ' + (data.mitre_technique || '') : '—']
            ];
            $.each(fields, function(i, f) {
                $meta.append('<tr><td><strong>' + f[0] + '</strong></td><td>' +
                    $('<span>').text(f[1] || '—').html() + '</td></tr>');
            });

            var $net = $('#event-detail-network').empty();
            var netFields = [
                ['Source IP', data.src_ip], ['Source Port', data.src_port],
                ['Dest IP', data.dst_ip], ['Dest Port', data.dst_port],
                ['Protocol', data.protocol], ['Interface', data.interface],
                ['Country', data.country || '—']
            ];
            $.each(netFields, function(i, f) {
                $net.append('<tr><td><strong>' + f[0] + '</strong></td><td>' +
                    $('<span>').text(f[1] || '—').html() + '</td></tr>');
            });

            $('#event-detail-raw').text(data.raw || '');
            $('#eventDetailModal').modal('show');
        });
    });
});
</script>
