<?php

namespace OPNsense\ServiceHub\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\ServiceHub\ServiceHub;

class ServiceController extends ApiControllerBase
{
    /**
     * Scan all installed Menu.xml files and return a list of plugin entries.
     * Each entry contains: id, name, section, url, icon, vendor, plugin.
     */
    public function getMenuItemsAction()
    {
        $plugins = [];
        $seen    = [];

        $menuFiles = glob('/usr/local/opnsense/mvc/app/models/*/*/Menu/Menu.xml');
        if (!$menuFiles) {
            $menuFiles = [];
        }

        foreach ($menuFiles as $file) {
            try {
                $xml = @simplexml_load_file($file);
                if ($xml === false) {
                    continue;
                }

                // Derive vendor + module from path: .../models/Vendor/Module/Menu/Menu.xml
                $parts     = explode('/', str_replace('\\', '/', $file));
                $modelsIdx = array_search('models', $parts);
                $vendor    = ($modelsIdx !== false && isset($parts[$modelsIdx + 1]))
                    ? $parts[$modelsIdx + 1]
                    : 'Unknown';
                $module    = ($modelsIdx !== false && isset($parts[$modelsIdx + 2]))
                    ? $parts[$modelsIdx + 2]
                    : 'Unknown';

                foreach ($xml->children() as $sectionName => $sectionNode) {
                    foreach ($sectionNode->children() as $itemName => $itemNode) {
                        $visibleName = trim((string)($itemNode['VisibleName'] ?? $itemName));
                        $cssClass    = (string)($itemNode['cssClass'] ?? 'fa fa-plug');

                        // Find the first navigable URL (direct or from first child page)
                        $firstUrl = (string)($itemNode['url'] ?? '');
                        if ($firstUrl === '') {
                            foreach ($itemNode->children() as $pageNode) {
                                $url = (string)($pageNode['url'] ?? '');
                                if ($url !== '') {
                                    $firstUrl = $url;
                                    break;
                                }
                            }
                        }

                        // Skip entries with no accessible URL or pure API endpoints
                        if ($firstUrl === '' || strpos($firstUrl, 'api/') === 0) {
                            continue;
                        }

                        $id = strtolower($vendor . '_' . $module . '_' . $itemName);
                        if (isset($seen[$id])) {
                            continue;
                        }
                        $seen[$id] = true;

                        $plugins[] = [
                            'id'      => $id,
                            'name'    => $visibleName,
                            'section' => $sectionName,
                            'url'     => $firstUrl,
                            'icon'    => $cssClass,
                            'vendor'  => $vendor,
                            'plugin'  => strtolower($module),
                        ];
                    }
                }
            } catch (\Exception $e) {
                continue;
            }
        }

        usort($plugins, function ($a, $b) {
            return strcmp($a['name'], $b['name']);
        });

        return ['items' => $plugins];
    }

    /**
     * Return saved category assignments and category list.
     */
    public function getSettingsAction()
    {
        $model = new ServiceHub();
        return [
            'assignments' => (string)$model->hub->assignments,
            'categories'  => (string)$model->hub->categories,
        ];
    }

    /**
     * Persist category assignments and category list.
     */
    public function setSettingsAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $assignments = $this->request->getPost('assignments', 'string', '{}');
        $categories  = $this->request->getPost('categories', 'string', '[]');

        // Validate that both values are valid JSON to prevent storing garbage
        if (json_decode($assignments) === null) {
            $assignments = '{}';
        }
        if (json_decode($categories) === null) {
            $categories = '[]';
        }

        $model = new ServiceHub();
        $model->hub->assignments = $assignments;
        $model->hub->categories  = $categories;
        $model->serializeToConfig();
        Config::getInstance()->save();

        return ['result' => 'saved'];
    }

    /**
     * Return whether the "collapse Services menu" overlay theme is active.
     */
    public function getHideStatusAction()
    {
        $cfg          = Config::getInstance()->object();
        $currentTheme = trim((string)($cfg->system->theme ?? 'opnsense'));
        return [
            'hideEnabled'  => ($currentTheme === 'servicehub'),
            'currentTheme' => $currentTheme,
        ];
    }

    /**
     * Activate the servicehub theme overlay (hides other Services menu items).
     */
    public function enableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $cfg          = Config::getInstance();
        $conf         = $cfg->object();
        $currentTheme = trim((string)($conf->system->theme ?? 'opnsense'));

        // Persist the previous theme so we can restore it later
        if ($currentTheme !== 'servicehub') {
            $model = new ServiceHub();
            $model->hub->previousTheme = $currentTheme;
            $model->serializeToConfig();
        }

        $conf->system->theme = 'servicehub';
        $cfg->save();
        (new Backend())->configdRun('webgui reload');

        return ['result' => 'saved'];
    }

    /**
     * Restore the previous theme, removing the Services menu overlay.
     */
    public function disableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $model        = new ServiceHub();
        $prevTheme    = trim((string)$model->hub->previousTheme);
        if ($prevTheme === '' || $prevTheme === 'servicehub') {
            $prevTheme = 'opnsense';
        }

        $cfg  = Config::getInstance();
        $conf = $cfg->object();
        $conf->system->theme = $prevTheme;

        $model->hub->previousTheme = '';
        $model->serializeToConfig();
        $cfg->save();
        (new Backend())->configdRun('webgui reload');

        return ['result' => 'saved', 'theme' => $prevTheme];
    }
}
