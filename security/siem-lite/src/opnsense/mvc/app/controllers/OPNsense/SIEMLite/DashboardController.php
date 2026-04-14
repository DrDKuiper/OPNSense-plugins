<?php

namespace OPNsense\SIEMLite;

class DashboardController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/dashboard');
    }
}
