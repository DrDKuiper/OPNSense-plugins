<script>
$(document).ready(function () {

    // ========================================================
    // State
    // ========================================================
    var hub = {
        items:       [],
        assignments: {},  // itemId -> categoryName
        categories:  ['VPN & Tunneling', 'Network & Proxy', 'Security',
                      'Monitoring', 'DNS & DHCP', 'Mail', 'Backup', 'System', 'Other'],
        editMode:    false,
        hideEnabled: false   // true when servicehub theme overlay is active
    };

    var HUB_ONLY_STORAGE_KEY = 'servicehub.hubOnly';
    var hubOnlyObserver = null;

    // Keyword → default category mapping (matches against plugin + name + url + section)
    var AUTO_MAP = [
        ['VPN & Tunneling',   ['openvpn', 'strongswan', 'tinc', 'zerotier', 'openconnect',
                               'wireguard', 'ipsec', 'vpn', 'tunnel']],
        ['Network & Proxy',   ['haproxy', 'relayd', 'nginx', 'squid', 'icap', 'proxy',
                               'siprox', 'sslh', 'tayga', 'upnp', 'frr', 'freeradius',
                               'radsec', 'shadowsocks', 'chrony', 'mdns', 'ndp', 'ndproxy',
                               'realtek', 'turnserver', 'udpbroadcast', 'wol', 'natpmp',
                               'ntpd', 'google-cloud', 'caddy']],
        ['Security',          ['clamav', 'crowdsec', 'acme', 'maltrail', 'stunnel', 'wazuh',
                               'netbird', 'tailscale', 'intrusion', 'snort', 'etpro',
                               'qfeeds', 'tor', 'openconnect', 'etopen', 'ptopen', 'snortvrt']],
        ['Monitoring',        ['collectd', 'telegraf', 'ntopng', 'zabbix', 'netdata',
                               'node_exporter', 'lldpd', 'vnstat', 'iperf', 'topology',
                               'telegram', 'munin', 'nrpe', 'netsnmp', 'net-snmp',
                               'topology-map']],
        ['DNS & DHCP',        ['bind', 'dnscrypt', 'ddclient', 'rfc2136', 'dhcp', 'isc-dhcp']],
        ['Mail',              ['postfix', 'rspamd', 'mail']],
        ['Backup',            ['backup', 'gdrive', 'nextcloud', 'sftp-backup', 'git-backup']],
        ['System',            ['puppet', 'smart', 'dmidecode', 'cpu-microcode', 'hw-probe',
                               'beats', 'apcupsd', 'nut', 'lcdproc', 'virtualbox', 'vmware',
                               'xen', 'qemu', 'dec-hw', 'redis']]
    ];

    var CAT_ICONS = {
        'VPN & Tunneling':   'fa fa-lock',
        'Network & Proxy':   'fa fa-exchange',
        'Security':          'fa fa-shield',
        'Monitoring':        'fa fa-bar-chart',
        'DNS & DHCP':        'fa fa-server',
        'Mail':              'fa fa-envelope',
        'Backup':            'fa fa-cloud-upload',
        'System':            'fa fa-cog',
        'Other':             'fa fa-plug'
    };

    var CAT_COLORS = {
        'VPN & Tunneling':   '#5b7ebe',
        'Network & Proxy':   '#3a9fbe',
        'Security':          '#c0392b',
        'Monitoring':        '#2980b9',
        'DNS & DHCP':        '#27ae60',
        'Mail':              '#8e44ad',
        'Backup':            '#16a085',
        'System':            '#7f8c8d',
        'Other':             '#95a5a6'
    };

    // ========================================================
    // Helpers
    // ========================================================
    function esc(s) {
        return $('<div/>').text(s).html();
    }

    function autoCategory(item) {
        var haystack = (item.plugin + ' ' + item.name + ' ' + item.url + ' ' + item.section).toLowerCase();
        for (var i = 0; i < AUTO_MAP.length; i++) {
            var keywords = AUTO_MAP[i][1];
            for (var j = 0; j < keywords.length; j++) {
                if (haystack.indexOf(keywords[j]) !== -1) {
                    return AUTO_MAP[i][0];
                }
            }
        }
        return 'Other';
    }

    function getCategory(item) {
        return hub.assignments[item.id] || autoCategory(item);
    }

    function catIcon(cat) {
        return CAT_ICONS[cat] || 'fa fa-th-large';
    }

    function catColor(cat) {
        return CAT_COLORS[cat] || '#95a5a6';
    }

    function getPersistedHubOnly() {
        try {
            return window.localStorage.getItem(HUB_ONLY_STORAGE_KEY) === '1';
        } catch (e) {
            return false;
        }
    }

    function setPersistedHubOnly(enable) {
        try {
            window.localStorage.setItem(HUB_ONLY_STORAGE_KEY, enable ? '1' : '0');
        } catch (e) {}
    }

    function ensureHubOnlyObserver() {
        if (hubOnlyObserver || !window.MutationObserver) {
            return;
        }

        var nav = document.getElementById('navigation');
        if (!nav) {
            return;
        }

        hubOnlyObserver = new MutationObserver(function () {
            if (hub.hideEnabled) {
                applyHubOnlyFallback(true);
            }
        });
        hubOnlyObserver.observe(nav, { childList: true, subtree: true });
    }

    // ========================================================
    // Hub-only fallback (sidebar hide without theme switch)
    // ========================================================
    function applyHubOnlyFallback(enable) {
        var styleId = 'servicehub-hubonly-style';
        var cls = 'hubonly-hidden-item';

        if (!document.getElementById(styleId)) {
            $('head').append(
                $('<style id="' + styleId + '"></style>').text(
                    '.' + cls + ' { display: none !important; }'
                )
            );
        }

        var $nav = $('#navigation');
        if (!$nav.length) {
            return;
        }

        $nav.find('a.' + cls + ', li.' + cls).removeClass(cls);
        if (!enable) {
            return;
        }

        var marked = 0;

        // OPNsense 25.x style menu tree from diagnostics:
        // #navigation > #mainmenu > #Services
        var $servicesRoot = $nav.find('#mainmenu > #Services').first();
        if ($servicesRoot.length) {
            $servicesRoot.find('a[href]').not('[href*="servicehub"]').each(function () {
                $(this).addClass(cls);
                $(this).closest('li').addClass(cls);
            });
            marked = $servicesRoot.find('a.' + cls).length;
        }

        var containerSelector = [
            '#services',
            '[data-section="Services"]',
            '[data-category="Services"]',
            'li[id*="services"]',
            'ul[id*="services"]',
            'div[id*="services"]'
        ].join(',');

        if (marked === 0) {
            $nav.find('a[href*="servicehub"]').each(function () {
                var $container = $(this).closest(containerSelector);
                if (!$container.length) {
                    return;
                }

                $container.find('a[href]').not('[href*="servicehub"]').each(function () {
                    var href = $(this).attr('href') || '';
                    if (href.indexOf('/ui/') === 0 || href.indexOf('.php') !== -1) {
                        $(this).addClass(cls);
                        $(this).closest('li').addClass(cls);
                        marked++;
                    }
                });
            });
        }

        // Last-resort fallback for unknown sidebar HTML variants.
        if (marked === 0) {
            $nav.find('a.list-group-item[href^="/ui/"]')
                .not('[href*="servicehub"]')
                .not('[href*="/ui/dashboard"]')
                .not('[href*="/ui/firewall"]')
                .not('[href*="/ui/interfaces"]')
                .not('[href*="/ui/diagnostics"]')
                .not('[href*="/ui/routing"]')
                .not('[href*="/ui/reporting"]')
                .not('[href*="/ui/ids"]')
                .not('[href*="/ui/trafficshaper"]')
                .not('[href*="/ui/captiveportal"]')
                .not('[href*="/ui/certs"]')
                .each(function () {
                    $(this).addClass(cls);
                    $(this).closest('li').addClass(cls);
                });
        }
    }

    // ========================================================
    // Hub view (card grid)
    // ========================================================
    function renderHub() {
        var $c = $('#hubContent').empty();

        // Group items by effective category
        var grouped = {};
        hub.categories.forEach(function (cat) { grouped[cat] = []; });

        hub.items.forEach(function (item) {
            var cat = getCategory(item);
            if (!grouped.hasOwnProperty(cat)) {
                if (hub.categories.indexOf(cat) === -1) {
                    hub.categories.push(cat);
                }
                grouped[cat] = [];
            }
            grouped[cat].push(item);
        });

        var $row = $('<div class="row"></div>').css({margin: '0 -6px'});

        hub.categories.forEach(function (cat) {
            var items = (grouped[cat] || []).slice().sort(function (a, b) {
                return a.name.localeCompare(b.name);
            });

            var accentColor = catColor(cat);

            var $col = $('<div class="col-lg-3 col-md-4 col-sm-6 col-xs-12"></div>')
                .css({padding: '6px'});

            var $panel = $('<div class="panel panel-default"></div>')
                .css({marginBottom: 0, minHeight: '80px', borderTop: '3px solid ' + accentColor});

            // Panel heading
            var $head = $('<div class="panel-heading"></div>').css({
                padding: '8px 12px',
                fontWeight: '600',
                fontSize: '13px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
            });
            var $title = $('<span></span>');
            $title.append(
                $('<i></i>').addClass(catIcon(cat)).css({marginRight: '6px', color: accentColor}),
                document.createTextNode(cat)
            );
            $head.append($title);
            if (items.length > 0) {
                $head.append(
                    $('<span class="badge"></span>').css({
                        background: accentColor,
                        color: '#fff'
                    }).text(items.length)
                );
            }

            // Panel body
            var $body = $('<div class="panel-body"></div>').css({padding: '6px 8px'});

            if (items.length === 0) {
                $body.append(
                    $('<div></div>').css({
                        color: '#bbb', fontSize: '12px', textAlign: 'center', padding: '12px 0'
                    }).text('No plugins assigned')
                );
            } else {
                items.forEach(function (item) {
                    var $link = $('<a></a>')
                        .attr('href', item.url)
                        .css({
                            display: 'flex',
                            alignItems: 'center',
                            padding: '3px 6px',
                            borderRadius: '3px',
                            fontSize: '13px',
                            color: 'inherit',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            textDecoration: 'none'
                        })
                        .hover(
                            function () { $(this).css('background', 'rgba(0,0,0,0.06)'); },
                            function () { $(this).css('background', ''); }
                        );
                    $link.append(
                        $('<i></i>').addClass(item.icon || 'fa fa-plug').css({
                            width: '16px', textAlign: 'center',
                            marginRight: '6px', opacity: '0.65', flexShrink: 0
                        }),
                        $('<span></span>').text(item.name).css({
                            overflow: 'hidden', textOverflow: 'ellipsis'
                        })
                    );
                    $body.append($link);
                });
            }

            $panel.append($head, $body);
            $col.append($panel);
            $row.append($col);
        });

        $c.append($row);

        // Toolbar
        var $hideBtn = hub.hideEnabled
            ? $('<button id="hubToggleHideBtn" class="btn btn-warning btn-sm" style="margin-right:6px;" ' +
                'title="Services menu is collapsed — click to restore all items"></button>')
                .append($('<i class="fa fa-eye-slash" style="margin-right:4px;"></i>'),
                        document.createTextNode('Hub only  \u25CF'))
            : $('<button id="hubToggleHideBtn" class="btn btn-default btn-sm" style="margin-right:6px;" ' +
                'title="Hide all other Services menu items, keeping only Services Hub"></button>')
                .append($('<i class="fa fa-filter" style="margin-right:4px;"></i>'),
                        document.createTextNode('Collapse Services menu'));

        var $editBtn = $('<button id="hubEditBtn" class="btn btn-default btn-sm"></button>')
            .append($('<i class="fa fa-pencil" style="margin-right:4px;"></i>'),
                    document.createTextNode('Customize Categories'));

        $('#hubToolbar').empty().append($hideBtn, $editBtn);
    }

    // ========================================================
    // Customize / Edit view
    // ========================================================
    function renderCustomize() {
        var $c = $('#hubContent').empty();

        // ---- Category order editor ----
        var $catBox = $('<div class="content-box" style="margin-bottom:16px;"></div>');
        var $catMain = $('<div class="content-box-main"></div>').css({padding: '12px 16px'});
        $catMain.append(
            $('<h5 style="margin:0 0 10px;font-weight:600;"></h5>').text('Categories')
        );

        var $catList = $('<div id="hubCatList" style="display:flex;flex-wrap:wrap;gap:6px;align-items:center;"></div>');
        hub.categories.forEach(function (cat) {
            var $chip = $('<span class="label" style="font-size:13px;padding:5px 10px;cursor:default;"></span>')
                .css({'background-color': catColor(cat), color: '#fff'})
                .text(cat);
            var $del = $('<i class="fa fa-times" style="margin-left:6px;cursor:pointer;opacity:0.8;"></i>');
            $del.on('click', function () {
                // Move items in this category to "Other" before removing
                hub.items.forEach(function (item) {
                    if (hub.assignments[item.id] === cat) {
                        hub.assignments[item.id] = 'Other';
                    }
                });
                var idx = hub.categories.indexOf(cat);
                if (idx !== -1) hub.categories.splice(idx, 1);
                renderCustomize();
            });
            $chip.append($del);
            $catList.append($chip);
        });

        // Add-category input
        var $addRow = $('<div style="display:flex;gap:6px;align-items:center;margin-top:8px;"></div>');
        var $newInput = $('<input type="text" class="form-control input-sm" placeholder="New category name…" style="max-width:220px;">');
        var $addBtn = $('<button class="btn btn-default btn-xs"><i class="fa fa-plus"></i> Add</button>');
        $addBtn.on('click', function () {
            var name = $.trim($newInput.val());
            if (name && hub.categories.indexOf(name) === -1) {
                hub.categories.push(name);
                $newInput.val('');
                renderCustomize();
            }
        });
        $addRow.append($newInput, $addBtn);

        $catMain.append($catList, $addRow);
        $catBox.append($catMain);
        $c.append($catBox);

        // ---- Plugin assignment table ----
        var $tableBox = $('<div class="content-box"></div>');
        var $tableMain = $('<div class="content-box-main" style="padding:0;"></div>');

        var $tbl = $('<table class="table table-striped table-condensed" style="margin:0;"></table>');
        $tbl.append(
            $('<thead><tr>' +
              '<th style="width:50%">Plugin</th>' +
              '<th style="width:20%">Menu Section</th>' +
              '<th style="width:30%">Category</th>' +
              '</tr></thead>')
        );

        var $tbody = $('<tbody></tbody>');
        var sorted = hub.items.slice().sort(function (a, b) {
            return a.name.localeCompare(b.name);
        });

        sorted.forEach(function (item) {
            var $tr = $('<tr></tr>');

            // Name cell
            var $tdName = $('<td></td>');
            $tdName.append(
                $('<i></i>').addClass(item.icon || 'fa fa-plug').css({
                    marginRight: '6px', opacity: 0.6, width: '14px', textAlign: 'center'
                }),
                $('<span></span>').text(item.name)
            );

            // Section cell
            var $tdSection = $('<td style="color:#888;font-size:12px;vertical-align:middle;"></td>')
                .text(item.section);

            // Category dropdown cell
            var $tdCat = $('<td style="vertical-align:middle;"></td>');
            var $sel = $('<select class="form-control input-sm hub-assign-select"></select>')
                .attr('data-id', item.id);

            hub.categories.forEach(function (cat) {
                var $opt = $('<option></option>').val(cat).text(cat);
                if (getCategory(item) === cat) {
                    $opt.prop('selected', true);
                }
                $sel.append($opt);
            });

            $tdCat.append($sel);
            $tr.append($tdName, $tdSection, $tdCat);
            $tbody.append($tr);
        });

        $tbl.append($tbody);
        $tableMain.append($tbl);
        $tableBox.append($tableMain);
        $c.append($tableBox);

        // Toolbar
        var $hideBtn2 = hub.hideEnabled
            ? $('<button id="hubToggleHideBtn" class="btn btn-warning btn-sm" style="margin-right:6px;" ' +
                'title="Services menu is collapsed — click to restore all items"></button>')
                .append($('<i class="fa fa-eye-slash" style="margin-right:4px;"></i>'),
                        document.createTextNode('Hub only  \u25CF'))
            : $('<button id="hubToggleHideBtn" class="btn btn-default btn-sm" style="margin-right:6px;" ' +
                'title="Hide all other Services menu items, keeping only Services Hub"></button>')
                .append($('<i class="fa fa-filter" style="margin-right:4px;"></i>'),
                        document.createTextNode('Collapse Services menu'));

        var $saveBtn = $('<button id="hubSaveBtn" class="btn btn-primary btn-sm" style="margin-right:4px;"></button>')
            .append($('<i class="fa fa-floppy-o" style="margin-right:4px;"></i>'), document.createTextNode('Save'));
        var $cancelBtn = $('<button id="hubCancelBtn" class="btn btn-default btn-sm"></button>')
            .text('Cancel');

        $('#hubToolbar').empty().append($hideBtn2, $saveBtn, $cancelBtn);
    }

    // ========================================================
    // Event handlers
    // ========================================================
    $(document).on('click', '#hubEditBtn', function () {
        hub.editMode = true;
        renderCustomize();
    });

    $(document).on('click', '#hubSaveBtn', function () {
        // Collect assignments from dropdowns
        $('.hub-assign-select').each(function () {
            hub.assignments[$(this).attr('data-id')] = $(this).val();
        });

        var $btn = $(this).prop('disabled', true).html(
            '<i class="fa fa-spinner fa-spin"></i> Saving…'
        );

        ajaxCall('/api/servicehub/service/setSettings', {
            assignments: JSON.stringify(hub.assignments),
            categories:  JSON.stringify(hub.categories)
        }, function (resp) {
            $btn.prop('disabled', false);
            if (resp && resp.result === 'saved') {
                hub.editMode = false;
                renderHub();
                // Brief success flash on toolbar
                $('#hubToolbar').prepend(
                    $('<span class="text-success" style="margin-right:10px;font-size:13px;">' +
                      '<i class="fa fa-check"></i> Saved' +
                      '</span>').delay(2500).fadeOut(400, function () { $(this).remove(); })
                );
            }
        });
    });

    $(document).on('click', '#hubCancelBtn', function () {
        hub.editMode = false;
        // Reload settings to discard unsaved category-list edits
        $.ajax('/api/servicehub/service/getSettings', {
            type: 'GET', cache: false,
            success: function (cfg) {
                try { hub.assignments = JSON.parse(cfg.assignments || '{}'); } catch (e) {}
                try {
                    var cats = JSON.parse(cfg.categories || '[]');
                    if (cats.length) hub.categories = cats;
                } catch (e) {}
                renderHub();
            }
        });
    });

    // ---- Hide/show Services menu toggle ----
    $(document).on('click', '#hubToggleHideBtn', function () {
        var enable = !hub.hideEnabled;
        var $btn = $(this).prop('disabled', true);
        $btn.empty().append($('<i class="fa fa-spinner fa-spin"></i>'),
                            document.createTextNode(' Applying\u2026'));

        var url = enable ? '/api/servicehub/service/enableHide'
                        : '/api/servicehub/service/disableHide';

        ajaxCall(url, {}, function (resp) {
            if (resp && resp.result === 'saved') {
                hub.hideEnabled = enable;
                setPersistedHubOnly(enable);
                applyHubOnlyFallback(hub.hideEnabled);
                renderHub();
                // Theme switch requires a full page reload to take effect
                $('#hubContent').prepend(
                    $('<div class="alert alert-info" style="margin-bottom:12px;"></div>')
                        .append(
                            $('<i class="fa fa-refresh" style="margin-right:6px;"></i>'),
                            document.createTextNode(
                                enable
                                ? 'Services menu collapsed. '
                                : 'Services menu restored. '
                            ),
                            $('<a href="#" onclick="window.location.reload();return false;"></a>')
                                .text('Reload page to apply.')
                        )
                );
            } else {
                $btn.prop('disabled', false);
                renderHub();
            }
        });
    });

    // ========================================================
    // Initial data load
    // ========================================================
    $('#hubContent').html(
        '<div style="text-align:center;padding:60px;color:#aaa;">' +
        '<i class="fa fa-spinner fa-spin fa-2x"></i><br><br>Loading plugins…' +
        '</div>'
    );

    // Load settings, hide-status, and menu items in parallel; render when all three complete
    var initData = { settings: null, hideStatus: null, items: null };
    function tryRenderAfterLoad() {
        if (initData.settings === null || initData.hideStatus === null || initData.items === null) {
            return;
        }
        hub.hideEnabled = !!(initData.hideStatus && initData.hideStatus.hideEnabled) || getPersistedHubOnly();
        ensureHubOnlyObserver();
        applyHubOnlyFallback(hub.hideEnabled);
        renderHub();
    }

    $.ajax('/api/servicehub/service/getSettings', {
        type: 'GET', cache: false,
        success: function (cfg) {
            try { hub.assignments = JSON.parse(cfg.assignments || '{}'); } catch (e) { hub.assignments = {}; }
            try {
                var cats = JSON.parse(cfg.categories || '[]');
                if (cats.length) hub.categories = cats;
            } catch (e) {}
            initData.settings = cfg;
            tryRenderAfterLoad();
        },
        error: function () {
            $('#hubContent').html('<div class="alert alert-danger">Failed to load settings from API.</div>');
        }
    });

    $.ajax('/api/servicehub/service/getHideStatus', {
        type: 'GET', cache: false,
        success: function (status) {
            initData.hideStatus = status || {};
            tryRenderAfterLoad();
        },
        error: function () {
            initData.hideStatus = {};
            tryRenderAfterLoad();
        }
    });

    $.ajax('/api/servicehub/service/getMenuItems', {
        type: 'GET', cache: false,
        success: function (resp) {
            hub.items = resp.items || [];
            initData.items = hub.items;
            tryRenderAfterLoad();
        },
        error: function () {
            $('#hubContent').html('<div class="alert alert-danger">Failed to load plugin list from API.</div>');
        }
    });

    // ---- Diagnostic: show real sidebar HTML to calibrate CSS selectors ----
    $(document).on('click', '#hubDiagBtn', function () {
        var html = document.getElementById('navigation')
            ? document.getElementById('navigation').innerHTML
            : '(#navigation not found in DOM)';
        // Summarise: find all <a> tags with href
        var $nav = $('#navigation');
        var lines = [];
        $nav.find('a[href]').each(function () {
            var el = this;
            var ids = [];
            $(el).parents('[id]').each(function () { ids.unshift('#' + this.id); });
            lines.push(ids.join(' > ') + ' >> ' + el.href);
        });
        var summary = lines.length
            ? lines.join('\n')
            : html.substring(0, 4000);

        var $modal = $('<div class="modal fade" tabindex="-1"></div>');
        var $dialog = $('<div class="modal-dialog modal-lg"></div>');
        var $content = $('<div class="modal-content"></div>');
        $content.append(
            '<div class="modal-header"><button type="button" class="close" data-dismiss="modal">&times;</button>' +
            '<h4 class="modal-title">Sidebar structure (copy and share for CSS calibration)</h4></div>',
            $('<div class="modal-body"></div>').append(
                $('<textarea class="form-control" rows="20" style="font-family:monospace;font-size:11px;"></textarea>')
                    .val(summary)
            ),
            '<div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Close</button></div>'
        );
        $dialog.append($content);
        $modal.append($dialog);
        $('body').append($modal);
        $modal.modal('show').on('hidden.bs.modal', function () { $modal.remove(); });
    });
});
</script>

<div class="content-box">
    <div class="content-box-main" style="padding: 16px;">

        <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:18px;">
            <h4 style="margin:0; font-weight:600;">
                <i class="fa fa-th" style="margin-right:8px; opacity:0.8;"></i>
                Services Hub
                <small style="font-size:12px; color:#aaa; margin-left:8px; font-weight:400;">
                    All installed plugins, organised by category
                </small>
            </h4>
            <div id="hubToolbar"></div>
        </div>

        <div id="hubContent"></div>

        <div style="margin-top:16px; text-align:right;">
            <button id="hubDiagBtn" class="btn btn-link btn-xs" style="color:#bbb; font-size:11px;">
                <i class="fa fa-stethoscope"></i> Diagnose sidebar structure
            </button>
        </div>

    </div>
</div>
