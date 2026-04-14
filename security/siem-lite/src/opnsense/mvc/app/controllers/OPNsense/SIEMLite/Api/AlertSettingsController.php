<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\SIEMLite\Alert;
use OPNsense\Core\Config;

class AlertSettingsController extends ApiControllerBase
{
    public function getAction()
    {
        $result = array();
        if ($this->request->isGet()) {
            $mdl = new Alert();
            $result['alert'] = $mdl->getNodes();
        }
        return $result;
    }

    public function setAction()
    {
        $result = array("result" => "failed");
        if ($this->request->isPost()) {
            $mdl = new Alert();
            $mdl->setNodes($this->request->getPost("alert"));

            $valMsgs = $mdl->performValidation();
            foreach ($valMsgs as $field => $msg) {
                if (!array_key_exists("validations", $result)) {
                    $result["validations"] = array();
                }
                $result["validations"]["alert." . $msg->getField()] = $msg->getMessage();
            }

            if ($valMsgs->count() == 0) {
                $mdl->serializeToConfig();
                Config::getInstance()->save();
                $result["result"] = "saved";
            }
        }
        return $result;
    }
}
