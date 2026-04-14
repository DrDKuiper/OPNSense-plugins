<?php

namespace OPNsense\SIEMLite;

class EventsController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/events');
    }
}
