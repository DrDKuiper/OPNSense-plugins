<?php

namespace OPNsense\SIEMLite\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

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

    public function loadBuiltinAction()
    {
        $result = array("result" => "failed", "count" => 0);
        if ($this->request->isPost()) {
            $builtinPath = '/usr/local/opnsense/scripts/OPNsense/SIEMLite/builtin_rules.json';
            if (!file_exists($builtinPath)) {
                $result["message"] = "Built-in rules file not found";
                return $result;
            }

            $jsonData = file_get_contents($builtinPath);
            $builtinRules = json_decode($jsonData, true);
            if (!is_array($builtinRules)) {
                $result["message"] = "Invalid built-in rules format";
                return $result;
            }

            $mdl = $this->getModel();
            $added = 0;

            // Get existing rule titles to avoid duplicates
            $existingTitles = array();
            foreach ($mdl->rules->rule->iterateItems() as $uuid => $rule) {
                $existingTitles[] = (string)$rule->title;
            }

            foreach ($builtinRules as $ruleData) {
                $title = $ruleData['title'] ?? '';
                if (empty($title) || in_array($title, $existingTitles)) {
                    continue;
                }

                $node = $mdl->rules->rule->Add();
                $node->enabled = $ruleData['enabled'] ?? '1';
                $node->title = $title;
                $node->description = $ruleData['description'] ?? '';
                $node->severity = $ruleData['severity'] ?? 'medium';
                $node->logsource = $ruleData['logsource'] ?? 'any';
                $node->detection_pattern = $ruleData['detection_pattern'] ?? '';
                $node->condition = $ruleData['condition'] ?? 'contains';
                $node->threshold = (string)($ruleData['threshold'] ?? 1);
                $node->timewindow = (string)($ruleData['timewindow'] ?? 300);
                $node->mitre_tactic = $ruleData['mitre_tactic'] ?? '';
                $node->mitre_technique = $ruleData['mitre_technique'] ?? '';
                $node->tags = $ruleData['tags'] ?? '';
                $node->builtin = '1';
                $added++;
            }

            if ($added > 0) {
                $mdl->serializeToConfig();
                Config::getInstance()->save();
            }

            $result["result"] = "saved";
            $result["count"] = $added;
        }
        return $result;
    }
}
