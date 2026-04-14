<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class DashboardController extends ApiControllerBase
{
    /**
     * Get dashboard statistics and metrics
     */
    public function getStatsAction()
    {
        $backend = new Backend();
        $timeRange = $this->request->get('timeRange', 'string', '24h');
        $response = $backend->configdpRun("siemlite dashboard-stats", array($timeRange));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array(
            'total_events' => 0,
            'total_alerts' => 0,
            'critical_alerts' => 0,
            'high_alerts' => 0,
            'medium_alerts' => 0,
            'low_alerts' => 0,
            'risk_score' => 0,
            'top_sources' => array(),
            'top_destinations' => array(),
            'top_rules' => array(),
            'events_timeline' => array(),
            'alerts_by_severity' => array(),
            'geo_data' => array(),
            'source_distribution' => array()
        );
    }

    /**
     * Get risk score history
     */
    public function getRiskHistoryAction()
    {
        $backend = new Backend();
        $response = $backend->configdRun("siemlite risk-history");
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('history' => array());
    }
}
