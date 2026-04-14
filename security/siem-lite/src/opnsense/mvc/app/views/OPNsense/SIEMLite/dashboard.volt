{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted.
 #}

<style>
    .siem-card {
        border-radius: 6px;
        padding: 18px;
        margin-bottom: 15px;
        border-left: 4px solid #337ab7;
        border: 1px solid rgba(128,128,128,0.2);
        border-left: 4px solid #337ab7;
    }
    .siem-card.critical { border-left-color: #d9534f; }
    .siem-card.high { border-left-color: #f0ad4e; }
    .siem-card.medium { border-left-color: #5bc0de; }
    .siem-card.low { border-left-color: #5cb85c; }
    .siem-card.clickable {
        cursor: pointer;
        transition: transform 0.15s ease, box-shadow 0.15s ease;
    }
    .siem-card.clickable:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }

    .stat-value {
        font-size: 2.2em;
        font-weight: 700;
        line-height: 1.1;
    }
    .stat-label {
        opacity: 0.7;
        font-size: 0.85em;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .risk-gauge {
        width: 100%;
        height: 24px;
        background: rgba(128,128,128,0.2);
        border-radius: 12px;
        overflow: hidden;
        margin-top: 8px;
    }
    .risk-gauge-fill {
        height: 100%;
        border-radius: 12px;
        transition: width 0.6s ease, background 0.6s ease;
    }
    .timeline-chart {
        width: 100%;
        height: 200px;
        position: relative;
    }
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

    .top-list { list-style: none; padding: 0; margin: 0; }
    .top-list li {
        display: flex;
        justify-content: space-between;
        padding: 6px 0;
        border-bottom: 1px solid rgba(128,128,128,0.15);
        font-size: 0.9em;
    }
    .top-list li:last-child { border-bottom: none; }
    .top-list .count { font-weight: 600; color: #337ab7; }
    .top-list li.clickable-ip {
        cursor: pointer;
        transition: background 0.15s ease;
    }
    .top-list li.clickable-ip:hover {
        background: rgba(51,122,183,0.08);
    }
    .refresh-indicator {
        font-size: 0.75em;
        opacity: 0.5;
        display: inline-flex;
        align-items: center;
        gap: 5px;
    }
    .refresh-indicator .countdown-bar {
        width: 40px;
        height: 3px;
        background: rgba(128,128,128,0.2);
        border-radius: 2px;
        overflow: hidden;
    }
    .refresh-indicator .countdown-fill {
        height: 100%;
        background: #337ab7;
        border-radius: 2px;
        transition: width 1s linear;
    }

    .siem-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 20px;
    }
    .siem-header h2 {
        margin: 0;
        font-weight: 300;
    }
    .time-selector .btn { padding: 4px 12px; font-size: 0.85em; }
    .time-selector .btn.active { background: #337ab7; color: #fff; }

    .source-bar {
        display: flex;
        align-items: center;
        margin-bottom: 6px;
    }
    .source-bar .label-text {
        width: 120px;
        font-size: 0.85em;
        opacity: 0.7;
    }
    .source-bar .bar-track {
        flex: 1;
        height: 18px;
        background: rgba(128,128,128,0.2);
        border-radius: 4px;
        overflow: hidden;
    }
    .source-bar .bar-fill {
        height: 100%;
        border-radius: 4px;
        transition: width 0.6s ease;
    }
    .source-bar .bar-count {
        width: 60px;
        text-align: right;
        font-size: 0.85em;
        font-weight: 600;
    }
    .siem-nodata {
        text-align: center;
        padding: 30px 10px;
        opacity: 0.5;
        font-size: 0.95em;
    }
</style>

<div class="siem-header">
    <h2><i class="fa fa-shield"></i> SIEM Dashboard</h2>
    <div style="display:flex; align-items:center; gap:15px;">
        <span class="refresh-indicator">
            <button class="btn btn-xs btn-default" id="btn-manual-refresh" title="Refresh now"><i class="fa fa-refresh"></i></button>
            <span class="countdown-bar"><span class="countdown-fill" id="countdown-fill" style="width:100%"></span></span>
            <span id="countdown-text">30s</span>
        </span>
        <span id="siem-service-status"></span>
        <div class="btn-group time-selector" id="timeRangeSelector">
            <button class="btn btn-default" data-range="1h">1H</button>
            <button class="btn btn-default active" data-range="24h">24H</button>
            <button class="btn btn-default" data-range="7d">7D</button>
            <button class="btn btn-default" data-range="30d">30D</button>
        </div>
    </div>
</div>

<div class="alert alert-warning" id="siem-not-running" style="display:none;">
    <i class="fa fa-exclamation-triangle"></i>
    {{ lang._('SIEM engine is not running. Go to') }} <a href="/ui/siemlite/settings">{{ lang._('Settings') }}</a> {{ lang._('to enable and start the service.') }}
</div>

<!-- KPI Cards Row -->
<div class="row">
    <div class="col-md-2">
        <div class="siem-card clickable" data-href="/ui/siemlite/events" title="View all events">
            <div class="stat-label">Total Events <i class="fa fa-external-link" style="opacity:0.3;font-size:0.8em"></i></div>
            <div class="stat-value" id="stat-total-events">—</div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="siem-card clickable" data-href="/ui/siemlite/alerts" title="View active alerts">
            <div class="stat-label">Active Alerts <i class="fa fa-external-link" style="opacity:0.3;font-size:0.8em"></i></div>
            <div class="stat-value" id="stat-total-alerts">—</div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="siem-card critical clickable" data-href="/ui/siemlite/alerts" data-filter="critical" title="View critical alerts">
            <div class="stat-label">Critical</div>
            <div class="stat-value text-danger" id="stat-critical">—</div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="siem-card high clickable" data-href="/ui/siemlite/alerts" data-filter="high" title="View high alerts">
            <div class="stat-label">High</div>
            <div class="stat-value text-warning" id="stat-high">—</div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="siem-card medium clickable" data-href="/ui/siemlite/alerts" data-filter="medium" title="View medium alerts">
            <div class="stat-label">Medium</div>
            <div class="stat-value text-info" id="stat-medium">—</div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="siem-card low clickable" data-href="/ui/siemlite/alerts" data-filter="low" title="View low alerts">
            <div class="stat-label">Low</div>
            <div class="stat-value text-success" id="stat-low">—</div>
        </div>
    </div>
</div>

<!-- Risk Score + Events Timeline -->
<div class="row">
    <div class="col-md-4">
        <div class="siem-card">
            <div class="stat-label">Security Risk Score</div>
            <div class="stat-value" id="risk-score-value" style="margin-bottom:8px">—</div>
            <div class="risk-gauge">
                <div class="risk-gauge-fill" id="risk-gauge-fill" style="width:0%; background:#5cb85c;"></div>
            </div>
            <div style="display:flex; justify-content:space-between; margin-top:4px; font-size:0.75em; opacity:0.6;">
                <span>Low</span><span>Medium</span><span>High</span><span>Critical</span>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <div class="siem-card">
            <div class="stat-label">Events Timeline</div>
            <canvas id="timeline-chart" height="180"></canvas>
        </div>
    </div>
</div>

<!-- Top Lists + Source Distribution -->
<div class="row">
    <div class="col-md-4">
        <div class="siem-card">
            <div class="stat-label" style="margin-bottom:10px"><i class="fa fa-crosshairs"></i> Top Source IPs</div>
            <ul class="top-list" id="top-sources"></ul>
        </div>
    </div>
    <div class="col-md-4">
        <div class="siem-card">
            <div class="stat-label" style="margin-bottom:10px"><i class="fa fa-bullseye"></i> Top Destination IPs</div>
            <ul class="top-list" id="top-destinations"></ul>
        </div>
    </div>
    <div class="col-md-4">
        <div class="siem-card">
            <div class="stat-label" style="margin-bottom:10px"><i class="fa fa-exclamation-triangle"></i> Top Triggered Rules</div>
            <ul class="top-list" id="top-rules"></ul>
        </div>
    </div>
</div>

<!-- Log Source Distribution -->
<div class="row">
    <div class="col-md-6">
        <div class="siem-card">
            <div class="stat-label" style="margin-bottom:10px"><i class="fa fa-database"></i> Events by Source</div>
            <div id="source-distribution"></div>
        </div>
    </div>
    <div class="col-md-6">
        <div class="siem-card">
            <div class="stat-label" style="margin-bottom:10px"><i class="fa fa-globe"></i> Top Countries</div>
            <ul class="top-list" id="geo-data"></ul>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    var currentRange = '24h';
    var sourceColors = {
        'firewall': '#337ab7', 'ids': '#d9534f', 'proxy': '#f0ad4e',
        'vpn': '#5bc0de', 'auth': '#5cb85c', 'system': '#777',
        'webui': '#9b59b6', 'cron': '#95a5a6'
    };

    function formatNumber(n) {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
        return n;
    }

    function loadDashboard() {
        $.get('/api/siemlite/dashboard/getStats', {timeRange: currentRange}, function(data) {
            // KPIs
            $('#stat-total-events').text(formatNumber(data.total_events || 0));
            $('#stat-total-alerts').text(formatNumber(data.total_alerts || 0));
            $('#stat-critical').text(data.critical_alerts || 0);
            $('#stat-high').text(data.high_alerts || 0);
            $('#stat-medium').text(data.medium_alerts || 0);
            $('#stat-low').text(data.low_alerts || 0);

            // Risk Score
            var risk = data.risk_score || 0;
            $('#risk-score-value').text(risk + '/100');
            var riskColor = risk >= 80 ? '#d9534f' : risk >= 60 ? '#f0ad4e' : risk >= 30 ? '#5bc0de' : '#5cb85c';
            $('#risk-gauge-fill').css({width: risk + '%', background: riskColor});

            // Top Sources
            var $src = $('#top-sources').empty();
            if (!data.top_sources || data.top_sources.length === 0) {
                $src.append('<li class="siem-nodata">No data available</li>');
            } else {
                $.each(data.top_sources, function(i, item) {
                    $src.append('<li class="clickable-ip" data-ip="' + $('<span>').text(item.ip).html() + '" title="Click to view events from ' + $('<span>').text(item.ip).html() + '"><span><i class="fa fa-chevron-right" style="opacity:0.2;font-size:0.7em;margin-right:5px"></i>' + $('<span>').text(item.ip).html() +
                        (item.country ? ' <i class="fa fa-globe" style="opacity:0.5"></i> ' + $('<span>').text(item.country).html() : '') +
                        '</span><span class="count">' + formatNumber(item.count) + '</span></li>');
                });
            }

            // Top Destinations
            var $dst = $('#top-destinations').empty();
            if (!data.top_destinations || data.top_destinations.length === 0) {
                $dst.append('<li class="siem-nodata">No data available</li>');
            } else {
                $.each(data.top_destinations, function(i, item) {
                    $dst.append('<li class="clickable-ip" data-ip="' + $('<span>').text(item.ip).html() + '" title="Click to view events to ' + $('<span>').text(item.ip).html() + '"><span><i class="fa fa-chevron-right" style="opacity:0.2;font-size:0.7em;margin-right:5px"></i>' + $('<span>').text(item.ip).html() +
                        '</span><span class="count">' + formatNumber(item.count) + '</span></li>');
                });
            }

            // Top Rules
            var $rules = $('#top-rules').empty();
            if (!data.top_rules || data.top_rules.length === 0) {
                $rules.append('<li class="siem-nodata">No data available</li>');
            } else {
                $.each(data.top_rules, function(i, item) {
                    $rules.append('<li><span>' + $('<span>').text(item.title).html() +
                        ' <span class="severity-badge ' + item.severity + '">' + item.severity + '</span>' +
                        '</span><span class="count">' + item.count + '</span></li>');
                });
            }

            // Source Distribution
            var $dist = $('#source-distribution').empty();
            if (!data.source_distribution || data.source_distribution.length === 0) {
                $dist.append('<div class="siem-nodata">No data available</div>');
            } else {
                var maxCount = 0;
                $.each(data.source_distribution, function(i, item) {
                    if (item.count > maxCount) maxCount = item.count;
                });
                $.each(data.source_distribution, function(i, item) {
                    var pct = maxCount > 0 ? (item.count / maxCount * 100) : 0;
                    var color = sourceColors[item.source] || '#337ab7';
                    $dist.append(
                        '<div class="source-bar">' +
                        '<span class="label-text">' + $('<span>').text(item.source).html() + '</span>' +
                        '<div class="bar-track"><div class="bar-fill" style="width:' + pct + '%; background:' + color + '"></div></div>' +
                        '<span class="bar-count">' + formatNumber(item.count) + '</span>' +
                        '</div>'
                    );
                });
            }

            // Geo Data
            var $geo = $('#geo-data').empty();
            if (!data.geo_data || data.geo_data.length === 0) {
                $geo.append('<li class="siem-nodata">No data available</li>');
            } else {
                $.each(data.geo_data, function(i, item) {
                    $geo.append('<li><span><i class="fa fa-map-marker text-danger"></i> ' +
                        $('<span>').text(item.country).html() +
                        '</span><span class="count">' + formatNumber(item.count) + '</span></li>');
                });
            }

            // Timeline Chart
            renderTimeline(data.events_timeline || []);
        }).fail(function() {
            // Service not running - show friendly message
            $('#stat-total-events').text('0');
            $('#stat-total-alerts').text('0');
            $('#stat-critical').text('0');
            $('#stat-high').text('0');
            $('#stat-medium').text('0');
            $('#stat-low').text('0');
            $('#risk-score-value').text('0/100');
            renderTimeline([]);
        });
    }

    function renderTimeline(timeline) {
        var canvas = document.getElementById('timeline-chart');
        if (!canvas) return;
        var ctx = canvas.getContext('2d');
        var W = canvas.width = canvas.parentElement.clientWidth - 40;
        var H = canvas.height = 170;
        ctx.clearRect(0, 0, W, H);

        // Detect theme text color from computed styles
        var textColor = getComputedStyle(canvas.parentElement).color || '#999';
        var gridColor = 'rgba(128,128,128,0.2)';

        if (timeline.length === 0) {
            ctx.fillStyle = textColor;
            ctx.globalAlpha = 0.4;
            ctx.font = '14px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('No data available', W / 2, H / 2);
            ctx.globalAlpha = 1;
            return;
        }

        var maxVal = Math.max.apply(null, timeline.map(function(t) { return t.count; })) || 1;
        var barW = Math.max(2, (W - 40) / timeline.length - 1);
        var chartH = H - 30;

        // Grid lines
        ctx.strokeStyle = gridColor;
        ctx.lineWidth = 1;
        for (var g = 0; g <= 4; g++) {
            var gy = chartH - (chartH / 4 * g);
            ctx.beginPath(); ctx.moveTo(35, gy); ctx.lineTo(W, gy); ctx.stroke();
            ctx.fillStyle = textColor;
            ctx.globalAlpha = 0.5;
            ctx.font = '10px sans-serif';
            ctx.textAlign = 'right';
            ctx.fillText(formatNumber(Math.round(maxVal / 4 * g)), 32, gy + 3);
            ctx.globalAlpha = 1;
        }

        // Bars
        timeline.forEach(function(item, i) {
            var x = 40 + i * (barW + 1);
            var h = (item.count / maxVal) * chartH;
            var y = chartH - h;
            ctx.fillStyle = item.has_alert ? '#d9534f' : '#337ab7';
            ctx.globalAlpha = 0.8;
            ctx.fillRect(x, y, barW, h);
            ctx.globalAlpha = 1;
        });

        // X-axis labels (show a subset)
        ctx.fillStyle = textColor;
        ctx.globalAlpha = 0.5;
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'center';
        var step = Math.max(1, Math.floor(timeline.length / 8));
        for (var j = 0; j < timeline.length; j += step) {
            var lx = 40 + j * (barW + 1) + barW / 2;
            ctx.fillText(timeline[j].label || '', lx, H - 2);
        }
        ctx.globalAlpha = 1;
    }

    // Time range selector
    $('#timeRangeSelector .btn').click(function() {
        $('#timeRangeSelector .btn').removeClass('active');
        $(this).addClass('active');
        currentRange = $(this).data('range');
        loadDashboard();
    });

    // Auto-refresh every 30 seconds with countdown
    var refreshInterval = 30;
    var countdown = refreshInterval;
    var countdownTimer;

    function resetCountdown() {
        countdown = refreshInterval;
        $('#countdown-fill').css('width', '100%');
        $('#countdown-text').text(countdown + 's');
    }

    function startCountdown() {
        clearInterval(countdownTimer);
        resetCountdown();
        countdownTimer = setInterval(function() {
            countdown--;
            var pct = (countdown / refreshInterval) * 100;
            $('#countdown-fill').css('width', pct + '%');
            $('#countdown-text').text(countdown + 's');
            if (countdown <= 0) {
                loadDashboard();
                resetCountdown();
            }
        }, 1000);
    }

    loadDashboard();
    startCountdown();

    // Manual refresh
    $('#btn-manual-refresh').click(function() {
        $(this).find('i').addClass('fa-spin');
        loadDashboard();
        resetCountdown();
        setTimeout(function() { $('#btn-manual-refresh i').removeClass('fa-spin'); }, 600);
    });

    // Clickable KPI cards
    $(document).on('click', '.siem-card.clickable', function() {
        var href = $(this).data('href');
        var filter = $(this).data('filter');
        if (href) {
            if (filter) {
                window.location.href = href + '?severity=' + filter;
            } else {
                window.location.href = href;
            }
        }
    });

    // Clickable IPs — navigate to Events page with search filter
    $(document).on('click', '.clickable-ip', function() {
        var ip = $(this).data('ip');
        if (ip) {
            window.location.href = '/ui/siemlite/events?search=' + encodeURIComponent(ip);
        }
    });

    // Check service status
    function checkServiceStatus() {
        $.get('/api/siemlite/service/status', function(data) {
            var $badge = $('#siem-service-status');
            if (data.status === 'running') {
                $badge.html('<span class="label label-success"><i class="fa fa-check-circle"></i> Running</span>');
                $('#siem-not-running').hide();
            } else if (data.status === 'disabled') {
                $badge.html('<span class="label label-default"><i class="fa fa-minus-circle"></i> Disabled</span>');
                $('#siem-not-running').show();
            } else {
                $badge.html('<span class="label label-danger"><i class="fa fa-times-circle"></i> Stopped</span>');
                $('#siem-not-running').show();
            }
        });
    }
    checkServiceStatus();
    setInterval(checkServiceStatus, 15000);
});
</script>
