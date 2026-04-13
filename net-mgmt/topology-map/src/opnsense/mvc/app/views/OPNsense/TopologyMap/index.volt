<script>
$(document).ready(function () {
    var autoRefreshMs = 30000;
    var positionsStorageKey = 'tm-graph-positions-v1';
    var graphState = {
        rawNodes: [],
        rawLinks: [],
        selectedNodeId: null,
        zoom: 1,
        panX: 0,
        panY: 0,
        drag: null,
        dragNode: null,
        viewWidth: 700,
        viewHeight: 460,
        manualPositions: {},
        renderedNodePositions: {},
        suppressNextNodeClick: false
    };

    function loadManualPositions() {
        try {
            var raw = sessionStorage.getItem(positionsStorageKey);
            if (!raw) {
                return {};
            }
            var parsed = JSON.parse(raw);
            return (parsed && typeof parsed === 'object') ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    function saveManualPositions() {
        try {
            sessionStorage.setItem(positionsStorageKey, JSON.stringify(graphState.manualPositions || {}));
        } catch (e) {
            // Ignore storage quota/security errors.
        }
    }

    function buildLayoutExportPayload() {
        return {
            version: 1,
            exportedAt: new Date().toISOString(),
            positions: graphState.manualPositions || {}
        };
    }

    function parseLayoutImport(rawText) {
        var parsed;
        try {
            parsed = JSON.parse(rawText);
        } catch (e) {
            return {ok: false, message: '{{ lang._('Invalid JSON file.') }}'};
        }

        var source = parsed;
        if (parsed && typeof parsed === 'object' && parsed.positions && typeof parsed.positions === 'object') {
            source = parsed.positions;
        }

        if (!source || typeof source !== 'object') {
            return {ok: false, message: '{{ lang._('Layout JSON must contain a positions object.') }}'};
        }

        var cleaned = {};
        var keys = Object.keys(source);
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            var item = source[key];
            if (!item || typeof item !== 'object') {
                continue;
            }

            var x = Number(item.x);
            var y = Number(item.y);
            if (!isFinite(x) || !isFinite(y)) {
                continue;
            }

            cleaned[key] = {x: x, y: y, fixed: true};
        }

        return {ok: true, positions: cleaned};
    }

    function escapeHtml(value) {
        return $('<div/>').text(value == null ? '' : value).html();
    }

    function renderSummary(summary) {
        $('#summaryInterfaces').text(summary.interfaces || 0);
        $('#summaryHosts').text(summary.hosts || 0);
        $('#summaryNeighbors').text(summary.neighbors || 0);
        $('#summaryNodes').text(summary.nodes || 0);
        $('#summaryLinks').text(summary.links || 0);
        $('#summaryGeoPoints').text(summary.geoPoints || 0);
    }

    function renderTable(selector, rows, cols) {
        var html = '<table class="table table-striped __nomb"><thead><tr>';
        for (var i = 0; i < cols.length; i++) {
            html += '<th>' + cols[i].label + '</th>';
        }
        html += '</tr></thead><tbody>';

        for (var r = 0; r < rows.length; r++) {
            html += '<tr>';
            for (var c = 0; c < cols.length; c++) {
                var key = cols[c].key;
                var value = rows[r][key] || '';
                html += '<td>' + $('<div/>').text(value).html() + '</td>';
            }
            html += '</tr>';
        }

        html += '</tbody></table>';
        $(selector).html(html);
    }

    function layoutVertical(nodes, x, minY, maxY) {
        if (!nodes.length) {
            return;
        }

        var movable = [];
        for (var i = 0; i < nodes.length; i++) {
            if (!nodes[i].fixed) {
                movable.push(nodes[i]);
            }
        }

        if (!movable.length) {
            return;
        }

        var step = (maxY - minY) / (movable.length + 1);
        for (var m = 0; m < movable.length; m++) {
            movable[m].x = x;
            movable[m].y = minY + ((m + 1) * step);
        }
    }

    function layoutGrid(nodes, minX, maxX, minY, maxY) {
        if (!nodes.length) {
            return;
        }

        var movable = [];
        for (var i = 0; i < nodes.length; i++) {
            if (!nodes[i].fixed) {
                movable.push(nodes[i]);
            }
        }

        if (!movable.length) {
            return;
        }

        var cols = Math.max(1, Math.ceil(Math.sqrt(movable.length)));
        var rows = Math.ceil(movable.length / cols);
        var stepX = (maxX - minX) / (cols + 1);
        var stepY = (maxY - minY) / (rows + 1);

        for (var m = 0; m < movable.length; m++) {
            var col = m % cols;
            var row = Math.floor(m / cols);
            movable[m].x = minX + ((col + 1) * stepX);
            movable[m].y = minY + ((row + 1) * stepY);
        }
    }

    function sanitizeCoordinate(value, fallback) {
        var num = Number(value);
        return isFinite(num) ? num : fallback;
    }

    function getNodeTypeLabel(type) {
        if (type === 'interface') {
            return '{{ lang._('Interface') }}';
        }
        if (type === 'host') {
            return '{{ lang._('Host') }}';
        }
        if (type === 'lldp-neighbor') {
            return '{{ lang._('LLDP Neighbor') }}';
        }
        return '{{ lang._('Other') }}';
    }

    function activeTypeFilter(type) {
        if (type === 'interface') {
            return $('#graphFilterInterface').is(':checked');
        }
        if (type === 'host') {
            return $('#graphFilterHost').is(':checked');
        }
        if (type === 'lldp-neighbor') {
            return $('#graphFilterLldp').is(':checked');
        }
        return $('#graphFilterOther').is(':checked');
    }

    function applyFilters(nodes, links) {
        var term = ($('#graphSearch').val() || '').toLowerCase();
        var nodeMap = {};
        var visibleNodes = [];

        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i] || {};
            var label = (n.label || '').toLowerCase();
            var ip = (n.ip || '').toLowerCase();
            var showByText = (term === '') || (label.indexOf(term) !== -1) || (ip.indexOf(term) !== -1);
            var showByType = activeTypeFilter(n.type || 'unknown');

            if (showByText && showByType) {
                visibleNodes.push(n);
                if (n.id) {
                    nodeMap[n.id] = true;
                }
            }
        }

        var visibleLinks = [];
        for (var l = 0; l < links.length; l++) {
            var link = links[l] || {};
            if (nodeMap[link.from] && nodeMap[link.to]) {
                visibleLinks.push(link);
            }
        }

        return {nodes: visibleNodes, links: visibleLinks};
    }

    function runForceLayout(nodes, links, width, height) {
        if (nodes.length > 150) {
            return;
        }

        var indexById = {};
        var anchors = {};
        for (var i = 0; i < nodes.length; i++) {
            nodes[i].vx = sanitizeCoordinate(nodes[i].vx, 0);
            nodes[i].vy = sanitizeCoordinate(nodes[i].vy, 0);
            nodes[i].x = sanitizeCoordinate(nodes[i].x, width / 2);
            nodes[i].y = sanitizeCoordinate(nodes[i].y, height / 2);
            indexById[nodes[i].id] = i;
            anchors[nodes[i].id] = {x: nodes[i].x, y: nodes[i].y};
        }

        for (var iter = 0; iter < 85; iter++) {
            for (var a = 0; a < nodes.length; a++) {
                var n1 = nodes[a];

                if (!n1.fixed) {
                    // Keep nodes around their initial lanes to avoid collapsing into one cluster.
                    n1.vx += (anchors[n1.id].x - n1.x) * 0.003;
                    n1.vy += (anchors[n1.id].y - n1.y) * 0.003;
                }

                for (var b = a + 1; b < nodes.length; b++) {
                    var n2 = nodes[b];
                    var dx = n2.x - n1.x;
                    var dy = n2.y - n1.y;
                    var dist2 = (dx * dx) + (dy * dy) + 0.01;
                    var repulse = 9000 / dist2;

                    n1.vx -= repulse * dx * 0.001;
                    n1.vy -= repulse * dy * 0.001;
                    n2.vx += repulse * dx * 0.001;
                    n2.vy += repulse * dy * 0.001;
                }
            }

            for (var li = 0; li < links.length; li++) {
                var lk = links[li] || {};
                var fromIdx = indexById[lk.from];
                var toIdx = indexById[lk.to];
                if (typeof fromIdx === 'undefined' || typeof toIdx === 'undefined') {
                    continue;
                }

                var src = nodes[fromIdx];
                var dst = nodes[toIdx];
                var ldx = dst.x - src.x;
                var ldy = dst.y - src.y;
                var dist = Math.sqrt((ldx * ldx) + (ldy * ldy)) || 1;
                var target = 140;
                var spring = (dist - target) * 0.0022;

                src.vx += spring * ldx;
                src.vy += spring * ldy;
                dst.vx -= spring * ldx;
                dst.vy -= spring * ldy;
            }

            for (var ni = 0; ni < nodes.length; ni++) {
                var n = nodes[ni];
                if (n.fixed) {
                    continue;
                }
                n.vx *= 0.84;
                n.vy *= 0.84;
                n.vx = Math.max(-7, Math.min(7, n.vx));
                n.vy = Math.max(-7, Math.min(7, n.vy));
                n.x += n.vx;
                n.y += n.vy;
                n.x = sanitizeCoordinate(n.x, anchors[n.id].x);
                n.y = sanitizeCoordinate(n.y, anchors[n.id].y);
                n.x = Math.max(24, Math.min(width - 24, n.x));
                n.y = Math.max(24, Math.min(height - 24, n.y));
            }
        }
    }

    function spreadOverlaps(nodes, width, height) {
        var groups = {};
        var key;
        var i;

        for (i = 0; i < nodes.length; i++) {
            key = Math.round(nodes[i].x / 8) + ':' + Math.round(nodes[i].y / 8);
            if (!groups[key]) {
                groups[key] = [];
            }
            groups[key].push(nodes[i]);
        }

        Object.keys(groups).forEach(function (groupKey) {
            var g = groups[groupKey];
            if (g.length < 2) {
                return;
            }

            var cx = g[0].x;
            var cy = g[0].y;
            var radius = 12;
            for (var gi = 0; gi < g.length; gi++) {
                var angle = (Math.PI * 2 * gi) / g.length;
                g[gi].x = Math.max(24, Math.min(width - 24, cx + Math.cos(angle) * radius));
                g[gi].y = Math.max(24, Math.min(height - 24, cy + Math.sin(angle) * radius));
                radius += 4;
            }
        });

        // Final collision pass to increase minimum distance between node centers.
        for (var pass = 0; pass < 2; pass++) {
            for (var a = 0; a < nodes.length; a++) {
                for (var b = a + 1; b < nodes.length; b++) {
                    var n1 = nodes[a];
                    var n2 = nodes[b];
                    var dx = n2.x - n1.x;
                    var dy = n2.y - n1.y;
                    var dist = Math.sqrt((dx * dx) + (dy * dy));
                    if (!isFinite(dist) || dist < 0.001) {
                        dist = 0.001;
                        dx = 0.001;
                        dy = 0;
                    }
                    var minDist = 20;
                    if (dist >= minDist) {
                        continue;
                    }

                    var push = (minDist - dist) / 2;
                    var ux = dx / dist;
                    var uy = dy / dist;

                    if (!n1.fixed) {
                        n1.x = Math.max(24, Math.min(width - 24, n1.x - (ux * push)));
                        n1.y = Math.max(24, Math.min(height - 24, n1.y - (uy * push)));
                    }
                    if (!n2.fixed) {
                        n2.x = Math.max(24, Math.min(width - 24, n2.x + (ux * push)));
                        n2.y = Math.max(24, Math.min(height - 24, n2.y + (uy * push)));
                    }
                }
            }
        }
    }

    function updateViewportTransform() {
        var $stage = $('#tm-stage');
        if (!$stage.length) {
            return;
        }

        $stage.attr('transform', 'translate(' + graphState.panX + ' ' + graphState.panY + ') scale(' + graphState.zoom + ')');
        $('#graphZoomValue').text(Math.round(graphState.zoom * 100) + '%');
    }

    function resetGraphView() {
        graphState.zoom = 1;
        graphState.panX = 0;
        graphState.panY = 0;
        updateViewportTransform();
    }

    function bindGraphInteractions() {
        var $svg = $('#topologyGraph svg');
        if (!$svg.length) {
            return;
        }

        function eventToGraphCoordinates(ev) {
            var rect = $svg[0].getBoundingClientRect();
            var viewBox = ($svg.attr('viewBox') || '').split(/\s+/);
            var vbWidth = parseFloat(viewBox[2]) || graphState.viewWidth;
            var vbHeight = parseFloat(viewBox[3]) || graphState.viewHeight;
            var baseX = (ev.clientX - rect.left) * (vbWidth / rect.width);
            var baseY = (ev.clientY - rect.top) * (vbHeight / rect.height);

            return {
                x: (baseX - graphState.panX) / graphState.zoom,
                y: (baseY - graphState.panY) / graphState.zoom
            };
        }

        $svg.off('wheel').on('wheel', function (ev) {
            ev.preventDefault();
            var delta = ev.originalEvent.deltaY > 0 ? -0.1 : 0.1;
            graphState.zoom = Math.max(0.4, Math.min(2.8, graphState.zoom + delta));
            updateViewportTransform();
        });

        $svg.off('mousedown').on('mousedown', function (ev) {
            if ($(ev.target).closest('circle.tm-node').length) {
                return;
            }
            graphState.drag = {
                startX: ev.clientX,
                startY: ev.clientY,
                panX: graphState.panX,
                panY: graphState.panY
            };
        });

        $(document).off('mousemove.tmgraph').on('mousemove.tmgraph', function (ev) {
            if (graphState.dragNode) {
                var nodeId = graphState.dragNode.id;
                var point = eventToGraphCoordinates(ev);
                var x = Math.max(24, Math.min(graphState.viewWidth - 24, point.x));
                var y = Math.max(24, Math.min(graphState.viewHeight - 24, point.y));

                graphState.manualPositions[nodeId] = {x: x, y: y, fixed: true};
                graphState.renderedNodePositions[nodeId] = {x: x, y: y};

                var $node = $('#topologyGraph .tm-node[data-node-id="' + nodeId.replace(/"/g, '&quot;') + '"]');
                var $text = $('#topologyGraph .tm-node-label[data-node-id="' + nodeId.replace(/"/g, '&quot;') + '"]');
                $node.attr('cx', x).attr('cy', y);
                $text.attr('x', x + 12).attr('y', y + 4);

                $('#topologyGraph .tm-link').each(function () {
                    var $line = $(this);
                    var fromId = $line.attr('data-from');
                    var toId = $line.attr('data-to');
                    var fromPos = graphState.renderedNodePositions[fromId];
                    var toPos = graphState.renderedNodePositions[toId];
                    if (fromPos && toPos) {
                        $line.attr('x1', fromPos.x).attr('y1', fromPos.y).attr('x2', toPos.x).attr('y2', toPos.y);
                    }
                });
                return;
            }

            if (!graphState.drag) {
                return;
            }
            graphState.panX = graphState.drag.panX + (ev.clientX - graphState.drag.startX);
            graphState.panY = graphState.drag.panY + (ev.clientY - graphState.drag.startY);
            updateViewportTransform();
        });

        $(document).off('mouseup.tmgraph').on('mouseup.tmgraph', function () {
            if (graphState.dragNode) {
                saveManualPositions();
                graphState.dragNode = null;
                graphState.suppressNextNodeClick = true;
                setTimeout(function () {
                    graphState.suppressNextNodeClick = false;
                }, 80);
            }
            graphState.drag = null;
        });

        $('#topologyGraph .tm-node').off('mousedown').on('mousedown', function (ev) {
            ev.stopPropagation();
            var id = $(this).attr('data-node-id') || '';
            if (!id) {
                return;
            }
            graphState.dragNode = {id: id};
        });

        $('#topologyGraph .tm-node').off('click').on('click', function () {
            if (graphState.suppressNextNodeClick) {
                return;
            }
            var id = $(this).attr('data-node-id') || '';
            graphState.selectedNodeId = (graphState.selectedNodeId === id) ? null : id;
            renderGraph(graphState.rawNodes, graphState.rawLinks);
        });
    }

    function renderGraph(nodes, links) {
        graphState.rawNodes = Array.isArray(nodes) ? nodes : [];
        graphState.rawLinks = Array.isArray(links) ? links : [];

        var filtered = applyFilters(graphState.rawNodes, graphState.rawLinks);
        var filteredNodes = filtered.nodes;
        var filteredLinks = filtered.links;

        var $graph = $('#topologyGraph');
        var width = Math.max(700, $graph.innerWidth() || 700);
        var height = 460;
        graphState.viewWidth = width;
        graphState.viewHeight = height;

        if (!Array.isArray(filteredNodes) || filteredNodes.length === 0) {
            $graph.html('<div class="text-muted" style="padding:12px">{{ lang._('No topology nodes found for active filters.') }}</div>');
            return;
        }

        var interfaces = [];
        var hosts = [];
        var neighbors = [];
        var others = [];
        var nodeMap = {};
        var renderNodes = [];

        for (var i = 0; i < filteredNodes.length; i++) {
            var n = $.extend({}, filteredNodes[i]);
            n.id = n.id || ('node-' + i);
            n.label = n.label || n.id;
            n.type = n.type || 'unknown';
            n.x = width / 2;
            n.y = height / 2;
            n.fixed = false;
            renderNodes.push(n);
            nodeMap[n.id] = n;

            if (n.type === 'interface') {
                interfaces.push(n);
            } else if (n.type === 'host') {
                hosts.push(n);
            } else if (n.type === 'lldp-neighbor') {
                neighbors.push(n);
            } else {
                others.push(n);
            }
        }

        for (var mi = 0; mi < renderNodes.length; mi++) {
            var nodeWithManual = renderNodes[mi];
            var manualPos = graphState.manualPositions[nodeWithManual.id];
            if (!manualPos) {
                continue;
            }

            nodeWithManual.x = Math.max(24, Math.min(width - 24, sanitizeCoordinate(manualPos.x, nodeWithManual.x)));
            nodeWithManual.y = Math.max(24, Math.min(height - 24, sanitizeCoordinate(manualPos.y, nodeWithManual.y)));
            nodeWithManual.fixed = true;
        }

        layoutVertical(interfaces, 130, 30, height - 30);
        layoutGrid(hosts, Math.floor(width * 0.34), Math.floor(width * 0.63), 35, height - 35);
        layoutVertical(neighbors, width - 130, 30, height - 30);
        layoutGrid(others, Math.floor(width * 0.66), width - 45, 40, height - 40);
        runForceLayout(renderNodes, filteredLinks, width, height);
        spreadOverlaps(renderNodes, width, height);

        var selected = graphState.selectedNodeId;
        var adjacency = {};
        if (selected) {
            adjacency[selected] = true;
            for (var ai = 0; ai < filteredLinks.length; ai++) {
                var alink = filteredLinks[ai] || {};
                if (alink.from === selected) {
                    adjacency[alink.to] = true;
                }
                if (alink.to === selected) {
                    adjacency[alink.from] = true;
                }
            }
        }

        var colors = {
            'interface': '#0073a8',
            'host': '#2f9e44',
            'lldp-neighbor': '#cc4b00',
            'unknown': '#6b7280'
        };

        graphState.renderedNodePositions = {};
        for (var rp = 0; rp < renderNodes.length; rp++) {
            renderNodes[rp].x = sanitizeCoordinate(renderNodes[rp].x, width / 2);
            renderNodes[rp].y = sanitizeCoordinate(renderNodes[rp].y, height / 2);
            graphState.renderedNodePositions[renderNodes[rp].id] = {
                x: renderNodes[rp].x,
                y: renderNodes[rp].y
            };
        }

        var svg = '';
        svg += '<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '">';
        svg += '<defs>';
        svg += '<marker id="tm-arrow" markerWidth="10" markerHeight="8" refX="8" refY="4" orient="auto">';
        svg += '<path d="M0,0 L10,4 L0,8 z" fill="#8a8f98"></path>';
        svg += '</marker>';
        svg += '</defs>';
        svg += '<rect x="1" y="1" width="' + (width - 2) + '" height="' + (height - 2) + '" fill="#f8fbfd" stroke="#dde4ea" stroke-width="1"></rect>';
        svg += '<g id="tm-stage">';

        for (var li = 0; li < filteredLinks.length; li++) {
            var link = filteredLinks[li] || {};
            var fromNode = nodeMap[link.from];
            var toNode = nodeMap[link.to];
            if (!fromNode || !toNode) {
                continue;
            }

            var highlighted = !!selected && (link.from === selected || link.to === selected);
            var linkOpacity = !selected ? '0.92' : (highlighted ? '1' : '0.20');
            var linkColor = highlighted ? '#0b5a7a' : '#8a8f98';
            var linkWidth = highlighted ? '2.4' : '1.3';

            svg += '<line class="tm-link" data-from="' + escapeHtml(link.from) + '" data-to="' + escapeHtml(link.to) + '" x1="' + fromNode.x + '" y1="' + fromNode.y + '" x2="' + toNode.x + '" y2="' + toNode.y + '" ';
            svg += 'stroke="' + linkColor + '" stroke-width="' + linkWidth + '" opacity="' + linkOpacity + '" marker-end="url(#tm-arrow)"></line>';
        }

        for (var ni = 0; ni < renderNodes.length; ni++) {
            var node = renderNodes[ni];
            var color = colors[node.type] || colors.unknown;
            var tip = escapeHtml(getNodeTypeLabel(node.type) + ' | ' + (node.label || node.id) + (node.ip ? (' | ' + node.ip) : ''));
            var isSelected = selected && selected === node.id;
            var isAdjacent = selected && adjacency[node.id];
            var opacity = !selected ? '1' : (isAdjacent ? '1' : '0.25');
            var stroke = isSelected ? '#111827' : '#ffffff';
            var strokeWidth = isSelected ? '3' : '2';
            var radius = node.fixed ? 10.5 : 9;

            svg += '<g opacity="' + opacity + '">';
            svg += '<title>' + tip + '</title>';
            svg += '<circle class="tm-node" data-node-id="' + escapeHtml(node.id) + '" cx="' + node.x + '" cy="' + node.y + '" r="' + radius + '" fill="' + color + '" stroke="' + stroke + '" stroke-width="' + strokeWidth + '"></circle>';
            svg += '<text class="tm-node-label" data-node-id="' + escapeHtml(node.id) + '" x="' + (node.x + 12) + '" y="' + (node.y + 4) + '" font-size="11" fill="#1f2937">' + escapeHtml(node.label) + '</text>';
            svg += '</g>';
        }

        svg += '</g>';
        svg += '</svg>';
        $graph.html(svg);
        updateViewportTransform();
        bindGraphInteractions();
    }

    function loadData() {
        ajaxCall('/api/topologymap/service/discover', {}, function (data, status) {
            if (status !== 'success' || data['status'] !== 'ok') {
                $('#responseMsg').removeClass('hidden alert-info').addClass('alert-danger').html(data['message'] || '{{ lang._('Unable to load topology data.') }}');
                return;
            }

            $('#responseMsg').addClass('hidden').removeClass('alert-danger').html('');
            var summary = data['summary'] || {};
            summary.geoPoints = (data['meta'] && data['meta']['geo_points']) ? data['meta']['geo_points'] : 0;
            renderSummary(summary);

            var nodes = (data['topology'] && data['topology']['nodes']) ? data['topology']['nodes'] : [];
            var links = (data['topology'] && data['topology']['links']) ? data['topology']['links'] : [];
            var nodeLabels = {};

            for (var i = 0; i < nodes.length; i++) {
                var currentNode = nodes[i] || {};
                if (currentNode.id) {
                    nodeLabels[currentNode.id] = currentNode.label || currentNode.id;
                }
            }

            var linksForTable = [];
            for (var l = 0; l < links.length; l++) {
                var currentLink = links[l] || {};
                linksForTable.push({
                    from: nodeLabels[currentLink.from] || currentLink.from || '',
                    to: nodeLabels[currentLink.to] || currentLink.to || '',
                    type: currentLink.type || ''
                });
            }

            renderGraph(nodes, links);

            renderTable('#nodesTable', nodes, [
                {key: 'label', label: '{{ lang._('Node') }}'},
                {key: 'type', label: '{{ lang._('Type') }}'},
                {key: 'ip', label: '{{ lang._('IP') }}'},
                {key: 'mac', label: '{{ lang._('MAC') }}'},
                {key: 'source', label: '{{ lang._('Source') }}'}
            ]);

            renderTable('#linksTable', linksForTable, [
                {key: 'from', label: '{{ lang._('From') }}'},
                {key: 'to', label: '{{ lang._('To') }}'},
                {key: 'type', label: '{{ lang._('Type') }}'}
            ]);

            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        });
    }

    function filteredLinksCount() {
        var cnt = $('#topologyGraph line').length;
        return cnt || 0;
    }

    function bindGraphControls() {
        $('#graphFilterInterface,#graphFilterHost,#graphFilterLldp,#graphFilterOther').on('change', function () {
            renderGraph(graphState.rawNodes, graphState.rawLinks);
            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        });

        $('#graphSearch').on('input', function () {
            renderGraph(graphState.rawNodes, graphState.rawLinks);
            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        });

        $('#graphZoomIn').on('click', function () {
            graphState.zoom = Math.min(2.8, graphState.zoom + 0.15);
            updateViewportTransform();
        });

        $('#graphZoomOut').on('click', function () {
            graphState.zoom = Math.max(0.4, graphState.zoom - 0.15);
            updateViewportTransform();
        });

        $('#graphResetView').on('click', function () {
            graphState.selectedNodeId = null;
            resetGraphView();
            renderGraph(graphState.rawNodes, graphState.rawLinks);
            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        });

        $('#graphResetLayout').on('click', function () {
            graphState.manualPositions = {};
            saveManualPositions();
            renderGraph(graphState.rawNodes, graphState.rawLinks);
            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        });

        $('#graphExportLayout').on('click', function () {
            var payload = buildLayoutExportPayload();
            var json = JSON.stringify(payload, null, 2);
            var blob = new Blob([json], {type: 'application/json'});
            var url = URL.createObjectURL(blob);
            var stamp = new Date().toISOString().replace(/[:]/g, '-');

            var link = document.createElement('a');
            link.href = url;
            link.download = 'topology-layout-' + stamp + '.json';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        });

        $('#graphImportLayout').on('click', function () {
            $('#graphImportLayoutFile').val('');
            $('#graphImportLayoutFile').trigger('click');
        });

        $('#graphImportLayoutFile').on('change', function (ev) {
            var input = ev.target;
            if (!input.files || !input.files.length) {
                return;
            }

            var file = input.files[0];
            var reader = new FileReader();
            reader.onload = function (loadEv) {
                var result = parseLayoutImport(String(loadEv.target.result || ''));
                if (!result.ok) {
                    $('#responseMsg').removeClass('hidden alert-info').addClass('alert-danger').text(result.message || '{{ lang._('Failed to import layout.') }}');
                    return;
                }

                graphState.manualPositions = result.positions || {};
                saveManualPositions();
                renderGraph(graphState.rawNodes, graphState.rawLinks);
                $('#graphVisibleNodes').text($('.tm-node').length || 0);
                $('#graphVisibleLinks').text(filteredLinksCount());
                $('#responseMsg').removeClass('hidden alert-danger').addClass('alert-info').text('{{ lang._('Layout imported successfully.') }}');
            };

            reader.onerror = function () {
                $('#responseMsg').removeClass('hidden alert-info').addClass('alert-danger').text('{{ lang._('Unable to read selected file.') }}');
            };

            reader.readAsText(file);
        });
    }

    mapDataToFormUI({'frm_topologymap': '/api/topologymap/settings/get'});

    $('#saveAct').click(function () {
        saveFormToEndpoint('/api/topologymap/settings/set', 'frm_topologymap', function () {
            $('#responseMsg').removeClass('hidden alert-danger').addClass('alert-info').html('{{ lang._('Settings saved.') }}');
            loadData();
        });
    });

    $('#refreshAct').click(function () {
        loadData();
    });

    var resizeTimer = null;
    $(window).resize(function () {
        if (resizeTimer) {
            clearTimeout(resizeTimer);
        }
        resizeTimer = setTimeout(function () {
            renderGraph(graphState.rawNodes, graphState.rawLinks);
            $('#graphVisibleNodes').text($('.tm-node').length || 0);
            $('#graphVisibleLinks').text(filteredLinksCount());
        }, 150);
    });

    setInterval(function () {
        loadData();
    }, autoRefreshMs);

    graphState.manualPositions = loadManualPositions();
    bindGraphControls();
    loadData();
});
</script>

<div class="alert alert-info" role="alert">
    {{ lang._('Automatic topology mapping using LLDP, ARP and NDP discovery. Geo map output is available for future dashboard/map widgets.') }}
</div>

<div class="alert alert-success" role="alert">
    {{ lang._('Interactive graph view supports filters, search, zoom/pan and link highlighting. It updates every 30 seconds.') }}
</div>

<div class="alert hidden" role="alert" id="responseMsg"></div>

<div class="row">
    <div class="col-md-12">
        <div class="content-box tab-content table-responsive">
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr><th class="listtopic">{{ lang._('Discovery Summary') }}</th></tr>
                <tr>
                    <td>
                        <strong>{{ lang._('Interfaces') }}:</strong> <span id="summaryInterfaces">0</span> |
                        <strong>{{ lang._('Hosts') }}:</strong> <span id="summaryHosts">0</span> |
                        <strong>{{ lang._('LLDP Neighbors') }}:</strong> <span id="summaryNeighbors">0</span> |
                        <strong>{{ lang._('Nodes') }}:</strong> <span id="summaryNodes">0</span> |
                        <strong>{{ lang._('Links') }}:</strong> <span id="summaryLinks">0</span> |
                        <strong>{{ lang._('Geo Points') }}:</strong> <span id="summaryGeoPoints">0</span>
                    </td>
                </tr>
            </table>
        </div>
    </div>
</div>

<div class="col-md-12" style="margin-top: 10px;">
    {{ partial("layout_partials/base_form",['fields':settings,'id':'frm_topologymap'])}}
</div>

<div class="col-md-12" style="margin-top: 10px;">
    <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b></button>
    <button class="btn btn-default" id="refreshAct" type="button"><b>{{ lang._('Refresh Discovery') }}</b></button>
</div>

<div class="row" style="margin-top: 10px;">
    <div class="col-md-12">
        <div class="content-box tab-content table-responsive">
            <div style="padding: 10px 12px 6px 12px; border-bottom: 1px solid #e5e7eb; display: flex; flex-wrap: wrap; gap: 10px; align-items: center;">
                <label style="margin:0; font-weight: normal;"><input type="checkbox" id="graphFilterInterface" checked="checked"> {{ lang._('Interface') }}</label>
                <label style="margin:0; font-weight: normal;"><input type="checkbox" id="graphFilterHost" checked="checked"> {{ lang._('Host') }}</label>
                <label style="margin:0; font-weight: normal;"><input type="checkbox" id="graphFilterLldp" checked="checked"> {{ lang._('LLDP Neighbor') }}</label>
                <label style="margin:0; font-weight: normal;"><input type="checkbox" id="graphFilterOther" checked="checked"> {{ lang._('Other') }}</label>
                <input type="text" id="graphSearch" class="form-control" style="max-width: 260px;" placeholder="{{ lang._('Filter by node name or IP...') }}">
                <button class="btn btn-default btn-xs" id="graphZoomOut" type="button">-</button>
                <button class="btn btn-default btn-xs" id="graphZoomIn" type="button">+</button>
                <button class="btn btn-default btn-xs" id="graphResetView" type="button">{{ lang._('Reset View') }}</button>
                <button class="btn btn-default btn-xs" id="graphResetLayout" type="button">{{ lang._('Reset Layout') }}</button>
                <button class="btn btn-default btn-xs" id="graphExportLayout" type="button">{{ lang._('Export Layout') }}</button>
                <button class="btn btn-default btn-xs" id="graphImportLayout" type="button">{{ lang._('Import Layout') }}</button>
                <input type="file" id="graphImportLayoutFile" accept="application/json,.json" style="display:none;">
                <span class="text-muted" style="margin-left:auto">{{ lang._('Zoom') }}: <span id="graphZoomValue">100%</span> | {{ lang._('Visible Nodes') }}: <span id="graphVisibleNodes">0</span> | {{ lang._('Visible Links') }}: <span id="graphVisibleLinks">0</span></span>
            </div>
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr><th class="listtopic">{{ lang._('Topology Graph') }}</th></tr>
                <tr><td id="topologyGraph"></td></tr>
            </table>
            <div class="help-block" style="padding: 8px 12px 12px 12px; margin: 0;">
                <span style="display:inline-block;width:10px;height:10px;background:#0073a8;border-radius:50%;margin-right:6px;"></span>{{ lang._('Interface') }}
                <span style="display:inline-block;width:10px;height:10px;background:#2f9e44;border-radius:50%;margin-left:18px;margin-right:6px;"></span>{{ lang._('Host') }}
                <span style="display:inline-block;width:10px;height:10px;background:#cc4b00;border-radius:50%;margin-left:18px;margin-right:6px;"></span>{{ lang._('LLDP Neighbor') }}
            </div>
        </div>
    </div>
</div>

<div class="row" style="margin-top: 10px;">
    <div class="col-md-6">
        <div class="content-box tab-content table-responsive">
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr><th class="listtopic">{{ lang._('Nodes') }}</th></tr>
                <tr><td id="nodesTable"></td></tr>
            </table>
        </div>
    </div>
    <div class="col-md-6">
        <div class="content-box tab-content table-responsive">
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr><th class="listtopic">{{ lang._('Links') }}</th></tr>
                <tr><td id="linksTable"></td></tr>
            </table>
        </div>
    </div>
</div>
