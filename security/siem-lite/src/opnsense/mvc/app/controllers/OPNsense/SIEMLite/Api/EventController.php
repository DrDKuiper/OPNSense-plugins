<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class EventController extends ApiControllerBase
{
    /**
     * Search events from the SIEM database
     */
    public function searchAction()
    {
        $backend = new Backend();
        $itemsPerPage = intval($this->request->getPost('rowCount', 'int', 20));
        $currentPage = intval($this->request->getPost('current', 'int', 1));
        $offset = ($currentPage - 1) * $itemsPerPage;

        $searchPhrase = $this->request->getPost('searchPhrase', 'string', '');
        $severity = $this->request->getPost('severity', 'string', '');
        $source = $this->request->getPost('source', 'string', '');
        $timeRange = $this->request->getPost('timeRange', 'string', '24h');

        $params = base64_encode(json_encode(array(
            'offset' => $offset,
            'limit' => $itemsPerPage,
            'search' => $searchPhrase,
            'severity' => $severity,
            'source' => $source,
            'time_range' => $timeRange
        )));

        $response = $backend->configdpRun("siemlite query-events", array($params));
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
     * Get event details by ID
     */
    public function getAction($eventId)
    {
        $backend = new Backend();
        $response = $backend->configdpRun("siemlite get-event", array($eventId));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array();
    }
}
