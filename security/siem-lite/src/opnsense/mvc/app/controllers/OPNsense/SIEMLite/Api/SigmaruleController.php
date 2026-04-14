<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class SigmaruleController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'sigmarule';
    protected static $internalModelClass = '\OPNsense\SIEMLite\SigmaRule';

    public function searchRuleAction()
    {
        return $this->searchBase(
            'rules.rule',
            array("enabled", "title", "severity", "logsource", "condition", "mitre_tactic", "tags", "builtin")
        );
    }

    public function getRuleAction($uuid = null)
    {
        return $this->getBase('rule', 'rules.rule', $uuid);
    }

    public function addRuleAction()
    {
        return $this->addBase('rule', 'rules.rule');
    }

    public function delRuleAction($uuid)
    {
        return $this->delBase('rules.rule', $uuid);
    }

    public function setRuleAction($uuid)
    {
        return $this->setBase('rule', 'rules.rule', $uuid);
    }

    public function toggleRuleAction($uuid)
    {
        return $this->toggleBase('rules.rule', $uuid);
    }
}
