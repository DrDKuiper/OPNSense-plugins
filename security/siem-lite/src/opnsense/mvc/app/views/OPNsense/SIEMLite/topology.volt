{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<style>
    .topo-container {
        display: flex;
        gap: 15px;
        height: calc(100vh - 200px);
        min-height: 500px;
    }
    .topo-canvas-wrap {
        flex: 1;
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 8px;
        overflow: hidden;
        position: relative;
    }
    #topo-canvas {
        width: 100%;
        height: 100%;
        cursor: grab;
    }
    #topo-canvas:active { cursor: grabbing; }
    .topo-sidebar {
        width: 320px;
        flex-shrink: 0;
        overflow-y: auto;
        border: 1px solid rgba(128,128,128,0.2);
        border-radius: 8px;
        padding: 15px;
    }
    .topo-controls {
        padding: 12px 15px;
        border-radius: 6px;
        margin-bottom: 15px;
        display: flex;
        gap: 10px;
        align-items: center;
        flex-wrap: wrap;
        border: 1px solid rgba(128,128,128,0.2);
    }
    .topo-controls select, .topo-controls input {
        padding: 5px 10px;
        border: 1px solid rgba(128,128,128,0.3);
        border-radius: 4px;
        background: transparent;
        color: inherit;
    }
    .topo-controls select option { background-color: #2b2b2b; color: #e0e0e0; }
    .topo-legend {
        display: flex;
        gap: 15px;
        flex-wrap: wrap;
        margin-bottom: 15px;
        font-size: 0.85em;
    }
    .topo-legend-item {
        display: flex;
        align-items: center;
        gap: 5px;
    }
    .topo-legend-dot {
        width: 12px;
        height: 12px;
        border-radius: 50%;
    }
    .topo-stats {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        margin-bottom: 15px;
    }
    .topo-stat {
        text-align: center;
        padding: 8px;
        border: 1px solid rgba(128,128,128,0.15);
        border-radius: 6px;
    }
    .topo-stat .val { font-size: 1.3em; font-weight: 700; }
    .topo-stat .lbl { font-size: 0.75em; opacity: 0.6; text-transform: uppercase; }
    .node-detail { display: none; }
    .node-detail.show { display: block; }
    .node-detail h5 {
        font-family: 'Consolas', monospace;
        margin: 15px 0 8px;
        padding-bottom: 5px;
        border-bottom: 1px solid rgba(128,128,128,0.2);
    }
    .node-detail .peer-list {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    .node-detail .peer-list li {
        display: flex;
        justify-content: space-between;
        padding: 3px 0;
        font-size: 0.85em;
        font-family: monospace;
    }
    .sev-dot {
        display: inline-block;
        width: 8px;
        height: 8px;
        border-radius: 50%;
        margin-right: 4px;
    }
    .topo-overlay {
        position: absolute;
        top: 10px;
        left: 10px;
        display: flex;
        gap: 5px;
        z-index: 10;
    }
    .topo-overlay button {
        padding: 5px 10px;
        border: 1px solid rgba(128,128,128,0.3);
        border-radius: 4px;
        background: rgba(0,0,0,0.5);
        color: #ccc;
        cursor: pointer;
        font-size: 0.9em;
    }
    .topo-overlay button:hover { background: rgba(0,0,0,0.7); }
</style>

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-sitemap"></i> {{ lang._('Network Map') }}
</h2>

<div class="topo-controls">
    <select id="topo-time">
        <option value="1h">Last 1 Hour</option>
        <option value="24h" selected>Last 24 Hours</option>
        <option value="7d">Last 7 Days</option>
        <option value="30d">Last 30 Days</option>
    </select>
    <label style="font-size:0.85em">Min. connections:</label>
    <input type="number" id="topo-min" value="2" min="1" max="100" style="width:70px"/>
    <button class="btn btn-primary btn-sm" id="btn-topo-refresh"><i class="fa fa-refresh"></i> {{ lang._('Reload') }}</button>
</div>

<div class="topo-legend">
    <div class="topo-legend-item"><div class="topo-legend-dot" style="background:#3498db"></div> Internal</div>
    <div class="topo-legend-item"><div class="topo-legend-dot" style="background:#e74c3c"></div> External</div>
    <div class="topo-legend-item"><div class="topo-legend-dot" style="background:#95a5a6"></div> Localhost</div>
    <div class="topo-legend-item" style="margin-left:20px">
        <div style="width:30px;height:3px;background:#5cb85c;margin-right:5px;border-radius:2px"></div> Normal
    </div>
    <div class="topo-legend-item">
        <div style="width:30px;height:3px;background:#f0ad4e;margin-right:5px;border-radius:2px"></div> Warning
    </div>
    <div class="topo-legend-item">
        <div style="width:30px;height:3px;background:#d9534f;margin-right:5px;border-radius:2px"></div> Critical
    </div>
</div>

<div class="topo-container">
    <div class="topo-canvas-wrap">
        <div class="topo-overlay">
            <button id="btn-zoom-in" title="Zoom In"><i class="fa fa-plus"></i></button>
            <button id="btn-zoom-out" title="Zoom Out"><i class="fa fa-minus"></i></button>
            <button id="btn-zoom-reset" title="Reset"><i class="fa fa-crosshairs"></i></button>
        </div>
        <canvas id="topo-canvas"></canvas>
    </div>
    <div class="topo-sidebar">
        <div class="topo-stats">
            <div class="topo-stat"><div class="val" id="topo-nodes">0</div><div class="lbl">Nodes</div></div>
            <div class="topo-stat"><div class="val" id="topo-edges">0</div><div class="lbl">Connections</div></div>
            <div class="topo-stat"><div class="val" id="topo-internal">0</div><div class="lbl">Internal</div></div>
            <div class="topo-stat"><div class="val" id="topo-external">0</div><div class="lbl">External</div></div>
        </div>
        <div id="node-detail-panel" class="node-detail">
            <h4 style="margin-top:0"><i class="fa fa-info-circle"></i> <span id="nd-ip"></span></h4>
            <div id="nd-severity"></div>
            <h5>{{ lang._('Outbound Peers') }}</h5>
            <ul class="peer-list" id="nd-outbound"></ul>
            <h5>{{ lang._('Inbound Peers') }}</h5>
            <ul class="peer-list" id="nd-inbound"></ul>
            <h5>{{ lang._('Ports Accessed') }}</h5>
            <ul class="peer-list" id="nd-ports"></ul>
            <h5>{{ lang._('Recent Events') }}</h5>
            <div id="nd-events" style="max-height:200px;overflow-y:auto;font-size:0.82em"></div>
        </div>
        <div id="node-detail-empty" style="text-align:center;opacity:0.5;padding:40px 0">
            <i class="fa fa-mouse-pointer" style="font-size:2em;margin-bottom:10px;display:block"></i>
            {{ lang._('Click a node to see details') }}
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    var canvas = document.getElementById('topo-canvas');
    var ctx = canvas.getContext('2d');
    var nodes = [], edges = [];
    var zoom = 1, panX = 0, panY = 0;
    var dragging = null, dragStart = null, panning = false, panStart = null;
    var hoveredNode = null, selectedNode = null;
    var animFrame;
    var W, H;

    var colors = {
        internal: '#3498db',
        external: '#e74c3c',
        localhost: '#95a5a6'
    };
    var sevColors = ['#5cb85c', '#5cb85c', '#f0ad4e', '#f0ad4e', '#d9534f'];

    function resize() {
        var rect = canvas.parentElement.getBoundingClientRect();
        W = rect.width;
        H = rect.height;
        canvas.width = W * window.devicePixelRatio;
        canvas.height = H * window.devicePixelRatio;
        canvas.style.width = W + 'px';
        canvas.style.height = H + 'px';
        ctx.setTransform(window.devicePixelRatio, 0, 0, window.devicePixelRatio, 0, 0);
    }

    function loadTopology() {
        $.get('/api/siemlite/topology/getdata', {
            timeRange: $('#topo-time').val(),
            minCount: $('#topo-min').val()
        }, function(data) {
            nodes = data.nodes || [];
            edges = data.edges || [];

            // Stats
            $('#topo-nodes').text(nodes.length);
            $('#topo-edges').text(edges.length);
            $('#topo-internal').text(nodes.filter(function(n){return n.type==='internal'}).length);
            $('#topo-external').text(nodes.filter(function(n){return n.type==='external'}).length);

            // Initialize positions
            var cx = W / 2, cy = H / 2;
            $.each(nodes, function(i, n) {
                n.x = cx + (Math.random() - 0.5) * W * 0.6;
                n.y = cy + (Math.random() - 0.5) * H * 0.6;
                n.vx = 0;
                n.vy = 0;
                n.radius = Math.max(6, Math.min(25, Math.sqrt(n.count) * 2));
            });

            // Build node lookup
            var nodeMap = {};
            $.each(nodes, function(i, n) { nodeMap[n.id] = i; });
            $.each(edges, function(i, e) {
                e.sourceIdx = nodeMap[e.source];
                e.targetIdx = nodeMap[e.target];
            });

            startSimulation();
        });
    }

    function startSimulation() {
        var iterations = 0;
        if (animFrame) cancelAnimationFrame(animFrame);

        function tick() {
            if (iterations < 300) {
                simulate();
                iterations++;
            }
            draw();
            animFrame = requestAnimationFrame(tick);
        }
        tick();
    }

    function simulate() {
        var alpha = 0.3;
        var repulsion = 2000;
        var attraction = 0.005;
        var damping = 0.85;
        var centerForce = 0.01;
        var cx = W / 2, cy = H / 2;

        // Repulsion between all nodes
        for (var i = 0; i < nodes.length; i++) {
            for (var j = i + 1; j < nodes.length; j++) {
                var dx = nodes[j].x - nodes[i].x;
                var dy = nodes[j].y - nodes[i].y;
                var dist = Math.sqrt(dx * dx + dy * dy) || 1;
                var force = repulsion / (dist * dist);
                var fx = (dx / dist) * force * alpha;
                var fy = (dy / dist) * force * alpha;
                nodes[i].vx -= fx;
                nodes[i].vy -= fy;
                nodes[j].vx += fx;
                nodes[j].vy += fy;
            }
        }

        // Attraction along edges
        $.each(edges, function(i, e) {
            if (e.sourceIdx === undefined || e.targetIdx === undefined) return;
            var s = nodes[e.sourceIdx], t = nodes[e.targetIdx];
            var dx = t.x - s.x, dy = t.y - s.y;
            var dist = Math.sqrt(dx * dx + dy * dy) || 1;
            var force = (dist - 120) * attraction * alpha;
            var fx = (dx / dist) * force;
            var fy = (dy / dist) * force;
            s.vx += fx; s.vy += fy;
            t.vx -= fx; t.vy -= fy;
        });

        // Center gravity + velocity update
        $.each(nodes, function(i, n) {
            if (n === dragging) return;
            n.vx += (cx - n.x) * centerForce;
            n.vy += (cy - n.y) * centerForce;
            n.vx *= damping;
            n.vy *= damping;
            n.x += n.vx;
            n.y += n.vy;
            // Bounds
            n.x = Math.max(n.radius, Math.min(W - n.radius, n.x));
            n.y = Math.max(n.radius, Math.min(H - n.radius, n.y));
        });
    }

    function draw() {
        ctx.clearRect(0, 0, W, H);
        ctx.save();
        ctx.translate(panX, panY);
        ctx.scale(zoom, zoom);

        // Draw edges
        $.each(edges, function(i, e) {
            if (e.sourceIdx === undefined || e.targetIdx === undefined) return;
            var s = nodes[e.sourceIdx], t = nodes[e.targetIdx];
            var sev = e.severity || 0;
            ctx.beginPath();
            ctx.moveTo(s.x, s.y);
            ctx.lineTo(t.x, t.y);
            ctx.strokeStyle = sevColors[sev] || '#5cb85c';
            ctx.lineWidth = Math.max(1, Math.min(5, Math.log2(e.count + 1)));
            ctx.globalAlpha = 0.4;
            ctx.stroke();
            ctx.globalAlpha = 1;

            // Arrow
            var angle = Math.atan2(t.y - s.y, t.x - s.x);
            var midX = (s.x + t.x) / 2, midY = (s.y + t.y) / 2;
            ctx.beginPath();
            ctx.moveTo(midX + 6 * Math.cos(angle), midY + 6 * Math.sin(angle));
            ctx.lineTo(midX - 4 * Math.cos(angle - 0.5), midY - 4 * Math.sin(angle - 0.5));
            ctx.lineTo(midX - 4 * Math.cos(angle + 0.5), midY - 4 * Math.sin(angle + 0.5));
            ctx.closePath();
            ctx.fillStyle = sevColors[sev] || '#5cb85c';
            ctx.globalAlpha = 0.5;
            ctx.fill();
            ctx.globalAlpha = 1;
        });

        // Draw nodes
        $.each(nodes, function(i, n) {
            var color = colors[n.type] || colors.external;
            var isHovered = (n === hoveredNode);
            var isSelected = (n === selectedNode);

            // Glow for selected/hovered
            if (isSelected || isHovered) {
                ctx.beginPath();
                ctx.arc(n.x, n.y, n.radius + 4, 0, Math.PI * 2);
                ctx.fillStyle = color;
                ctx.globalAlpha = 0.2;
                ctx.fill();
                ctx.globalAlpha = 1;
            }

            // Node circle
            ctx.beginPath();
            ctx.arc(n.x, n.y, n.radius, 0, Math.PI * 2);
            ctx.fillStyle = color;
            ctx.globalAlpha = isSelected ? 1 : 0.8;
            ctx.fill();
            ctx.globalAlpha = 1;

            // Severity ring
            if (n.severity >= 3) {
                ctx.beginPath();
                ctx.arc(n.x, n.y, n.radius + 2, 0, Math.PI * 2);
                ctx.strokeStyle = sevColors[n.severity];
                ctx.lineWidth = 2;
                ctx.stroke();
            }

            // Label
            ctx.fillStyle = getComputedStyle(document.body).color || '#ccc';
            ctx.font = (isHovered || isSelected ? 'bold ' : '') + '10px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(n.id, n.x, n.y + n.radius + 14);
        });

        ctx.restore();
    }

    // Mouse events
    function getMousePos(e) {
        var rect = canvas.getBoundingClientRect();
        return {
            x: (e.clientX - rect.left - panX) / zoom,
            y: (e.clientY - rect.top - panY) / zoom
        };
    }

    function findNode(pos) {
        for (var i = nodes.length - 1; i >= 0; i--) {
            var n = nodes[i];
            var dx = pos.x - n.x, dy = pos.y - n.y;
            if (dx * dx + dy * dy < (n.radius + 4) * (n.radius + 4)) return n;
        }
        return null;
    }

    canvas.addEventListener('mousedown', function(e) {
        var pos = getMousePos(e);
        var node = findNode(pos);
        if (node) {
            dragging = node;
            dragStart = pos;
        } else {
            panning = true;
            panStart = {x: e.clientX - panX, y: e.clientY - panY};
        }
    });

    canvas.addEventListener('mousemove', function(e) {
        var pos = getMousePos(e);
        if (dragging) {
            dragging.x = pos.x;
            dragging.y = pos.y;
            dragging.vx = 0;
            dragging.vy = 0;
        } else if (panning) {
            panX = e.clientX - panStart.x;
            panY = e.clientY - panStart.y;
        } else {
            hoveredNode = findNode(pos);
            canvas.style.cursor = hoveredNode ? 'pointer' : 'grab';
        }
    });

    canvas.addEventListener('mouseup', function(e) {
        if (dragging && dragStart) {
            var pos = getMousePos(e);
            var dx = pos.x - dragStart.x, dy = pos.y - dragStart.y;
            if (dx * dx + dy * dy < 25) {
                // Click — select node
                selectedNode = dragging;
                loadNodeDetail(dragging.id);
            }
        }
        dragging = null;
        panning = false;
    });

    canvas.addEventListener('wheel', function(e) {
        e.preventDefault();
        var delta = e.deltaY > 0 ? 0.9 : 1.1;
        zoom = Math.max(0.2, Math.min(5, zoom * delta));
    }, {passive: false});

    // Zoom buttons
    $('#btn-zoom-in').click(function() { zoom = Math.min(5, zoom * 1.2); });
    $('#btn-zoom-out').click(function() { zoom = Math.max(0.2, zoom * 0.8); });
    $('#btn-zoom-reset').click(function() { zoom = 1; panX = 0; panY = 0; });

    function loadNodeDetail(ip) {
        $('#node-detail-empty').hide();
        $('#node-detail-panel').addClass('show');
        $('#nd-ip').text(ip);

        $.get('/api/siemlite/topology/nodedetail/' + encodeURIComponent(ip), function(data) {
            // Severity breakdown
            var sevHtml = '';
            if (data.severity_breakdown) {
                $.each(data.severity_breakdown, function(sev, cnt) {
                    var col = {critical:'#d9534f',high:'#f0ad4e',medium:'#5bc0de',low:'#5cb85c',informational:'#95a5a6'}[sev]||'#95a5a6';
                    sevHtml += '<span class="sev-dot" style="background:'+col+'"></span>' + sev + ': ' + cnt + ' &nbsp;';
                });
            }
            $('#nd-severity').html(sevHtml);

            // Outbound peers
            var $out = $('#nd-outbound').empty();
            $.each(data.outbound_peers || [], function(i, p) {
                $out.append('<li><span>' + $('<span>').text(p.ip).html() + '</span><span style="opacity:0.6">' + p.count + '</span></li>');
            });
            if (!$out.children().length) $out.append('<li style="opacity:0.5">None</li>');

            // Inbound peers
            var $in = $('#nd-inbound').empty();
            $.each(data.inbound_peers || [], function(i, p) {
                $in.append('<li><span>' + $('<span>').text(p.ip).html() + '</span><span style="opacity:0.6">' + p.count + '</span></li>');
            });
            if (!$in.children().length) $in.append('<li style="opacity:0.5">None</li>');

            // Ports
            var $ports = $('#nd-ports').empty();
            $.each(data.ports_accessed || [], function(i, p) {
                $ports.append('<li><span>:' + $('<span>').text(p.port).html() + '</span><span style="opacity:0.6">' + p.count + '</span></li>');
            });
            if (!$ports.children().length) $ports.append('<li style="opacity:0.5">None</li>');

            // Events
            var $events = $('#nd-events').empty();
            $.each(data.recent_events || [], function(i, ev) {
                var sevCol = {critical:'#d9534f',high:'#f0ad4e',medium:'#5bc0de',low:'#5cb85c'}[ev.severity]||'inherit';
                $events.append(
                    '<div style="padding:3px 0;border-bottom:1px solid rgba(128,128,128,0.1)">' +
                    '<span style="opacity:0.5">' + (ev.timestamp||'').substring(11,19) + '</span> ' +
                    '<span style="color:' + sevCol + '">' + $('<span>').text(ev.action||'').html() + '</span> ' +
                    $('<span>').text((ev.message||'').substring(0,80)).html() +
                    '</div>'
                );
            });
        });
    }

    // Controls
    $('#topo-time, #topo-min').change(function() { loadTopology(); });
    $('#btn-topo-refresh').click(loadTopology);
    window.addEventListener('resize', function() { resize(); });

    resize();
    loadTopology();
});
</script>
