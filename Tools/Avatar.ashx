<?php
/**
 * Simple avatar endpoint: /Tools/Avatar.ashx?id=USER_ID
 */

header('Content-Type: image/png');
header('Cache-Control: public, max-age=120');

$docRoot = rtrim($_SERVER['DOCUMENT_ROOT'], '/');

if (file_exists($docRoot . '/config.php')) {
    include $docRoot . '/config.php';
}

$errPath = $docRoot . '/Images/IDE/not-approved.png';
$penPath = $docRoot . '/Images/IDE/pending.png';
$errimg = file_exists($errPath) ? file_get_contents($errPath) : null;
$penimg = file_exists($penPath) ? file_get_contents($penPath) : null;

$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($id < 1) {
    if ($errimg) { echo $errimg; } else { echo ''; }
    exit;
}

if (isset($MainDB)) {
    $stmt = $MainDB->prepare('SELECT id FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    if (!$stmt->fetch()) {
        if ($errimg) { echo $errimg; } else { echo ''; }
        exit;
    }
}

$path = $docRoot . '/Tools/RenderedUsers/' . $id . '.png';
if (file_exists($path) && filesize($path) > 50) {
    readfile($path);
    exit;
}

if ($penimg) {
    echo $penimg;
} else {
    // transparent 1x1
    echo base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
}
?>
