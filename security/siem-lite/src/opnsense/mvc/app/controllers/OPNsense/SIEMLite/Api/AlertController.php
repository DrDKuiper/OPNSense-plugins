<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class AlertController extends ApiControllerBase
{
    /**
     * Search triggered alerts
     */
    public function searchAction()
    {
        $backend = new Backend();
        $itemsPerPage = intval($this->request->getPost('rowCount', 'int', 20));
        $currentPage = intval($this->request->getPost('current', 'int', 1));
        $offset = ($currentPage - 1) * $itemsPerPage;

        $searchPhrase = $this->request->getPost('searchPhrase', 'string', '');
        $severity = $this->request->getPost('severity', 'string', '');
        $status = $this->request->getPost('status', 'string', '');
        $timeRange = $this->request->getPost('timeRange', 'string', '24h');

        $params = base64_encode(json_encode(array(
            'offset' => $offset,
            'limit' => $itemsPerPage,
            'search' => $searchPhrase,
            'severity' => $severity,
            'status' => $status,
            'time_range' => $timeRange
        )));

        $response = $backend->configdpRun("siemlite query-alerts", array($params));
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

    /**
     * Acknowledge an alert
     */
    public function ackAction($alertId)
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $response = $backend->configdpRun("siemlite ack-alert", array($alertId));
            return json_decode($response, true) ?: array('status' => 'error');
        }
        return array('status' => 'failed');
    }

    /**
     * Close an alert
     */
    public function closeAction($alertId)
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $response = $backend->configdpRun("siemlite close-alert", array($alertId));
            return json_decode($response, true) ?: array('status' => 'error');
        }
        return array('status' => 'failed');
    }
}
