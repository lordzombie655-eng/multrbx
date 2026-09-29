<?php
/**
 * MULTRBX Catalog item detail + purchase
 * URL: /CatalogItem?id=ASSET_ID
 */

include $_SERVER['DOCUMENT_ROOT'] . '/config.php';
include $_SERVER['DOCUMENT_ROOT'] . '/UserInfo.php';

$itemId = (int)($_GET['id'] ?? 0);
if ($itemId < 1) {
    header('Location: ' . $baseUrl . '/Catalog');
    exit;
}

$stmt = $MainDB->prepare(
    "SELECT * FROM asset WHERE id = :id AND approved = '1' AND public = '1' LIMIT 1"
);
$stmt->execute([':id' => $itemId]);
$item = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$item || in_array($item['itemtype'], ['place', 'advertisement'], true)) {
    header('Location: ' . $baseUrl . '/RobloxDefaultErrorPage.aspx?code=404');
    exit;
}

$owned = false;
if ($RBXTICKET !== null && $id) {
    $ownStmt = $MainDB->prepare('SELECT id FROM bought WHERE boughtby = :uid AND boughtid = :aid LIMIT 1');
    $ownStmt->execute([':uid' => $id, ':aid' => $itemId]);
    $owned = (bool)$ownStmt->fetch();
}

$isFree = isset($item['free']) && (string)$item['free'] === '1';
$rs = (int)($item['rsprice'] ?? 0);
$tx = (int)($item['tkprice'] ?? 0);

$thumb = $baseUrl . '/Tools/Asset.ashx?id=' . $itemId;
$buyBase = $baseUrl . '/Tools/PurchaseItem.ashx?id=' . $itemId;
?>
<?php if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/js/IncludeJS.php')) include $_SERVER['DOCUMENT_ROOT'] . '/js/IncludeJS.php'; ?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?php echo htmlspecialchars($item['name']); ?> - Catalog - MULTRBX</title>
  <link rel="stylesheet" href="<?php echo htmlspecialchars($baseUrl); ?>/CSS/Base/CSS/Roblox.css" />
  <link rel="stylesheet" href="<?php echo htmlspecialchars($baseUrl); ?>/CSS/Base/CSS/StyleGuide.css" />
  <style>
    body { background: #f2f2f2; font-family: Arial, Helvetica, sans-serif; }
    #ItemContainer { max-width: 970px; margin: 0 auto; padding: 16px; }
    .item-panel {
      background: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 20px;
      display: flex; flex-wrap: wrap; gap: 24px;
    }
    .item-thumb img {
      width: 250px; height: 250px; object-fit: contain; background: #e8e8e8; border-radius: 4px;
    }
    .item-info { flex: 1; min-width: 240px; }
    .item-info h1 { margin: 0 0 8px; font-size: 26px; color: #343434; }
    .item-info .type { color: #888; font-size: 13px; margin-bottom: 8px; text-transform: uppercase; }
    .item-info .creator { margin-bottom: 16px; font-size: 14px; }
    .item-info .creator a { color: #0055b3; text-decoration: none; }
    .item-info .creator a:hover { text-decoration: underline; }
    .price-box { font-size: 18px; font-weight: bold; color: #02b757; margin-bottom: 16px; }
    .btn-buy {
      display: inline-block; background: #00a2ff; color: #fff !important; border: none;
      border-radius: 3px; padding: 10px 18px; font-size: 14px; text-decoration: none;
      margin: 4px 6px 4px 0; cursor: pointer;
    }
    .btn-buy:hover { background: #32b5ff; }
    .btn-buy.tix { background: #f5c518; color: #333 !important; }
    .btn-buy.tix:hover { background: #ffd84d; }
    .btn-buy.free { background: #02b757; }
    .btn-buy.free:hover { background: #03d066; }
    .btn-disabled {
      display: inline-block; background: #ccc; color: #666 !important; border-radius: 3px;
      padding: 10px 18px; font-size: 14px; text-decoration: none; margin: 4px 6px 4px 0;
    }
    .back { margin-bottom: 12px; }
    .back a { color: #0055b3; text-decoration: none; font-size: 13px; }
    .back a:hover { text-decoration: underline; }
    .note { font-size: 12px; color: #888; margin-top: 12px; }
  </style>
</head>
<body>
  <div id="Container">
    <?php
    if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/Assembly/ContextHeader.php')) {
        include $_SERVER['DOCUMENT_ROOT'] . '/Assembly/ContextHeader.php';
    }
    ?>
    <div id="ItemContainer">
      <div class="back">
        <a href="<?php echo htmlspecialchars($baseUrl); ?>/Catalog">&laquo; Back to Catalog</a>
      </div>
      <div class="item-panel">
        <div class="item-thumb">
          <img src="<?php echo htmlspecialchars($thumb); ?>"
               alt="<?php echo htmlspecialchars($item['name']); ?>"
               onerror="this.src='<?php echo htmlspecialchars($baseUrl); ?>/Images/IDE/pending.png'">
        </div>
        <div class="item-info">
          <div class="type"><?php echo htmlspecialchars($item['itemtype']); ?></div>
          <h1><?php echo htmlspecialchars($item['name']); ?></h1>
          <div class="creator">
            By
            <a href="<?php echo htmlspecialchars($baseUrl . '/User.php?id=' . (int)$item['creatorid']); ?>">
              <?php echo htmlspecialchars($item['creatorname'] ?? 'Unknown'); ?>
            </a>
          </div>

          <div class="price-box">
            <?php
            if ($isFree) {
                echo 'Free';
            } else {
                $bits = [];
                if ($rs > 0) $bits[] = $rs . ' Robux';
                if ($tx > 0) $bits[] = $tx . ' Tickets';
                echo $bits ? htmlspecialchars(implode(' · ', $bits)) : 'Free';
            }
            ?>
          </div>

          <?php if ($RBXTICKET === null): ?>
            <a class="btn-buy" href="<?php echo htmlspecialchars($baseUrl); ?>/">Log in to purchase</a>
          <?php elseif ($owned): ?>
            <span class="btn-disabled">Already owned</span>
            <a class="btn-buy" href="<?php echo htmlspecialchars($baseUrl); ?>/My/Character.aspx">Go to Character</a>
          <?php else: ?>
            <?php if ($isFree || ($rs <= 0 && $tx <= 0)): ?>
              <a class="btn-buy free" href="<?php echo htmlspecialchars($buyBase . '&HandleMethod=Free'); ?>">Get for Free</a>
            <?php endif; ?>
            <?php if ($rs > 0): ?>
              <a class="btn-buy" href="<?php echo htmlspecialchars($buyBase . '&HandleMethod=Robux'); ?>">
                Buy for <?php echo $rs; ?> R$
              </a>
            <?php endif; ?>
            <?php if ($tx > 0): ?>
              <a class="btn-buy tix" href="<?php echo htmlspecialchars($buyBase . '&HandleMethod=Tickets'); ?>">
                Buy for <?php echo $tx; ?> Tix
              </a>
            <?php endif; ?>
          <?php endif; ?>

          <p class="note">Item ID: <?php echo (int)$itemId; ?></p>
        </div>
      </div>
    </div>
    <?php
    if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/Assembly/Footer.php')) {
        include $_SERVER['DOCUMENT_ROOT'] . '/Assembly/Footer.php';
    }
    ?>
  </div>
</body>
</html>
