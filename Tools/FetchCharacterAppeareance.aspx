<?php
/**
 * Full character appearance for avatar rendering.
 * Output: semicolon-separated URLs (BodyColors + worn clothing/gear)
 */

include $_SERVER['DOCUMENT_ROOT'] . '/config.php';

$UserId = (int)($_GET['id'] ?? 0);
if ($UserId < 1) {
    header('Content-Type: application/json');
    die(json_encode(['message' => 'Cannot fetch request at this time.']));
}

$WardrobeSrh = $MainDB->prepare(
    "SELECT * FROM bought
     WHERE boughtby = :id AND wearing = '1'
       AND itemtype NOT IN ('model','advertisement','decal','audio')
     ORDER BY id"
);
$WardrobeSrh->execute([':id' => $UserId]);
$ReWDS = $WardrobeSrh->fetchAll(PDO::FETCH_ASSOC);

$parts = [];
$parts[] = $baseUrl . '/Tools/FetchBodyColor.aspx?id=' . $UserId;

// Also support Asset/BodyColors.ashx if that exists on your install
// $parts[] = $baseUrl . '/Asset/BodyColors.ashx?userId=' . $UserId;

if (!$ReWDS) {
    // Minimal defaults so RCC still produces a figure
    $parts[] = $baseUrl . '/Tools/FetchClothing.aspx?id=1&type=S';
    $parts[] = $baseUrl . '/Tools/FetchClothing.aspx?id=3&type=P';
    echo implode(';', $parts) . ';';
    exit;
}

foreach ($ReWDS as $AssetInfo) {
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
