<?php

namespace OPNsense\SIEMLite;

class SettingsController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->generalForm = $this->getForm('general');
        $this->view->alertForm = $this->getForm('alert');
        $this->view->pick('OPNsense/SIEMLite/settings');
    }
}
