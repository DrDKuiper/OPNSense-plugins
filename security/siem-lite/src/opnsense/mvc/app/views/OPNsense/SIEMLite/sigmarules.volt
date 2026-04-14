{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<h2 style="font-weight:300; margin-bottom:15px;">
    <i class="fa fa-code"></i> {{ lang._('Sigma Detection Rules') }}
</h2>

<table id="grid-sigmarules" class="table table-responsive" data-editDialog="dialogEditSigmaRule">
    <thead>
        <tr>
            <th data-column-id="enabled" data-type="string" data-formatter="rowtoggle" data-width="80px">{{ lang._('Enabled') }}</th>
            <th data-column-id="title" data-type="string">{{ lang._('Title') }}</th>
            <th data-column-id="severity" data-type="string" data-formatter="severity" data-width="90px">{{ lang._('Severity') }}</th>
            <th data-column-id="logsource" data-type="string" data-width="130px">{{ lang._('Log Source') }}</th>
            <th data-column-id="condition" data-type="string" data-width="120px">{{ lang._('Condition') }}</th>
            <th data-column-id="mitre_tactic" data-type="string" data-width="100px">{{ lang._('MITRE Tactic') }}</th>
            <th data-column-id="tags" data-type="string" data-width="150px">{{ lang._('Tags') }}</th>
            <th data-column-id="builtin" data-type="string" data-formatter="builtin" data-width="70px">{{ lang._('Built-in') }}</th>
            <th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
            <th data-column-id="commands" data-formatter="commands" data-sortable="false" data-width="100px">{{ lang._('Commands') }}</th>
        </tr>
    </thead>
    <tbody></tbody>
    <tfoot>
        <tr>
            <td colspan="9"></td>
            <td>
                <button data-action="add" type="button" class="btn btn-xs btn-default"><span class="fa fa-plus"></span></button>
            </td>
        </tr>
    </tfoot>
</table>

<div class="col-md-12">
    <hr />
    <button class="btn btn-primary" id="saveAct_rules" type="button">
        <b>{{ lang._('Apply') }}</b> <i id="saveAct_rules_progress"></i>
    </button>
    <button class="btn btn-default" id="loadBuiltinRules" type="button">
        <i class="fa fa-download"></i> {{ lang._('Load Built-in Rules') }}
    </button>
    <br /><br />
</div>

{{ partial("layout_partials/base_dialog",['fields':formDialogEditSigmaRule,'id':'dialogEditSigmaRule','label':lang._('Edit Sigma Rule')])}}

<script>
$(document).ready(function() {
    $("#grid-sigmarules").UIBootgrid({
        search: '/api/siemlite/sigmarule/searchRule',
        get: '/api/siemlite/sigmarule/getRule/',
        set: '/api/siemlite/sigmarule/setRule/',
        add: '/api/siemlite/sigmarule/addRule/',
        del: '/api/siemlite/sigmarule/delRule/',
        toggle: '/api/siemlite/sigmarule/toggleRule/',
        options: {
            formatters: {
                severity: function(column, row) {
                    var colors = {critical:'#d9534f',high:'#f0ad4e',medium:'#5bc0de',low:'#5cb85c'};
                    var c = colors[row.severity] || '#999';
                    return '<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.8em;font-weight:600;color:#fff;background:' + c + '">' + (row.severity || '') + '</span>';
                },
                builtin: function(column, row) {
                    if (row.builtin === '1') {
                        return '<i class="fa fa-check text-success" title="Built-in rule"></i>';
                    }
                    return '<i class="fa fa-user text-muted" title="Custom rule"></i>';
                }
            }
        }
    });

    $("#saveAct_rules").click(function() {
        $("#saveAct_rules_progress").addClass("fa fa-spinner fa-pulse");
        ajaxCall("/api/siemlite/service/reconfigure", {}, function(data, status) {
            $("#saveAct_rules_progress").removeClass("fa fa-spinner fa-pulse");
        });
    });

    $("#loadBuiltinRules").click(function() {
        if (!confirm('This will add/reset built-in Sigma rules. Custom rules will not be affected. Continue?')) {
            return;
        }
        var $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fa fa-spinner fa-pulse"></i> Loading...');
        ajaxCall("/api/siemlite/sigmarule/loadBuiltin", {}, function(data) {
            $btn.prop('disabled', false).html('<i class="fa fa-download"></i> Load Built-in Rules');
            if (data && data.result === 'saved') {
                alert(data.count + ' built-in rules loaded successfully.');
            } else {
                alert('Failed to load rules: ' + (data.message || 'unknown error'));
            }
            $("#grid-sigmarules").bootgrid('reload');
        });
    });
});
</script>
