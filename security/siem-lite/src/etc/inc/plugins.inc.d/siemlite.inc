<?php

/*
 * Copyright (C) 2024 Kuiper
 * All rights reserved.
 */

function siemlite_services()
{
    global $config;

    $services = array();

    if (
        isset($config['OPNsense']['SIEMLite']['general']['enabled']) &&
        $config['OPNsense']['SIEMLite']['general']['enabled'] == '1'
    ) {
        $services[] = array(
            'description' => gettext('SIEM-Lite Security Engine'),
            'configd' => array(
                'restart' => array('siemlite restart'),
                'start'   => array('siemlite start'),
                'stop'    => array('siemlite stop'),
            ),
            'name' => 'siemlite',
            'pidfile' => '/var/run/siemlite.pid',
        );
    }

    return $services;
}
