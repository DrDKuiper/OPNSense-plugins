<?php

namespace OPNsense\SIEMLite;

class PacketinspectorController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->pick('OPNsense/SIEMLite/packetinspector');
    }
}
