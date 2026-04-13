<?php

namespace OPNsense\ServiceHub;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/ServiceHub/index');
    }
}
