<?php

namespace OPNsense\SIEMLite;

class SigmarulesController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->formDialogEditSigmaRule = $this->getForm('dialogEditSigmaRule');
        $this->view->pick('OPNsense/SIEMLite/sigmarules');
    }
}
