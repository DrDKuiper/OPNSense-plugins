<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\SIEMLite\General;
use OPNsense\Core\Config;

class GeneralController extends ApiControllerBase
{
    public function getAction()
    {
        $result = array();
        if ($this->request->isGet()) {
            $mdl = new General();
            $result['general'] = $mdl->getNodes();
        }
        return $result;
    }

    public function setAction()
    {
        $result = array("result" => "failed");
        if ($this->request->isPost()) {
            $mdl = new General();
            $mdl->setNodes($this->request->getPost("general"));

            $valMsgs = $mdl->performValidation();
            foreach ($valMsgs as $field => $msg) {
                if (!array_key_exists("validations", $result)) {
                    $result["validations"] = array();
                }
                $result["validations"]["general." . $msg->getField()] = $msg->getMessage();
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
