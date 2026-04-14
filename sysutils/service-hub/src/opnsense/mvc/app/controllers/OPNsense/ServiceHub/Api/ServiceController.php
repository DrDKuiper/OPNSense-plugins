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
     * Build the servicehub overlay theme so it inherits from the user's
     * real theme and adds Services-menu hiding rules.
     */
    private function buildOverlayTheme($baseTheme)
    {
        $themesBase = '/usr/local/opnsense/www/themes';
        $srcDir     = $themesBase . '/' . $baseTheme;
        $dstDir     = $themesBase . '/servicehub';

        if (!is_dir($srcDir)) {
            return false;
        }

        // Ensure target dirs exist
        @mkdir($dstDir . '/build/css', 0755, true);
        @mkdir($dstDir . '/build/images', 0755, true);
        @mkdir($dstDir . '/build/fonts', 0755, true);

        // Symlink images and fonts directories from base theme
        $assetDirs = ['images', 'fonts'];
        foreach ($assetDirs as $dir) {
            $src = $srcDir . '/build/' . $dir;
            $dst = $dstDir . '/build/' . $dir;
            if (is_dir($src)) {
                if (is_link($dst)) {
                    unlink($dst);
                } elseif (is_dir($dst)) {
                    // Remove existing directory so we can symlink
                    $this->removeDir($dst);
                }
                symlink($src, $dst);
            }
        }

        // CSS files that just proxy through to the base theme
        $proxyCss = [
            'bootstrap-select.css',
            'bootstrap-dialog.css',
            'opnsense-bootgrid.css',
            'dashboard.css',
            'jquery.bootgrid.css',
            'tokenize2.css',
        ];
        foreach ($proxyCss as $file) {
            $src = $srcDir . '/build/css/' . $file;
            $dst = $dstDir . '/build/css/' . $file;
            if (file_exists($src)) {
                if (is_link($dst) || file_exists($dst)) {
                    unlink($dst);
                }
                symlink($src, $dst);
            }
        }

        // Generate main.css: import base theme + add hiding rules
        $hideRules = <<<'CSS'

/*
 * Services Hub — hide non-hub items in Services menu.
 *
 * Real sidebar structure:
 *   <div id="Services" class="collapse">
 *     <a href="#Services_Apcupsd" class="list-group-item" data-toggle="collapse">…</a>
 *     <div class="collapse" id="Services_Apcupsd">…</div>
 *     <a href="/ui/servicehub" class="list-group-item active">Services Hub</a>
 *   </div>
 */

/* Hide group headers (collapse toggles) inside #Services */
div#Services > a.list-group-item[data-toggle="collapse"] {
    display: none !important;
}

/* Hide group content divs inside #Services */
div#Services > div.collapse {
    display: none !important;
}

/* Hide direct leaf links that are NOT Services Hub */
div#Services > a.list-group-item:not([data-toggle]):not([href*="servicehub"]) {
    display: none !important;
}

/* Always keep Services Hub visible */
div#Services > a.list-group-item[href*="servicehub"] {
    display: block !important;
    font-weight: 600;
}
CSS;

        $mainCss = '@import url("/ui/themes/' . $baseTheme . '/build/css/main.css");'
                 . "\n" . $hideRules;

        file_put_contents($dstDir . '/build/css/main.css', $mainCss);

        return true;
    }

    /**
     * Remove a directory recursively.
     */
    private function removeDir($dir)
    {
        if (!is_dir($dir)) {
            return;
        }
        $items = scandir($dir);
        foreach ($items as $item) {
            if ($item === '.' || $item === '..') {
                continue;
            }
            $path = $dir . '/' . $item;
            if (is_dir($path) && !is_link($path)) {
                $this->removeDir($path);
            } else {
                unlink($path);
            }
        }
        rmdir($dir);
    }

    /**
     * Activate hub-only mode: build overlay theme and switch to it.
     */
    public function enableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $cfg  = Config::getInstance();
        $conf = $cfg->object();
        $currentTheme = trim((string)($conf->system->theme ?? 'opnsense'));

        // Don't overwrite previousTheme if already on servicehub
        $model = new ServiceHub();
        if ($currentTheme !== 'servicehub') {
            $model->hub->previousTheme = $currentTheme;
        }
        $model->hub->hubOnly = '1';
        $model->serializeToConfig();

        // Build overlay theme based on the user's real theme
        $baseTheme = ($currentTheme !== 'servicehub') ? $currentTheme : trim((string)$model->hub->previousTheme);
        if ($baseTheme === '' || $baseTheme === 'servicehub') {
            $baseTheme = 'opnsense';
        }

        if (!$this->buildOverlayTheme($baseTheme)) {
            $cfg->save();
            return ['result' => 'failed', 'message' => 'Base theme not found: ' . $baseTheme];
        }

        $conf->system->theme = 'servicehub';
        $cfg->save();

        return ['result' => 'saved'];
    }

    /**
     * Deactivate hub-only mode, restoring the user's original theme.
     */
    public function disableHideAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => 'POST required'];
        }

        $model     = new ServiceHub();
        $prevTheme = trim((string)$model->hub->previousTheme);
        if ($prevTheme === '' || $prevTheme === 'servicehub') {
            $prevTheme = 'opnsense';
        }

        $model->hub->hubOnly = '0';
        $model->serializeToConfig();

        $cfg  = Config::getInstance();
        $conf = $cfg->object();
        $conf->system->theme = $prevTheme;
        $cfg->save();

        return ['result' => 'saved', 'theme' => $prevTheme];
    }
}
