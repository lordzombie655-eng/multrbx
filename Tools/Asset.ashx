<?php
/**
 * Serves rendered avatars and asset thumbnails as PNG.
 * Avatar: /Tools/Asset.ashx?id=USER_ID&request=avatar
 * Asset:  /Tools/Asset.ashx?id=ASSET_ID&request=asset  (or omit request)
 */

header('Content-Type: image/png');
header('Cache-Control: public, max-age=120');

$docRoot = rtrim($_SERVER['DOCUMENT_ROOT'], '/');

// Prefer main config; fall back to game config if present
if (file_exists($docRoot . '/config.php')) {
    include $docRoot . '/config.php';
} elseif (file_exists($docRoot . '/game/ProdRBX/Configuration.php')) {
    include $docRoot . '/game/ProdRBX/Configuration.php';
}

$errPath = $docRoot . '/Images/IDE/not-approved.png';
$penPath = $docRoot . '/Images/IDE/pending.png';

$errimg = file_exists($errPath) ? file_get_contents($errPath) : null;
$penimg = file_exists($penPath) ? file_get_contents($penPath) : null;

function serveOrFallback($path, $fallback) {
    if ($path && file_exists($path) && filesize($path) > 50) {
        readfile($path);
        exit;
    }
    if ($fallback !== null) {
        echo $fallback;
        exit;
    }
    // 1x1 transparent PNG
    echo base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    exit;
}

$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
$request = isset($_GET['request']) ? strtolower(trim($_GET['request'])) : 'asset';

if ($id < 1) {
    serveOrFallback(null, $errimg);
}

switch ($request) {
    case 'advertisement':
        header('Content-Type: text/html; charset=utf-8');
        $adType = $_GET['adtype'] ?? '';
        if (!isset($MainDB)) {
            echo '';
            exit;
        }
        $stmt = $MainDB->prepare("SELECT * FROM asset WHERE itemtype = 'advertisement' AND adtype = :adtype ORDER BY RAND() LIMIT 1");
        $stmt->execute([':adtype' => $adType]);
        $ad = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$ad) {
            echo '';
            exit;
        }
        $imgPath = $docRoot . '/Tools/RenderedAssets/' . $ad['id'] . '.png';
        if (file_exists($imgPath)) {
            $href = ($baseUrl ?? '') . ($adUrl ?? '/');
            echo '<a href="' . htmlspecialchars($href) . '" target="_top"><img src="' . htmlspecialchars(($baseUrl ?? '') . '/Tools/RenderedAssets/' . $ad['id'] . '.png') . '"></a>';
        }
        exit;

    case 'avatar':
        if (isset($MainDB)) {
            $stmt = $MainDB->prepare('SELECT id FROM users WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => $id]);
            if (!$stmt->fetch()) {
                serveOrFallback(null, $errimg);
            }
        }
        $avatarPath = $docRoot . '/Tools/RenderedUsers/' . $id . '.png';
        serveOrFallback($avatarPath, $penimg);
        break;

    default:
        // Generic asset thumbnail
        if (isset($MainDB)) {
            $stmt = $MainDB->prepare('SELECT id FROM asset WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => $id]);
            if (!$stmt->fetch()) {
                serveOrFallback(null, $errimg);
            }
        }
        $assetPath = $docRoot . '/Tools/RenderedAssets/' . $id . '.png';
        serveOrFallback($assetPath, $penimg);
        break;
}
?>
