<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class TrafficController extends ApiControllerBase
{
    public function flowsAction()
    {
        $backend = new Backend();
        $itemsPerPage = intval($this->request->getPost('rowCount', 'int', 20));
        $currentPage = intval($this->request->getPost('current', 'int', 1));
        $offset = ($currentPage - 1) * $itemsPerPage;
        $searchPhrase = $this->request->getPost('searchPhrase', 'string', '');
        $timeRange = $this->request->getPost('timeRange', 'string', '24h');
        $protocol = $this->request->getPost('protocol', 'string', '');

        $params = base64_encode(json_encode(array(
            'offset' => $offset,
            'limit' => $itemsPerPage,
            'search' => $searchPhrase,
            'time_range' => $timeRange,
            'protocol' => $protocol
        )));

        $response = $backend->configdpRun("siemlite traffic-flows", array($params));
        $data = json_decode($response, true);

        if (!is_array($data)) {
            $data = array('rows' => array(), 'total' => 0);
        }

        return array(
            'rows' => isset($data['rows']) ? $data['rows'] : array(),
            'rowCount' => $itemsPerPage,
            'current' => $currentPage,
            'total' => isset($data['total']) ? $data['total'] : 0
        );
    }

    public function statsAction()
    {
        $backend = new Backend();
        $timeRange = $this->request->get('timeRange', 'string', '24h');
        $response = $backend->configdpRun("siemlite traffic-stats", array($timeRange));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array();
    }

    public function topportsAction()
    {
        $backend = new Backend();
        $timeRange = $this->request->get('timeRange', 'string', '24h');
        $response = $backend->configdpRun("siemlite traffic-ports", array($timeRange));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array();
    }
}
