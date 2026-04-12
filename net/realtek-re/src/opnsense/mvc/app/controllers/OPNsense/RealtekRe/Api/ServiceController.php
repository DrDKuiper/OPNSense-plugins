<?php

namespace OPNsense\RealtekRe\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = 'OPNsense\RealtekRe\RealtekRe';
    protected static $internalServiceTemplate = 'OPNsense/RealtekRe';
    protected static $internalServiceEnabled = 'general.Enabled';
    protected static $internalServiceName = 'realtekre';

    public function overviewAction()
    {
        $backend = new Backend();

        $interfaces = preg_split('/\s+/', trim($backend->configdRun('realtekre interfaces')));
        $interfaces = array_values(array_filter($interfaces, function ($item) {
            return !empty($item);
        }));

        return array(
            'status' => 'ok',
            'overview' => array(
                'package_version' => trim($backend->configdRun('realtekre package-version')),
                'module_loaded' => trim($backend->configdRun('realtekre module-loaded')),
                'module_file' => trim($backend->configdRun('realtekre module-file')),
                'interfaces' => $interfaces,
                'loader_config' => trim($backend->configdRun('realtekre loader-config')),
            )
        );
    }
}