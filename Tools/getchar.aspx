<?php
/**
 * Character appearance string for RCC / client.
 * Returns semicolon-separated asset URLs (BodyColors + worn items).
 * Used by clothing_render.lua and similar scripts.
 */

include $_SERVER['DOCUMENT_ROOT'] . '/config.php';

$userId = (int)($_GET['id'] ?? 0);
if ($userId < 1) {
    header('Content-Type: application/json');
    die(json_encode(['message' => 'Cannot fetch request at this time.']));
}

// Prefer the full appearance endpoint logic
$WardrobeSrh = $MainDB->prepare(
    "SELECT * FROM bought
     WHERE boughtby = :id AND wearing = '1'
       AND itemtype NOT IN ('model','advertisement','decal','audio')
     ORDER BY id"
);
$WardrobeSrh->execute([':id' => $userId]);
$items = $WardrobeSrh->fetchAll(PDO::FETCH_ASSOC);

$parts = [];

// Body colors first
$parts[] = $baseUrl . '/Asset/BodyColors.ashx?userId=' . $userId;
// Fallback path some installs use
// $parts[] = $baseUrl . '/Tools/FetchBodyColor.aspx?id=' . $userId;

if (!$items) {
    // Default shirt / pants placeholders if your DB has them as id 1 and 3
    $parts[] = $baseUrl . '/Tools/FetchClothing.aspx?id=1&type=S';
    $parts[] = $baseUrl . '/Tools/FetchClothing.aspx?id=3&type=P';
    echo implode(';', $parts) . ';';
    exit;
}

foreach ($items as $AssetInfo) {
    switch ($AssetInfo['itemtype']) {
        case 'T-Shirt':
        case 'Shirt':
        case 'Pants':
        case 'Body Colors':
            $parts[] = $baseUrl . '/asset/?id=' . (int)$AssetInfo['boughtid'];
            break;

        case 'Package':
            $packageId = $AssetInfo['boughtid'];
            $packageQuery = $MainDB->prepare('SELECT * FROM package WHERE packageid = :packageId');
            $packageQuery->execute([':packageId' => $packageId]);
            $package = $packageQuery->fetch(PDO::FETCH_ASSOC);
            if ($package) {
                for ($i = 1; $i <= 5; $i++) {
                    $itemId = $package['id' . $i] ?? null;
                    if (!empty($itemId)) {
                        $parts[] = $baseUrl . '/asset/?id=' . (int)$itemId;
                    }
                }
            }
            break;

        default:
            $parts[] = $baseUrl . '/asset/?id=' . (int)$AssetInfo['boughtid'];
            break;
    }
}

echo implode(';', $parts) . ';';
?>
