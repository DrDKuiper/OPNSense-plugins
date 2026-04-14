<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class PacketinspectorController extends ApiControllerBase
{
    public function connectionsAction()
    {
        $backend = new Backend();
        $params = json_encode(array(
            'limit' => intval($this->request->getPost('rowCount', 'int', 100)),
            'filter' => $this->request->getPost('searchPhrase', 'string', ''),
            'protocol' => $this->request->getPost('protocol', 'string', ''),
            'state' => $this->request->getPost('state', 'string', '')
        ));
        $response = $backend->configdpRun("siemlite active-connections", array(escapeshellarg($params)));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('rows' => array(), 'total' => 0);
    }

    public function captureAction()
    {
        if (!$this->request->isPost()) {
            return array('status' => 'error', 'message' => 'POST required');
        }
        $backend = new Backend();
        $interface = preg_replace('/[^a-zA-Z0-9_]/', '', $this->request->getPost('interface', 'string', 'em0'));
        $count = min(intval($this->request->getPost('count', 'int', 25)), 100);
        $filter = $this->request->getPost('filter', 'string', '');
        // Sanitize BPF filter — only allow safe characters
        $filter = preg_replace('/[^a-zA-Z0-9\s\.\:\-\/\>\<\=\!\(\)\&\|]/', '', $filter);

        $params = json_encode(array(
            'interface' => $interface,
            'count' => $count,
            'filter' => $filter
        ));
        $response = $backend->configdpRun("siemlite capture-packets", array(escapeshellarg($params)));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('packets' => array(), 'total' => 0);
    }

    public function interfacesAction()
    {
        $backend = new Backend();
        $response = $backend->configdpRun("siemlite list-interfaces");
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('interfaces' => array());
    }

    public function dnsqueryAction()
    {
        $backend = new Backend();
        $limit = intval($this->request->get('limit', 'int', 50));
        $response = $backend->configdpRun("siemlite dns-queries", array(escapeshellarg(strval($limit))));
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('queries' => array());
    }

    public function arptableAction()
    {
        $backend = new Backend();
        $response = $backend->configdpRun("siemlite arp-table");
        $data = json_decode($response, true);
        return is_array($data) ? $data : array('entries' => array());
    }
}
