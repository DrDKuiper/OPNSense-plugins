{#
 # Copyright (C) 2024 Kuiper
 # All rights reserved.
 #}

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab-general">{{ lang._('General') }}</a></li>
    <li><a data-toggle="tab" href="#tab-notifications">{{ lang._('Notifications') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <!-- General Settings -->
    <div id="tab-general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct_general" type="button">
                    <b>{{ lang._('Save') }}</b> <i id="saveAct_general_progress"></i>
                </button>
            </div>
        </div>
    </div>

    <!-- Notification Settings -->
    <div id="tab-notifications" class="tab-pane fade in">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':alertForm,'id':'frm_alert_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct_alert" type="button">
                    <b>{{ lang._('Save') }}</b> <i id="saveAct_alert_progress"></i>
                </button>
                <button class="btn btn-default" id="testNotification" type="button">
                    <i class="fa fa-paper-plane"></i> {{ lang._('Send Test') }}
                </button>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    // Load settings
    var data_get_map = {
        'frm_general_settings': "/api/siemlite/general/get",
        'frm_alert_settings': "/api/siemlite/alertsettings/get"
    };
    mapDataToFormUI(data_get_map).done(function(data) {
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    updateServiceControlUI('siemlite');

    // Save general settings
    $("#saveAct_general").click(function() {
        saveFormToEndpoint("/api/siemlite/general/set", 'frm_general_settings', function() {
            $("#saveAct_general_progress").addClass("fa fa-spinner fa-pulse");
            ajaxCall("/api/siemlite/service/reconfigure", {}, function(data, status) {
                updateServiceControlUI('siemlite');
                $("#saveAct_general_progress").removeClass("fa fa-spinner fa-pulse");
            });
        });
    });

    // Save alert settings
    $("#saveAct_alert").click(function() {
        saveFormToEndpoint("/api/siemlite/alertsettings/set", 'frm_alert_settings', function() {
            $("#saveAct_alert_progress").addClass("fa fa-spinner fa-pulse");
            ajaxCall("/api/siemlite/service/reconfigure", {}, function(data, status) {
                $("#saveAct_alert_progress").removeClass("fa fa-spinner fa-pulse");
            });
        });
    });

    // Test notification
    $("#testNotification").click(function() {
        var $btn = $(this);
        $btn.prop('disabled', true);
        ajaxCall("/api/siemlite/service/reconfigure", {testNotification: '1'}, function(data) {
            $btn.prop('disabled', false);
            if (data && data.status === 'ok') {
                alert('Test notification sent successfully.');
            } else {
                alert('Failed to send test notification. Check your settings.');
            }
        });
    });
});
</script>
