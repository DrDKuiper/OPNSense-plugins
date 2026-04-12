<?php

namespace OPNsense\RealtekRe\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'realtekre';
    protected static $internalModelClass = 'OPNsense\RealtekRe\RealtekRe';

    public function applyProfileAction($profileName = null)
    {
        $result = array("result" => "failed");
        $profiles = $this->getProfiles();

        if (empty($profileName) || !array_key_exists($profileName, $profiles)) {
            $result['message'] = 'Unknown profile';
            return $result;
        }

        $model = $this->getModel();
        $model->setNodes($profiles[$profileName]);

        $validationMessages = $model->performValidation();
        foreach ($validationMessages as $msg) {
            if (!array_key_exists('validations', $result)) {
                $result['validations'] = array();
            }
            $result['validations']['general.' . $msg->getField()] = $msg->getMessage();
        }

        if ($validationMessages->count() == 0) {
            $model->serializeToConfig();
            Config::getInstance()->save();
            $result['result'] = 'saved';
            $result['message'] = sprintf('Profile "%s" applied.', $profileName);
        }

        return $result;
    }

    private function getProfiles()
    {
        return array(
            'baseline' => array(
                'general' => array(
                    'Enabled' => '1',
                    'IntrFilter' => '0',
                    'MsiDisable' => '0',
                    'MsixDisable' => '0',
                    'PreferIomap' => '0',
                    'MaxRxMbufSize' => '2048',
                    'InterfaceUnit' => '',
                    'IntRxMod' => '',
                    'S5Wol' => '0',
                    'S0MagicPacket' => '0'
                )
            ),
            'throughput' => array(
                'general' => array(
                    'Enabled' => '1',
                    'IntrFilter' => '1',
                    'MsiDisable' => '0',
                    'MsixDisable' => '0',
                    'PreferIomap' => '0',
                    'MaxRxMbufSize' => '',
                    'InterfaceUnit' => '',
                    'IntRxMod' => '',
                    'S5Wol' => '0',
                    'S0MagicPacket' => '0'
                )
            ),
            'compatibility' => array(
                'general' => array(
                    'Enabled' => '1',
                    'IntrFilter' => '0',
                    'MsiDisable' => '1',
                    'MsixDisable' => '1',
                    'PreferIomap' => '0',
                    'MaxRxMbufSize' => '2048',
                    'InterfaceUnit' => '',
                    'IntRxMod' => '',
                    'S5Wol' => '0',
                    'S0MagicPacket' => '0'
                )
            ),
            'wol' => array(
                'general' => array(
                    'Enabled' => '1',
                    'IntrFilter' => '0',
                    'MsiDisable' => '0',
                    'MsixDisable' => '0',
                    'PreferIomap' => '0',
                    'MaxRxMbufSize' => '',
                    'InterfaceUnit' => '',
                    'IntRxMod' => '',
                    'S5Wol' => '1',
                    'S0MagicPacket' => '1'
                )
            )
        );
    }
}