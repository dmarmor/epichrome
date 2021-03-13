#!/usr/bin/php
<?php

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
