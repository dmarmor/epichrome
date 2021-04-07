<?php

// makeicon.php: PHP script for compositing images to make iconsets
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


// --- CONSTANTS ---

// ICON SIZE LIMITS

const ICON_SIZE_MAX = 1024;
const ICON_SIZE_MIN = 16;
const AUTOICON_SIZE_MIN = 48;


// AUTO-ICON INFO

// auto-icon user agent
const AUTOICON_USER_AGENT = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1';

// auto-icon timeout
const AUTOICON_PAGE_TIMEOUT = 5;
const AUTOICON_IMAGE_TIMEOUT = 3;

// auto-icon URL transforms
const AUTOICON_URL_TRANSFORMS = [
    [ 'Google Calendar',
        [
            ['/(^|\.)calendar\.google\.com$/i'],
            ['/(^|\.)google.com$/i', '/^\/calendar($|\/)/i'],
            
        ],
        'https://www.google.com/calendar/about/',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Google_Calendar_icon_%282020%29.svg/1024px-Google_Calendar_icon_%282020%29.svg.png'
    ],
    [ 'Google Drive',
        [
            ['/(^|\.)drive\.google\.com$/i']
        ],
        'https://www.google.com/drive/',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Google_Drive_icon_%282020%29.svg/1147px-Google_Drive_icon_%282020%29.svg.png'
    ],
    [ 'Gmail',
        [
            ['/(^|\.)gmail\.com$/i'],
            ['/(^|\.)g?mail\.google\.com$/i'],
            ['/(^|\.)google.com$/i', '#^/g?mail($|/)#i'],
            
        ],
        'https://www.google.com/gmail/about/#',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7e/Gmail_icon_%282020%29.svg/1280px-Gmail_icon_%282020%29.svg.png'
    ],
    [ 'Google Photos',
        [
            ['/(^|\.)photos\.google\.com$/i'],
            ['/(^|\.)google.com$/i', '/^\/photos($|\/)/i'],
            
        ],
        'https://www.google.com/photos/about/',
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Google_Photos_icon_%282020%29.svg/1024px-Google_Photos_icon_%282020%29.svg.png'
    ]
];

// auto-icon tag search
const AUTOICON_TAG_SEARCH = [
    ['link', 'rel', ['/^fluid-icon$/',
                    '/^apple-touch-icon.*/',
                    '/^icon$/'], 'href'],
    ['meta', 'name', [['/^msapplication-TileImage$/', 0]], 'content']
];

// auto-icon fallback filenames
const AUTOICON_FALLBACK = [
    'apple-touch-icon.png',
    'apple-touch-icon-precomposed.png',
    '/apple-touch-icon.png',
    '/apple-touch-icon-precomposed.png',
    'favicon.ico',
    '/favicon.ico'
];

// --- ACTIONS ---

// RUNACTION -- run an arbitrary list of image-processing actions
function runActions($aAction, $aInput = null) {
    
    // initialize current input
    $curInput = $aInput;
    
    // make sure we don't destroy this input during any subactions
    if ($curInput) { $curInput->preserve = true; }
    
    // loop through array of actions
    foreach ($aAction as $curAction) {
        if (is_array($curAction)) {
            
            // ACTION: RECURSE ON LIST OF SUBACTIONS
            
            $nextInput = runActions($curAction, $curInput);
            if (!$nextInput) {
                $nextInput = $curInput;
            }
            
        } elseif ($curAction->action == 'read') {
            
            // ACTION: READ IN FILE
            
            $nextInput = actionReadFile($curAction->options);
            
        } elseif ($curAction->action == 'composite') {
            
            // ACTION: COMPOSITE AN IMAGE WITH ANOTHER IMAGE
            
            // run composite
            $nextInput = actionComposite($curInput, $curAction->options);
            
        } elseif ($curAction->action == 'write_iconset') {
            
            // ACTION: WRITE OUT ICONSET
            
            actionWriteIconset($curInput, $curAction->path, $curAction->options);
            $nextInput = null;
            
        } elseif ($curAction->action == 'write_png') {
            
            // ACTION: WRITE OUT PNG
            
            actionWritePNG($curInput, $curAction->path, $curAction->resolution, $curAction->options);
            $nextInput = null;
            
        } elseif ($curAction->action == 'autoicon') {
            
            // ACTION: FIND AUTO-ICON
            
            // we immediately exit after this
            actionAutoIcon($curAction->options);
            
        } elseif ($curAction->action == 'testautoicon') {
            
            // ACTION: FIND AUTO-ICON
            
            // we immediately exit after this
            actionTestStaticAutoIcons();
            
        } else {
            
            // UNKNOWN ACTION
            throw new EpiException('Unknown action "' . strval($curAction->action) . '".');
        }
                
        // destroy any finished intermediate images
        if ($nextInput && $curInput && $curInput->image &&
            ($curInput->image != $nextInput->image) &&
            (!$aInput || ($curInput->image != $aInput->image))) {
            imagedestroy($curInput->image);
        }
                    
        // update current input
        $curInput = $nextInput;
    }
    
    // turn off preservation for this input
    if ($curInput) { unset($curInput->preserve); }
    
    return $curInput;
}


// ACTIONREADFILE -- read in & resize an image file
function actionReadFile($aOptions) {
    
    // determine image type (try passed format first, then file extension)
    $iExt = $aOptions->format;
    if (!$iExt) {
        $iExt = strtolower(end(explode(".", $aOptions->path)));
    }
    
    // create image object
    $iResult = newInput(null, $aOptions->path, $aOptions->origPath);
    
    // use correct function to open image
    if (($iExt == 'jpg') || $iExt == 'jpeg') {
        $iResult->image = imagecreatefromjpeg($iResult->path);
    } elseif ($iExt == 'png') {
        $iResult->image = imagecreatefrompng($iResult->path);
    } elseif ($iExt == 'gif') {
        $iResult->image = imagecreatefromgif($iResult->path);
    } elseif ($iExt == 'bmp') {
        $iResult->image = imagecreatefrombmp($iResult->path);
    // } elseif ($iExt == 'webp') {
    //     $iResult->image = imagecreatefromwebp($iResult->path);
    } elseif ($iExt) {
        throw new EpiException('File "' . basename($iResult->path) . '" is not a known image type.');
    } else {
        throw new EpiException('Unable to determine type of file "' . basename($iResult->path) . '".');
    }
    
    // make sure we got a proper image
    if (!$iResult->image) {
        throw new EpiException("Unable to read $iResult->errName.");
    }
    
    // convert to true color (no indexing)
    if (!imagepalettetotruecolor($iResult->image)) {
        throw new EpiException("Unable to convert $iResult->errName to true color.");
    }
        
    return $iResult;
}


// ACTIONCOMPOSITE -- composite two images onto a standard-sized square
function actionComposite($aInput, $aOptions) {
    
    // create result object
    $iResult = clone $aInput;
    
    // make sure we have an options object
    if (!$aOptions) { $aOptions = new stdClass(); }
    
    // create second input if necessary
    if (!$aOptions->with) {
        
        // create a transparent 1024x1024 reference source
        $iSecondInput = newInput();
        
    } elseif (is_array($aOptions->with)) {
        
        $iSecondInput = runActions($aOptions->with);
        
    }
    
    // set top and bottom layers
    $iTop = new stdClass(); $iBottom = new stdClass();
    if ($aOptions->compUnder) {
        $iTop->input = $iSecondInput;
        $iTop->options = new stdClass();
        $iBottom->input = $iResult;
        $iBottom->options = $aOptions;
    } else {
        $iTop->input = $iResult;
        $iTop->options = $aOptions;
        $iBottom->input = $iSecondInput;
        $iBottom->options = new stdClass();
    }
    
    
    // CALCULATE RESIZE & POSITION INFORMATION FOR BOTH LAYERS
    
    foreach ([$iTop, $iBottom] as $curLayer) {
        
        // get original (or default) image dimensions
        if ($curLayer->input->image) {
            $curLayer->origW = imagesx($curLayer->input->image);
            $curLayer->origH = imagesy($curLayer->input->image);
            $curLayer->dimMin = min($curLayer->origW, $curLayer->origH);
            $curLayer->dimMax = max($curLayer->origW, $curLayer->origH);
        } else {
            $curLayer->origW = ICON_SIZE_MAX;
            $curLayer->origH = ICON_SIZE_MAX;
            $curLayer->dimMin = ICON_SIZE_MAX;
            $curLayer->dimMax = ICON_SIZE_MAX;
        }
        
        // copy or set default size/position
        $curLayer->size = (is_numeric($curLayer->options->size) ?
                            $curLayer->options->size : 1.0);
        $curLayer->ctrX = (is_numeric($curLayer->options->ctrX) ?
                                $curLayer->options->ctrX : 0.5);
        $curLayer->ctrY = (is_numeric($curLayer->options->ctrY) ?
                                $curLayer->options->ctrY : 0.5);
                    
        // determine reference size
        if (!$curLayer->input->refSize) {
            
            // get starting resize dimension
            $iTargetSize = ($curLayer->size * ICON_SIZE_MAX);
            
            // choose key dimension
            if ($curLayer->options->crop) {
                // if cropping, use the smallest dimension
                $iKeyDim = $curLayer->dimMin;
            } else {
                // if fitting or not resizing, use the largest
                $iKeyDim = $curLayer->dimMax;
            }
            
            // select ref size based on key dimension & target size
            for ($curDiv = 2; $curDiv <= 64; $curDiv *= 2) {
                if ($iKeyDim > ($iTargetSize / $curDiv)) {
                    break;
                }
            }
            $curLayer->input->refSize = ICON_SIZE_MAX / ($curDiv/2);
        }
    }
    
    // get canvas size of final image
    $iCanvasSize = min($iTop->input->refSize, $iBottom->input->refSize);
    
    foreach ([$iTop, $iBottom] as $curLayer) {
        
        // scale size/position to canvas size
        $curLayer->size *= $iCanvasSize;
        $curLayer->ctrX *= $iCanvasSize;
        $curLayer->ctrY *= $iCanvasSize;
                
        if ($curLayer->options->crop) {
            
            // source starting point
            $iSrcOffset = (abs($curLayer->origW - $curLayer->origH) / 2);
            $curLayer->srcX = (($curLayer->dimMin == $curLayer->origW) ? 0 : $iSrcOffset);
            $curLayer->srcY = (($curLayer->dimMin == $curLayer->origH) ? 0 : $iSrcOffset);
            
            // source dimensions
            $curLayer->srcW = $curLayer->dimMin;
            $curLayer->srcH = $curLayer->dimMin;
            
            // destination starting point
            $curLayer->dstX = $curLayer->ctrX - ($curLayer->size / 2);
            $curLayer->dstY = $curLayer->ctrY - ($curLayer->size / 2);
            
            // destination dimensions
            $curLayer->dstW = $curLayer->size;
            $curLayer->dstH = $curLayer->size;

        } else {
            
            // source starting point
            $curLayer->srcX = 0;
            $curLayer->srcY = 0;
            
            // source dimensions
            $curLayer->srcW = $curLayer->origW;
            $curLayer->srcH = $curLayer->origH;
            
            // min dimensions after resize
            $iScaledMinDim = $curLayer->size * $curLayer->dimMin / $curLayer->dimMax;
            
            // destination starting point & dimensions
            if ($curLayer->dimMin == $curLayer->origW) {
                
                $curLayer->dstX = $curLayer->ctrX - ($iScaledMinDim / 2);
                $curLayer->dstY = $curLayer->ctrY - ($curLayer->size / 2);
                
                $curLayer->dstW = $iScaledMinDim;
                $curLayer->dstH = $curLayer->size;
                
            } else {
                
                $curLayer->dstX = $curLayer->ctrX - ($curLayer->size / 2);
                $curLayer->dstY = $curLayer->ctrY - ($iScaledMinDim / 2);
                
                $curLayer->dstW = $curLayer->size;
                $curLayer->dstH = $iScaledMinDim;
                
            }
        }
    }
    
    
    // RESIZE IF NECESSARY & COMPOSITE
    
    // resize bottom layer
    $iResult = compositeImage($iBottom->input, null, $iCanvasSize, false,
                                $iBottom->srcX, $iBottom->srcY,
                                $iBottom->srcW, $iBottom->srcH,
                                $iBottom->dstX, $iBottom->dstY,
                                $iBottom->dstW, $iBottom->dstH);
    if ($iBottom->input->image &&
        (!$aOptions->compUnder) &&
        ($iResult->image != $iBottom->input->image)) {
        
        // destroy bottom input
        imagedestroy($iBottom->input->image);
    }

    // composite top and bottom layers
    $iResult = compositeImage($iTop->input, $iResult, $iCanvasSize, $iTop->options->clip,
                                $iTop->srcX, $iTop->srcY,
                                $iTop->srcW, $iTop->srcH,
                                $iTop->dstX, $iTop->dstY,
                                $iTop->dstW, $iTop->dstH);
    if ($iTop->input->image &&
        $aOptions->compUnder &&
        ($iResult->image != $iTop->input->image)) {
        
        // destroy top input
        imagedestroy($iTop->input->image);
    }
    
    // if main input is on top, transfer path & errname to result
    if (!$aOptions->compUnder) {
        $iResult->path = $aTop->path;
        $iResult->errName = $aTop->errName;
    }
    
    return $iResult;
}


// ACTIONWRITEPNG -- save out PNG file at a given resolution
function actionWritePNG($aInput, $aPath, $aResolution, $aOptions) {
    
    // scale icon to requested resolution
    $iResult = clone $aInput;
    if ($aResolution) {
        $iResult->refSize = $aResolution;
    }
    $iResult = actionComposite($iResult, $aOptions);
    
    savePNG($iResult, $aPath);
}

    
// ACTIONWRITEICONSET -- save out iconset directory
function actionWriteIconset($aInput, $aPath, $aOptions) {
    
    // clone input for savePNG
    $iInput = clone $aInput;
    $iInputErrName = 'icon "' . basename($aPath) . '"';
    
    // make sure we have a reference size for this icon
    $iRefSize = ($aInput->refSize ? $aInput->refSize : ICON_SIZE_MAX);
    
    // get biggest size for this icon
    $iBiggestSize = $iRefSize;
    if ($aOptions->maxSize) { $iBiggestSize = min($aOptions->maxSize, $iBiggestSize); }
    
    // get smallest size for this icon
    $iSmallestSize = ICON_SIZE_MIN;
    if ($aOptions->minSize) { $iSmallestSize = max(min($aOptions->minSize, $iRefSize), $iSmallestSize); }
    
    // get biggest icon size
    $curSize = $iBiggestSize;
    
    while ($curSize >= $iSmallestSize) {
        
        // get next size down
        $nextSize = $curSize / 2;
        
        // set up error name
        $iInput->errName = "$iInputErrName ($curSize" . "px)";
        
        $curResult = compositeImage($iInput, null, $curSize, false,
                                    0, 0, $iRefSize, $iRefSize,
                                    0, 0, $curSize, $curSize);
        
        // output as nextSize x2
        if ($curSize != ICON_SIZE_MIN) {
            savePNG($curResult, sprintf("%s/icon_%dx%d@2x.png", $aPath, $nextSize, $nextSize));
        }
        
        // output as curSize
        if ($curSize != ICON_SIZE_MAX) {
            savePNG($curResult, sprintf("%s/icon_%dx%d.png", $aPath, $curSize, $curSize));
        }
        
        // destroy any shrunk images
        if ($curSize != $iRefSize) {
            imagedestroy($curResult->image);
        }
        
        $curSize = $nextSize;
    }
}


// ACTIONGETAUTOICON -- attempt to download an icon based on URL
function actionAutoIcon($aOptions) {
    
    // base path for candidate icons
    $iIconTempFileBase = $aOptions->tempImageDir . '/iconsource_';
    
    // initialize final icon list
    $iFinalIcons = [];
    
    
    // SET UP FOR AUTOICON WEB INTERACTION
    
    setupAutoIconSettings();
    
    
    // GET FINAL URL TO SEARCH
    
    // normalize & parse URL
    $iUrl = $aOptions->url;
    if (!parse_url($iUrl, PHP_URL_SCHEME)) { $iUrl = 'http://'.$iUrl; }
    $iUrlParts = parse_url($iUrl);
    
    // apply transforms for sites with hard-to-get icons
    $iMatchFound = false;
    foreach (AUTOICON_URL_TRANSFORMS as $curTransform) {
        foreach ($curTransform[1] as $curRule) {
            
            // get current regexes to match against URL
            $curHostMatch = $curRule[0]; if (!$curHostMatch) { $curHostMatch = '/.*/'; }
            $curPathMatch = $curRule[1]; if (!$curPathMatch) { $curPathMatch = '/.*/'; }
            
            // try to match URL
            if (preg_match($curHostMatch, $iUrlParts['host']) &&
                preg_match($curPathMatch, $iUrlParts['path'])) {
                $iMatchFound = true;
                break;
            }
        }
        
        if ($iMatchFound) {
            
            // try to download any static icon
            if ($curTransform[3]) {
                $iDownloadResult = downloadAutoIcon($curTransform[3], $iIconTempFileBase);
                if ($iDownloadResult) {
                    $iFinalIcons = [$iDownloadResult];
                }
            }
            
            // transform URL according to this rule
            $iUrl = $curTransform[2];
            $iUrlParts = parse_url($iUrl);
            
            // and we're done
            break;
        }
    }
    
    
    // IF NO STATIC ICON, LOAD URL & LOOK THROUGH TAGS
    
    if (!$iFinalIcons) {
        
        // load HTML
        $iDoc = loadUrl($iUrl);
        if ((!$iDoc) || !$iDoc->documentElement) {
            throw new EpiException("Couldn't load \"" . $aOptions->url . '".');
        }
        
        // update URL after redirects
        $iUrl = $iDoc->documentURI;
        $iUrlParts = parse_url($iUrl);
        
        // get <head> element
        $iHead = $iDoc->documentElement->getElementsByTagName('head')[0];
        
        
        // CREATE LIST OF ICON FILES TO TRY
        
        // search known tags for icon sources
        
        $iTagIcons = [];
        
        foreach (AUTOICON_TAG_SEARCH as $curTag) {
            
            // get all elements with current tag name
            $curElemList = $iHead->getElementsByTagName($curTag[0]);
            
            foreach ($curElemList as $curElem) {
                
                // get needed attributes for current element
                $curAttrList = $curElem->attributes;
                $curPath = $curAttrList->getNamedItem($curTag[3])->nodeValue;
                $curPropList = explode(' ', $curAttrList->getNamedItem($curTag[1])->nodeValue);
                
                foreach ($curPropList as $curProp) {
                    foreach ($curTag[2] as $curMatch) {
                        
                        if (preg_match($curMatch, $curProp)) {
                            
                            // found an icon!
                            $iTagIcons[] = $curPath;
                        }
                    }
                }
            }
        }
        
        // create unique list of candidate icons, with NULL between tag & fallback
        foreach (array_merge($iTagIcons, [null], AUTOICON_FALLBACK) as $curIcon) {
            if ($curIcon) {
                $iIconCandidates[] = absoluteUrlPath($iUrlParts, $curIcon);
            } else {
                $iIconCandidates[] = null;
            }
        }
        $iIconCandidates = array_unique($iIconCandidates);
        
        
        // DOWNLOAD & CHECK ICONS
        
        $iFinalIcons = [];
        foreach ($iIconCandidates as $curIcon) {
            
            if ($curIcon === null) {
                if (count($iFinalIcons) > 0) {
                    // good icon already found, so don't search fallback list
                    break;
                } else {
                    // move on to fallbacks
                    continue;
                }
            }
            
            // download and check current candidate
            $iDownloadResult = downloadAutoIcon($curIcon, $iIconTempFileBase);
            if ($iDownloadResult) {
                $iFinalIcons[] = $iDownloadResult;
            }
        }
    }
    
    
    // SELECT BIGGEST ICON
    
    if (count($iFinalIcons) > 0) {
        
        // sort final list of icons
        usort($iFinalIcons, function($a, $b) {
            if ($a[0] > $b[0]) {
                return -1;
            } elseif ($a[0] < $b[0]) {
                return 1;
            } elseif (($a[1] == 'png') && ($b[1] != 'png')) {
                return -1;
            } elseif (($a[1] != 'png') && ($b[1] == 'png')) {
                return 1;
            } else {
                return 0;
            }
        });
        
        foreach ($iFinalIcons as $curIcon) {
            if ($curIcon[1] == 'png') {
                
                // already a PNG, so just move it into place
                if (rename($curIcon[2], $aOptions->imagePath)) {
                    return true;
                }
                
            } else {
                
                // convert to PNG
                exec('/usr/bin/sips --setProperty format png --out ' .
                        escapeshellarg($aOptions->imagePath) . ' ' .
                        escapeshellarg($curIcon[2]), $iIgnore, $iResult);
                if ($iResult == 0) {
                    return true;
                }
            }
        }
    }
    
    // if we got here, we didn't find an icon
    throw new EpiException('No suitable icon found at "' . $aOptions->url . '".');
}


// ACTIONTESTSTATICAUTOICONS -- try downloading all static auto-icons and list any that fail to download
function actionTestStaticAutoIcons() {
    
    // set up for auto-icon downloading
    setupAutoIconSettings();
    
    $iResult = [];
    
    // try downloading each static auto-icon
    foreach (AUTOICON_URL_TRANSFORMS as $curTransform) {
        if ($curTransform[3]) {
            $iIconData = file_get_contents($curTransform[3]);
            if (!$iIconData) {
                $iResult[] = $curTransform[0];
            }
        }
    }
    
    // report any errors
    if (count($iResult) > 0) {
        fwrite(STDERR, 'STATICAUTOICONS|' . implode('|', $iResult));
        exit(1);
    }
}


// --- UTILITY FUNCTIONS ---

// COMPOSITEIMAGE -- resize an image to arbitrary dimensions & composite over another
function compositeImage($aTopInput, $aCanvasInput, $aCanvasSize, $aClipToCanvas,
                        $aSrcX, $aSrcY, $aSrcW, $aSrcH,
                        $aDstX, $aDstY, $aDstW, $aDstH) {
    
    // round all values
    $aSrcX = round($aSrcX);
    $aSrcY = round($aSrcY);
    $aSrcW = round($aSrcW);
    $aSrcH = round($aSrcH);
    $aDstX = round($aDstX);
    $aDstY = round($aDstY);
    $aDstW = round($aDstW);
    $aDstH = round($aDstH);
    
    // blank error message
    $iErrMsg = null;
    
    // create result input
    if (!$aCanvasInput) {
        // no canvas layer, so create an empty one based on top layer
        $iResult = clone $aTopInput;
        $iResult->image = null;
        unset($iResult->preserve);
    } else {
        // copy canvas layer to result
        $iResult = clone $aCanvasInput;
        unset($iResult->preserve);
    }
    
    // ref size will always be the canvas size
    $iResult->refSize = $aCanvasSize;
    
    // determine if we need to create a transparent canvas image
    if ((!$iResult->image) || $aCanvasInput->preserve || $aClipToCanvas) {
        
        // special case: top image doesn't need to be resized, moved, composited or cropped
        if ((!$iResult->image) && (!$aClipToCanvas) &&
            ($aSrcX == 0) && ($aSrcY == 0) &&
            ($aSrcW == $aCanvasSize) && ($aSrcH == $aCanvasSize) &&
            ($aDstX == 0) && ($aDstY == 0) &&
            ($aDstW == $aCanvasSize) && ($aDstH == $aCanvasSize)) {
            
            // we're done!
            $iResult->image = $aTopInput->image;
            return $iResult;
            
        } else {
            
            // create a transparent canvas image
            
            // create true color image
            if (! ($iNewImage = imagecreatetruecolor($aCanvasSize, $aCanvasSize))) {
                throw new EpiException('Unable to create empty image.');
            }
            
            // turn on alpha blending
            if (!imagealphablending($iNewImage, true)) {
                throw new EpiException('Unable to turn on alpha blending for empty image.');
            }
            
            // fill image with completely transparent white pixels
            if (!imagefill($iNewImage, 0, 0, imagecolorallocatealpha($iNewImage, 255,255,255,127))) {
                throw new EpiException('Unable to fill empty image.');
            }
            
            if (!$iResult->image) {
                
                // we had no image, so we just use the transparent one
                $iResult->image = $iNewImage;
                
                // special error message for single layer
                $iErrMsg = 'resize ' . $aTopInput->errName;
                
            } else {
                
                // we have a canvas image, but need to preserve the original, so copy
                if (!imagecopy($iNewImage, $iResult->image,
                        0, 0, 0, 0, $aCanvasSize, $aCanvasSize)) {
                    throw new EpiException('Unable to copy ' . $iResult->errName);
                }
                $iResult->image = $iNewImage;
            }
        }
    }
    
    // if top input is empty, we just return the canvas
    if ($aTopInput->image) {
        
        // resize & composite top image on canvas image
        if (!imagecopyresampled($iResult->image, $aTopInput->image,
                                $aDstX, $aDstY, $aSrcX, $aSrcY,
                                $aDstW, $aDstH, $aSrcW, $aSrcH)) {
            if (!$iErrMsg) {
                $iErrMsg = 'composite ' . $aTopInput->errName . ' with ' . $iResult->errName;
            }
            throw new EpiException('Unable to ' . $iErrMsg . '.');
        }
        
        // clip to canvas alpha if requested
        if ($aClipToCanvas) {
            
            // turn alpha blending off
            if (!imagealphablending ($iResult->image, false)) {
                throw new EpiException("Unable to turn off alpha blending to clip $iResult->errName.");
            }
            
            for ($iX = 0; $iX < $aCanvasSize; $iX++) {
                for ($iY = 0; $iY < $aCanvasSize; $iY++) {
                    
                    // get canvas alpha at iX,iY
                    if (($curAlpha = imagecolorat($aCanvasInput->image, $iX, $iY)) === false) {
                        throw new EpiException("Unable to retrieve alpha at ($iX,$iY) in $aCanvasInput->errName.");
                    }
                    $curAlpha = imagecolorsforindex($aCanvasInput->image, $curAlpha)['alpha'];
                    
                    // get result pixel at iX,iY
                    if (($curPixel = imagecolorat($iResult->image, $iX, $iY)) === false) {
                        throw new EpiException("Unable to retrieve pixel at ($iX,$iY) in $iResult->errName.");
                    }
                    $curPixel = imagecolorsforindex($iResult->image, $curPixel);
                    
                    // set alpha for this pixel to canvas alpha
                    if ($curAlpha > $curPixel['alpha']) {
                        if (!imagesetpixel($iResult->image, $iX, $iY,
                                imagecolorallocatealpha($iResult->image,
                                    $curPixel['red'],
                                    $curPixel['green'],
                                    $curPixel['blue'],
                                    $curAlpha))) {
                            throw new EpiException("Unable to set alpha at ($iX,$iY) in $iResult->errName.");
                        }
                    }
                }
            }
            
            // turn alpha blending back on
            if (!imagealphablending ($iResult->image, true)) {
                throw new EpiException("Unable to turn on alpha blending after clipping $iResult->errName.");
            }
        }
    }
    
    
    return $iResult;
}


// SAVEPNG -- save out a PNG file
function savePNG($aInput, $aPath) {
    
    // set up to save alpha channel
    if (!imagealphablending($aInput->image, false)) {
        throw new EpiException("Unable to turn off alpha blending for $aInput->errName.");
    }
    if (!imagesavealpha($aInput->image, true)) {
        throw new EpiException("Unable to save alpha channel for $aInput->errName.");
    }
    
    //  Save the image
    if (!imagepng($aInput->image, $aPath)) {
        throw new EpiException("Unable to save $aInput->errName.");
    }
}


// NEWINPUT -- create a new input object
function newInput($aImage = null, $aPath = null, $aOrigPath = null) {
    
    // create input
    $iResult = new stdClass();
    $iResult->image = $aImage;
    $iResult->path = $aPath;
    
    // set error name
    if (!$aOrigPath) { $aOrigPath = $aPath; }
    $iResult->errName = ($aOrigPath ? 'image "' . basename($aOrigPath) . '"' : 'unnamed image');
    
    // return result
    return $iResult;
}


// SETUPAUTOICONSETTINGS -- set up PHP settings and timeouts for downloading auto-icons
function setupAutoIconSettings() {

    // set user agent
    ini_set('user_agent', AUTOICON_USER_AGENT);
    
    // set timeout (https://stackoverflow.com/questions/21497561/domdocumentload-timeout)
    libxml_set_streams_context(stream_context_create([
        'http' => [
            'method' => 'GET',
            'timeout' => strval(AUTOICON_IMAGE_TIMEOUT)
        ]
    ]));
    ini_set('default_socket_timeout', AUTOICON_IMAGE_TIMEOUT);  // overriding timeout
    
    // turn off the many warnings emitted when reading HTML
    error_reporting(error_reporting() & ~E_WARNING);
}


// ABSOLUTEURLPATH -- convert an URL and possibly-relative path to an absolute URL
function absoluteUrlPath($aUrlParts, $aPath)
{
    // return if already absolute URL
    if (parse_url($aPath, PHP_URL_SCHEME) != '' || substr($aPath, 0, 2) == '//') return $aPath;
    
    // ignore queries and anchors
    if ($aPath[0]=='#' || $aPath[0]=='?') { $aPath = ''; }
    
    // destroy path if relative url points to root
    if ($aPath[0] == '/') {
        $aUrlParts['path'] = '';
    } elseif ($aPath) {
        // remove non-directory element from path
        $aUrlParts['path'] = preg_replace('#/[^/]*$#', '/', $aUrlParts['path']);
    }
        
    // create dirty absolute URL
    $iResult = $aUrlParts['host'] . ($aUrlParts['port'] ? ':' . $aUrlParts['port'] : '') . $aUrlParts['path'];
    
    if ($aPath) { $iResult .= '/' . $aPath; }
    
    // replace '//' or '/./' or '/foo/../' with '/'
    $iCanonicalRe = array('#(/\.?/)#', '#/(?!\.\.)[^/]+/\.\./#');
    do {
        $iResult = preg_replace($iCanonicalRe, '/', $iResult, -1, $iMatchCount);
    } while ($iMatchCount > 0);
    
    // add scheme and any user & password
    return $aUrlParts['scheme'] . '://' .
            ($aUrlParts['user'] ? $aUrlParts['user'] .
                ($aUrlParts['pass'] ? ':' . $aUrlParts['pass'] : '') . '@' : '') .
            $iResult;
}


// LOADURL -- load a URL while keeping track of redirects
function loadUrl($aUrl) {
    
    // initialize cURL
    $iCurl = curl_init($aUrl);
    curl_setopt_array($iCurl, array(
        CURLOPT_USERAGENT => AUTOICON_USER_AGENT,
        CURLOPT_TIMEOUT => AUTOICON_PAGE_TIMEOUT,
        CURLOPT_RETURNTRANSFER  => true,
        CURLOPT_FOLLOWLOCATION  => true
    ));
    
    // create result document
    $iResult = new DOMDocument();
    $iResult->strictErrorChecking = false;
    // $doc->preserveWhiteSpace = false;
    // $doc->formatOutput = true;
    
    // execute the request
    $iResult->loadHTML(curl_exec($iCurl));
    
    // extract the target url
    $iResult->documentURI = curl_getinfo($iCurl, CURLINFO_EFFECTIVE_URL);
    
    curl_close($iCurl);
    
    return $iResult;
}


// DOWNLOADAUTOICON -- download & check a potential autoicon
function downloadAutoIcon($aURL, $aIconTempFileBase) {
    
    // get file extension, if any
    $iExt = end(explode('.', explode('?', $aURL)[0]));
    if ($iExt) { $iExt = '.' . $iExt; }
    
    // create unique output file name
    do {
        $iOutPath = $aIconTempFileBase . sprintf('%03d', rand(0,999)) . $iExt;
    } while (file_exists($iOutPath));
            
    // download icon
    $iIconData = file_get_contents($aURL);
    
    if ($iIconData) {
        
        if (file_put_contents($iOutPath, $iIconData)) {
            
            // run sips on downloaded file
            exec("/usr/bin/sips --getProperty format --getProperty pixelWidth ".escapeshellarg($iOutPath),
                    $iSipsOutput, $iResult);
            
            if ($iResult == 0) {
                
                // collapse output into a single string
                $iSipsOutput = implode(" ", $iSipsOutput);
                
                // parse out image format & pixelWidth
                if (preg_match('/format: ([^ ]+).*pixelWidth: ([0-9]+)/i',
                        $iSipsOutput, $iSipsMatch, PREG_OFFSET_CAPTURE) &&
                    (intval($iSipsMatch[2][0]) >= AUTOICON_SIZE_MIN)) {
                    
                    // good image above minimum size, so add to list
                    return [intval($iSipsMatch[2][0]), $iSipsMatch[1][0], $iOutPath];
                }
            }
        }
    }
    
    return null;
}


// EPIEXCEPTION -- extend Exception class to identify known errors
class EpiException extends Exception { }


// MAIN FUNCTIONALITY

try {
    
    // decode JSON arguments
    $gActions = json_decode($argv[1]);
    if ($gActions === null) {
        fwrite(STDERR, "Bad arguments:\n$argv[1]\n");
        throw new EpiException('Unable to decode arguments.');
    }
    
    // run actions
    runActions($gActions);
    
} catch (Exception $gErr) {
    fwrite(STDERR, 'PHPERR|');
    if ($gErr instanceof EpiException) {
        fwrite(STDERR, $gErr->getMessage() . "\n");
    } else {
        fwrite(STDERR, 'Unknown error "' . $gErr->getMessage() .
                        '" in ' . basename($gErr->getFile()) .
                        ' on line ' . $gErr->getLine() . "\n");
    }
    exit(1);
}
?>
