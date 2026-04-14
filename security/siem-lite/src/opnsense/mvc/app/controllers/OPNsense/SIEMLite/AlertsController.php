<?php

namespace OPNsense\SIEMLite;

class AlertsController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/alerts');
    }
}
