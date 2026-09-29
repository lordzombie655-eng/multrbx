<?php
/**
 * MULTRBX Avatar Renderer
 * Generates user avatar PNGs via RCCService and saves them to /Tools/RenderedUsers/
 *
 * Usage:
 *   /soap/amogs/roblox/render.php?id=USER_ID
 *   /soap/amogs/roblox/render.php?id=USER_ID&redirect=false   (returns PNG directly)
 */

error_reporting(E_ALL);
ini_set('display_errors', '0');

// Resolve base paths (works whether this file lives in soap/amogs/roblox/ or elsewhere)
$docRoot = rtrim($_SERVER['DOCUMENT_ROOT'] ?? dirname(__DIR__, 3), '/');
$scriptDir = __DIR__;

// Load RCC classes — try multiple common locations
$rccPaths = [
    $scriptDir . '/Grid/Rcc',
    $scriptDir,
    $docRoot . '/soap/amogs/roblox/Grid/Rcc',
    $docRoot . '/Grid/Rcc',
    $docRoot . '/soap/amogs/Grid/Rcc',
];

$rccLoaded = false;
foreach ($rccPaths as $path) {
    if (file_exists($path . '/RCCServiceSoap.php') || file_exists($path . '/rccrender.php')) {
        foreach (['Job.php', 'LuaType.php', 'LuaValue.php', 'ScriptExecution.php', 'Status.php', 'rccrender.php', 'RCCServiceSoap.php'] as $file) {
            $full = $path . '/' . $file;
            if (file_exists($full)) {
                require_once $full;
            }
        }
        $rccLoaded = true;
        break;
    }
}

if (!$rccLoaded) {
    http_response_code(500);
    header('Content-Type: text/plain');
    die('RCC classes not found. Place Grid/Rcc next to render.php or under DOCUMENT_ROOT.');
}

// Optional site config (for baseUrl)
if (file_exists($docRoot . '/config.php')) {
    include_once $docRoot . '/config.php';
}
$baseUrl = $baseUrl ?? ('https://' . ($_SERVER['SERVER_NAME'] ?? 'mulrbx.com'));

// ---------- Config (change these if your RCC listens elsewhere) ----------
$RCC_HOST = '127.0.0.1';
$RCC_PORT = 64989; // match the port your RCCService is actually running on
$RENDER_DIR = $docRoot . '/Tools/RenderedUsers';
$LUA_DIR = $scriptDir; // avat.lua / avatcloseup.lua expected here
// -----------------------------------------------------------------------

$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
$redirect = ($_GET['redirect'] ?? 'true') !== 'false';

if ($id < 1) {
    http_response_code(400);
    header('Content-Type: text/plain');
    die('Missing or invalid id');
}

if (!is_dir($RENDER_DIR)) {
    @mkdir($RENDER_DIR, 0755, true);
}

$pathNormal  = $RENDER_DIR . '/' . $id . '.png';
$pathCloseup = $RENDER_DIR . '/' . $id . '-closeup.png';

$avatLua = $LUA_DIR . '/avat.lua';
$closeupLua = $LUA_DIR . '/avatcloseup.lua';

if (!file_exists($avatLua)) {
    http_response_code(500);
    header('Content-Type: text/plain');
    die('avat.lua not found at: ' . $avatLua);
}

// Prefer RCCRenderer if available, otherwise RCCServiceSoap
$RCC = null;
try {
    if (class_exists('Roblox\\Grid\\Rcc\\RCCRenderer')) {
        $RCC = new Roblox\Grid\Rcc\RCCRenderer($RCC_HOST, $RCC_PORT);
    } elseif (class_exists('Roblox\\Grid\\Rcc\\RCCServiceSoap')) {
        $RCC = new Roblox\Grid\Rcc\RCCServiceSoap($RCC_HOST, $RCC_PORT);
    } else {
        throw new Exception('No RCC client class found');
    }
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: text/plain');
    die('Failed to connect to RCCService: ' . $e->getMessage());
}

function makeJobId(string $prefix): string {
    return $prefix . '_' . bin2hex(random_bytes(5));
}

function runRender($RCC, string $jobPrefix, string $scriptText, int $expiration = 90) {
    $jobId = makeJobId($jobPrefix);
    $job = new Roblox\Grid\Rcc\Job($jobId, $expiration);
    $script = new Roblox\Grid\Rcc\ScriptExecution('Render', $scriptText);
    $result = $RCC->OpenJobEx($job, $script);

    // Always try to close the job (use job ID string, not the object)
    try {
        $RCC->CloseJob($jobId);
    } catch (Throwable $e) {
        // ignore close errors
    }

    return $result;
}

function extractPng($jobResult): ?string {
    if ($jobResult === null || is_soap_fault($jobResult)) {
        return null;
    }
    // OpenJobEx usually returns an array of deserialized Lua values; first is base64 PNG
    if (is_array($jobResult) && isset($jobResult[0]) && is_string($jobResult[0])) {
        $raw = base64_decode($jobResult[0], true);
        if ($raw !== false && strlen($raw) > 100) {
            return $raw;
        }
    }
    // Sometimes a single string
    if (is_string($jobResult)) {
        $raw = base64_decode($jobResult, true);
        if ($raw !== false && strlen($raw) > 100) {
            return $raw;
        }
    }
    return null;
}

$serverName = $_SERVER['SERVER_NAME'] ?? 'mulrbx.com';
$baseForLua = 'http://' . $serverName; // RCC often expects http for asset fetches

// --- Normal full-body render ---
$scriptNormal = file_get_contents($avatLua) . "\nreturn start(\"" . $id . "\",\"" . $baseForLua . "\");";
$jobResultNormal = runRender($RCC, 'RENDER_NORMAL', $scriptNormal);
$imgNormal = extractPng($jobResultNormal);

if ($imgNormal === null) {
    http_response_code(502);
    header('Content-Type: text/plain');
    $debug = is_soap_fault($jobResultNormal)
        ? ('SOAP fault: ' . $jobResultNormal->faultstring)
        : ('Unexpected result: ' . substr(print_r($jobResultNormal, true), 0, 500));
    die("Avatar render failed for user {$id}. Is RCCService running on {$RCC_HOST}:{$RCC_PORT}?\n" . $debug);
}

file_put_contents($pathNormal, $imgNormal);
@chmod($pathNormal, 0644);

// --- Optional closeup ---
if (file_exists($closeupLua)) {
    $scriptCloseup = file_get_contents($closeupLua) . "\nreturn start(\"" . $id . "\",\"" . $baseForLua . "\");";
    $jobResultCloseup = runRender($RCC, 'RENDER_CLOSEUP', $scriptCloseup);
    $imgCloseup = extractPng($jobResultCloseup);
    if ($imgCloseup !== null) {
        file_put_contents($pathCloseup, $imgCloseup);
        @chmod($pathCloseup, 0644);
    }
}

if ($redirect) {
    $dest = $baseUrl . '/My/Character.aspx';
    header('Location: ' . $dest);
    exit;
}

header('Content-Type: image/png');
header('Cache-Control: no-cache, must-revalidate');
readfile($pathNormal);
exit;
?>
