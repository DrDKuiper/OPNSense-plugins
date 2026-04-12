<script>
$(document).ready(function () {
    function escapeHtml(text) {
        return $('<div/>').text(text || '').html();
    }

    function reloadForm() {
        return mapDataToFormUI({'frm_realtekre': '/api/realtekre/settings/get'});
    }

    function refreshOverview() {
        ajaxCall('/api/realtekre/service/overview', {}, function (data, status) {
            if (status !== 'success' || data['status'] !== 'ok') {
                $('#driverOverview').html('<div class="text-danger">{{ lang._('Unable to load driver overview.') }}</div>');
                return;
            }

            var overview = data['overview'] || {};
            var interfaces = (overview['interfaces'] || []).length ? overview['interfaces'].join(', ') : '{{ lang._('none detected') }}';
            var loaderConfig = overview['loader_config'] || '{{ lang._('No generated loader configuration found yet.') }}';
            var moduleLoaded = overview['module_loaded'] === 'yes' ? '{{ lang._('yes') }}' : '{{ lang._('no') }}';

            $('#driverOverview').html(
                '<table class="table table-striped __nomb">' +
                '<tr><td>{{ lang._('Driver package version') }}</td><td>' + escapeHtml(overview['package_version']) + '</td></tr>' +
                '<tr><td>{{ lang._('Module currently loaded') }}</td><td>' + escapeHtml(moduleLoaded) + '</td></tr>' +
                '<tr><td>{{ lang._('Module file') }}</td><td>' + escapeHtml(overview['module_file']) + '</td></tr>' +
                '<tr><td>{{ lang._('Detected re interfaces') }}</td><td>' + escapeHtml(interfaces) + '</td></tr>' +
                '</table>' +
                '<pre style="margin-bottom:0">' + escapeHtml(loaderConfig) + '</pre>'
            );
        });
    }

    function applyProfile(profileName) {
        ajaxCall('/api/realtekre/settings/applyProfile/' + profileName, {}, function (data, status) {
            if (status !== 'success' || data['result'] !== 'saved') {
                $('#responseMsg').removeClass('hidden alert-info').addClass('alert-danger').html(data['message'] || '{{ lang._('Unable to apply profile.') }}');
                return;
            }

            ajaxCall('/api/realtekre/service/reconfigure', {}, function (reconfigureData, reconfigureStatus) {
                var message = data['message'] || '{{ lang._('Profile applied.') }}';
                if (reconfigureStatus === 'success' && reconfigureData['message']) {
                    message += ' ' + reconfigureData['message'];
                }
                $('#responseMsg').removeClass('hidden alert-danger').addClass('alert-info').html(message);
                reloadForm();
                refreshOverview();
            });
        });
    }

    reloadForm();
    refreshOverview();

    $('#saveAct').click(function () {
        saveFormToEndpoint('/api/realtekre/settings/set', 'frm_realtekre', function () {
            ajaxCall('/api/realtekre/service/reconfigure', {}, function (data, status) {
                var message = '{{ lang._('Settings saved. A reboot is required for loader changes to take effect.') }}';

                if (status === 'success' && data['status'] === 'ok' && data['message']) {
                    message = data['message'];
                }

                $('#responseMsg').removeClass('hidden alert-danger').addClass('alert-info').html(message);
                refreshOverview();
            });
        });
    });

    $('.profile-apply').click(function () {
        applyProfile($(this).data('profile'));
    });
});
</script>

<div class="row">
    <div class="col-md-12">
        <div class="content-box tab-content table-responsive">
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr>
                    <th class="listtopic">{{ lang._('Driver Overview') }}</th>
                </tr>
                <tr>
                    <td id="driverOverview">{{ lang._('Loading driver overview...') }}</td>
                </tr>
            </table>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-md-12">
        <div class="content-box tab-content table-responsive">
            <table class="table table-striped __nomb" style="margin-bottom:0">
                <tr>
                    <th class="listtopic">{{ lang._('Tuning Profiles') }}</th>
                </tr>
                <tr>
                    <td>
                        <div><strong>{{ lang._('Baseline') }}</strong>: {{ lang._('Loads the vendor driver and reduces RX buffer size to 2048 for safer operation without jumbo frames.') }}</div>
                        <button class="btn btn-default profile-apply" data-profile="baseline" type="button">{{ lang._('Apply Baseline') }}</button>
                    </td>
                </tr>
                <tr>
                    <td>
                        <div><strong>{{ lang._('Throughput') }}</strong>: {{ lang._('Enables interrupt filtering and keeps MSI and MSI-X enabled for lower CPU overhead on healthy hardware.') }}</div>
                        <button class="btn btn-default profile-apply" data-profile="throughput" type="button">{{ lang._('Apply Throughput') }}</button>
                    </td>
                </tr>
                <tr>
                    <td>
                        <div><strong>{{ lang._('Compatibility') }}</strong>: {{ lang._('Disables MSI and MSI-X and lowers RX mbuf size for systems that hang or drop link under load.') }}</div>
                        <button class="btn btn-default profile-apply" data-profile="compatibility" type="button">{{ lang._('Apply Compatibility') }}</button>
                    </td>
                </tr>
                <tr>
                    <td>
                        <div><strong>{{ lang._('Wake-on-LAN') }}</strong>: {{ lang._('Enables the Wake-on-LAN tunables documented by the realtek-re-kmod package.') }}</div>
                        <button class="btn btn-default profile-apply" data-profile="wol" type="button">{{ lang._('Apply Wake-on-LAN') }}</button>
                    </td>
                </tr>
            </table>
        </div>
    </div>
</div>

<div class="alert alert-info" role="alert">
    {{ lang._('These settings generate loader tunables for the Realtek vendor driver. Any change requires a reboot before it affects the interface.') }}
</div>

<div class="alert alert-info" role="alert">
    {{ lang._('If stalls continue, especially with IPv6 traffic, also test disabling RX and TX checksum offloading on the affected interface in OPNsense.') }}
</div>

<div class="alert alert-info hidden" role="alert" id="responseMsg"></div>

<div class="col-md-12">
    {{ partial("layout_partials/base_form",['fields':settings,'id':'frm_realtekre'])}}
</div>

<div class="col-md-12">
    <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b></button>
</div>