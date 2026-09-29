<?php
/**
 * Wear / unwear an owned item, then trigger avatar re-render.
 */

include $_SERVER['DOCUMENT_ROOT'] . '/config.php';
include $_SERVER['DOCUMENT_ROOT'] . '/UserInfo.php';

if ($RBXTICKET === null) {
    header('Location: ' . $baseUrl . '/Tools/ShowPopup.aspx?Err=4');
    exit;
}

$WearItem = (int)($_GET['id'] ?? 0);
$RequestType = $_GET['RequestType'] ?? '';

if ($WearItem < 1 || $RequestType === '') {
    header('Location: ' . $baseUrl . '/Tools/ShowPopup.aspx?Err=5');
    exit;
}

$WardrobeSrh = $MainDB->prepare(
    "SELECT id FROM bought
     WHERE boughtid = :id AND boughtby = :bid
       AND itemtype NOT IN ('model','advertisement','decal','audio')
     ORDER BY id DESC LIMIT 1"
);
$WardrobeSrh->execute([':id' => $WearItem, ':bid' => $id]);
$row = $WardrobeSrh->fetch(PDO::FETCH_ASSOC);

if (!$row) {
    header('Location: ' . $baseUrl . '/Tools/ShowPopup.aspx?Err=5');
    exit;
}

$renderUrl = $baseUrl . '/soap/amogs/roblox/render.php?id=' . (int)$id . '&redirect=false';

switch ($RequestType) {
    case 'WearItem':
        $MainDB->prepare("UPDATE bought SET wearing = '1' WHERE boughtid = ? AND boughtby = ?")
               ->execute([$WearItem, $id]);
        // Fire-and-forget render (do not follow redirects / do not block forever)
        $ctx = stream_context_create([
            'http' => [
                'timeout' => 25,
                'ignore_errors' => true,
            ],
        ]);
        @file_get_contents($renderUrl, false, $ctx);
        header('Location: ' . $baseUrl . '/My/Character.aspx');
        exit;

    case 'UnWearItem':
        $MainDB->prepare("UPDATE bought SET wearing = NULL WHERE boughtid = ? AND boughtby = ?")
               ->execute([$WearItem, $id]);
        $ctx = stream_context_create([
            'http' => [
                'timeout' => 25,
                'ignore_errors' => true,
            ],
        ]);
        @file_get_contents($renderUrl, false, $ctx);
        header('Location: ' . $baseUrl . '/My/Character.aspx');
        exit;

    default:
        header('Location: ' . $baseUrl . '/Tools/ShowPopup.aspx?Err=5');
        exit;
}
?>
