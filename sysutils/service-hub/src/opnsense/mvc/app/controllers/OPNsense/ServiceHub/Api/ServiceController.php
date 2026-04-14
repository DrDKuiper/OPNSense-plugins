<?php

namespace OPNsense\ServiceHub\Api;

use OPNsense\Base\ApiControllerBase;
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
     * Return whether hub-only mode is active.
     */
    public function getHideStatusAction()
    {
        $model = new ServiceHub();
        $enabled = trim((string)$model->hub->hubOnly) === '1';
        return [
            'hideEnabled'  => $enabled,
        ];
    }

    /**
     * Activate hub-only mode (hides other Services menu items via JS).
     */
    public function enableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $model = new ServiceHub();
        $model->hub->hubOnly = '1';
        $model->serializeToConfig();

        // If theme was previously set to 'servicehub', restore the real theme
        $cfg  = Config::getInstance();
        $conf = $cfg->object();
        $currentTheme = trim((string)($conf->system->theme ?? 'opnsense'));
        if ($currentTheme === 'servicehub') {
            $prevTheme = trim((string)$model->hub->previousTheme);
            if ($prevTheme === '' || $prevTheme === 'servicehub') {
                $prevTheme = 'opnsense';
            }
            $conf->system->theme = $prevTheme;
        }

        $cfg->save();

        return ['result' => 'saved'];
    }

    /**
     * Deactivate hub-only mode, restoring full Services menu.
     */
    public function disableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $model = new ServiceHub();
        $model->hub->hubOnly = '0';
        $model->serializeToConfig();

        // If theme was previously set to 'servicehub', restore the real theme
        $cfg  = Config::getInstance();
        $conf = $cfg->object();
        $currentTheme = trim((string)($conf->system->theme ?? 'opnsense'));
        if ($currentTheme === 'servicehub') {
            $prevTheme = trim((string)$model->hub->previousTheme);
            if ($prevTheme === '' || $prevTheme === 'servicehub') {
                $prevTheme = 'opnsense';
            }
            $conf->system->theme = $prevTheme;
        }

        $cfg->save();

        return ['result' => 'saved'];
    }
}
