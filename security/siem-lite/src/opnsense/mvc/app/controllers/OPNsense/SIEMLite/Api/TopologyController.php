<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class TopologyController extends ApiControllerBase
{
    public function getdataAction()
    {
        $backend = new Backend();
        $timeRange = $this->request->get('timeRange', 'string', '24h');
        $minCount = intval($this->request->get('minCount', 'int', 2));
        $response = $backend->configdpRun("siemlite topology-data", array(
            escapeshellarg($timeRange),
            escapeshellarg(strval($minCount))
        ));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('nodes' => array(), 'edges' => array());
    }

    public function nodedetailAction($ip)
    {
        $backend = new Backend();
        $response = $backend->configdpRun("siemlite node-detail", array(escapeshellarg($ip)));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array();
    }
}
