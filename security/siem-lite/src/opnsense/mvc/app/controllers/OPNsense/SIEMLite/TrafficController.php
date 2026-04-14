<?php

namespace OPNsense\SIEMLite;

class TrafficController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/traffic');
    }
}
