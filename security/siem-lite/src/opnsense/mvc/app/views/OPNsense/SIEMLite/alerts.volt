{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<style>
    .alert-status-new { color: #d9534f; font-weight: 600; }
    .alert-status-acknowledged { color: #f0ad4e; }
    .alert-status-closed { color: #5cb85c; }
    .severity-badge {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 12px;
        font-size: 0.8em;
        font-weight: 600;
        color: #fff;
    }
    .severity-badge.critical { background: #d9534f; }
    .severity-badge.high { background: #f0ad4e; }
    .severity-badge.medium { background: #5bc0de; }
    .severity-badge.low { background: #5cb85c; }
    .alert-detail-events { max-height: 300px; overflow-y: auto; }
    .filter-bar {
        padding: 12px 15px;
        border-radius: 6px;
        margin-bottom: 15px;
        display: flex;
        gap: 10px;
        align-items: center;
        border: 1px solid rgba(128,128,128,0.2);
    }
    .filter-bar select, .filter-bar input {
        padding: 5px 10px;
        border: 1px solid rgba(128,128,128,0.3);
        border-radius: 4px;
        background-color: transparent;
        color: inherit;
    }
    .filter-bar select option {
        background-color: #2b2b2b;
        color: #e0e0e0;
    }
</style>

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-bell"></i> {{ lang._('Security Alerts') }}
</h2>

<div class="filter-bar">
    <select id="alert-filter-severity">
        <option value="">All Severities</option>
        <option value="critical">Critical</option>
        <option value="high">High</option>
        <option value="medium">Medium</option>
        <option value="low">Low</option>
    </select>
    <select id="alert-filter-status">
        <option value="">All Status</option>
        <option value="new">New</option>
        <option value="acknowledged">Acknowledged</option>
        <option value="closed">Closed</option>
    </select>
    <select id="alert-filter-time">
        <option value="1h">Last 1 Hour</option>
        <option value="24h" selected>Last 24 Hours</option>
        <option value="7d">Last 7 Days</option>
        <option value="30d">Last 30 Days</option>
    </select>
    <input type="text" id="alert-filter-search" placeholder="Search alerts..." style="min-width:250px; padding:5px 10px; border:1px solid rgba(128,128,128,0.3); border-radius:4px; background:inherit; color:inherit;"/>
    <button class="btn btn-primary btn-sm" id="btn-alert-refresh"><i class="fa fa-refresh"></i> {{ lang._('Refresh') }}</button>
</div>

<table id="grid-alerts" class="table table-condensed table-hover table-striped">
    <thead>
        <tr>
            <th data-column-id="timestamp" data-type="string" data-order="desc" data-width="160px">{{ lang._('Time') }}</th>
            <th data-column-id="severity" data-type="string" data-formatter="severity" data-width="90px">{{ lang._('Severity') }}</th>
            <th data-column-id="rule_title" data-type="string">{{ lang._('Rule') }}</th>
            <th data-column-id="source" data-type="string" data-width="100px">{{ lang._('Source') }}</th>
            <th data-column-id="src_ip" data-type="string" data-width="130px">{{ lang._('Source IP') }}</th>
            <th data-column-id="event_count" data-type="string" data-width="80px">{{ lang._('Events') }}</th>
            <th data-column-id="status" data-type="string" data-formatter="alertstatus" data-width="110px">{{ lang._('Status') }}</th>
            <th data-column-id="mitre" data-type="string" data-width="100px">{{ lang._('MITRE') }}</th>
            <th data-column-id="id" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            <th data-column-id="commands" data-formatter="alertcommands" data-sortable="false" data-width="100px">{{ lang._('Actions') }}</th>
        </tr>
    </thead>
    <tbody></tbody>
</table>

<script>
$(document).ready(function() {
    // Pre-fill filters from URL query params (from dashboard drill-down)
    var urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('severity')) $('#alert-filter-severity').val(urlParams.get('severity'));
    if (urlParams.get('status')) $('#alert-filter-status').val(urlParams.get('status'));
    if (urlParams.get('time')) $('#alert-filter-time').val(urlParams.get('time'));
    if (urlParams.get('search')) $('#alert-filter-search').val(urlParams.get('search'));

    var $grid = $("#grid-alerts").UIBootgrid({
        search: '/api/siemlite/alert/search',
        options: {
            formatters: {
                severity: function(column, row) {
                    return '<span class="severity-badge ' + (row.severity || 'low') + '">' + (row.severity || '') + '</span>';
                },
                alertstatus: function(column, row) {
                    var cls = 'alert-status-' + (row.status || 'new');
                    var icons = {new: 'fa-exclamation-circle', acknowledged: 'fa-check-circle', closed: 'fa-times-circle'};
                    var icon = icons[row.status] || 'fa-question-circle';
                    return '<span class="' + cls + '"><i class="fa ' + icon + '"></i> ' + (row.status || 'new') + '</span>';
                },
                alertcommands: function(column, row) {
                    var html = '';
                    if (row.status === 'new') {
                        html += '<button class="btn btn-xs btn-warning alert-ack-btn" data-id="' + row.id +
                            '" title="Acknowledge"><i class="fa fa-check"></i></button> ';
                    }
                    if (row.status !== 'closed') {
                        html += '<button class="btn btn-xs btn-success alert-close-btn" data-id="' + row.id +
                            '" title="Close"><i class="fa fa-times"></i></button>';
                    }
                    return html;
                }
            },
            requestHandler: function(request) {
                request.severity = $('#alert-filter-severity').val();
                request.status = $('#alert-filter-status').val();
                request.timeRange = $('#alert-filter-time').val();
                request.searchPhrase = $('#alert-filter-search').val();
                return request;
            }
        }
    });

    $('#alert-filter-severity, #alert-filter-status, #alert-filter-time').change(function() {
        $grid.bootgrid('reload');
    });
    var searchTimer;
    $('#alert-filter-search').on('input', function() {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(function() { $grid.bootgrid('reload'); }, 400);
    });
    $('#btn-alert-refresh').click(function() { $grid.bootgrid('reload'); });

    // Acknowledge alert
    $(document).on('click', '.alert-ack-btn', function() {
        var id = $(this).data('id');
        $.post('/api/siemlite/alert/ack/' + id, {}, function() {
            $grid.bootgrid('reload');
        });
    });

    // Close alert
    $(document).on('click', '.alert-close-btn', function() {
        var id = $(this).data('id');
        $.post('/api/siemlite/alert/close/' + id, {}, function() {
            $grid.bootgrid('reload');
        });
    });
});
</script>
