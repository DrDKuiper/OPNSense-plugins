<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\SIEMLite\General;

class ServiceController extends ApiControllerBase
{
    public function startAction()
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $response = $backend->configdRun("siemlite start");
            return array("response" => $response);
        }
        return array("response" => array());
    }

    public function stopAction()
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $response = $backend->configdRun("siemlite stop");
            return array("response" => $response);
        }
        return array("response" => array());
    }

    public function restartAction()
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $response = $backend->configdRun("siemlite restart");
            return array("response" => $response);
        }
        return array("response" => array());
    }

    public function statusAction()
    {
        $backend = new Backend();
        $mdl = new General();
        $response = $backend->configdRun("siemlite status");

        if (strpos($response, "not running") !== false) {
            if ($mdl->enabled->__toString() == 1) {
                $status = "stopped";
            } else {
                $status = "disabled";
            }
        } elseif (strpos($response, "is running") !== false) {
            $status = "running";
        } elseif ($mdl->enabled->__toString() == 0) {
            $status = "disabled";
        } else {
            $status = "unknown";
        }

        return array("status" => $status);
    }

    public function reconfigureAction()
    {
        if ($this->request->isPost()) {
            $mdl = new General();
            $backend = new Backend();

            $this->stopAction();
            $backend->configdRun('template reload OPNsense/SIEMLite');

            if ($mdl->enabled->__toString() == 1) {
                $backend->configdRun("siemlite reconfigure");
                $this->startAction();
            }

            return array("status" => "ok");
        }
        return array("status" => "failed");
    }
}
