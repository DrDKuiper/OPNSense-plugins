<?php

namespace OPNsense\SIEMLite;

class TopologyController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/topology');
    }
}
