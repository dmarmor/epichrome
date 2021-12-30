#!/usr/bin/env php
<?php

// braveversion.php: PHP script for finding the latest version of Brave at brave.com
//
// Copyright (C) 2021  David Marmor
//
// https://github.com/dmarmor/epichrome
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


// turn off the many warnings emitted when reading HTML
error_reporting(error_reporting() & ~E_WARNING);

$braveLatest = new DOMDocument();
$braveLatest->strictErrorChecking = false;

$braveLatest->loadHTMLFile($argv[1]);

if (!$braveLatest->documentElement) {
    throw new Exception("Couldn't load " . $braveLatest->documentURI . '.');
}

// get <body> element
$desktopH3 = $braveLatest->getElementById('desktop')->nextSibling;
while ($desktopH3->nodeName && ($desktopH3->nodeName != 'h3')) {
    $desktopH3 = $desktopH3->nextSibling;
}
if (!preg_match('/v([0-9]+\.[0-9.]*[0-9])/i', $desktopH3->textContent, $version)) {
    throw new Exception("Couldn't find version number on " . $braveLatest->documentURI . '.');
}

print($version[1]."\n");

//print($desktopH3->textContent."\n");
?>
