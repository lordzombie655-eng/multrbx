<?php
/**
 * MULTRBX Catalog — main item listing
 * URL: /Catalog  or  /Catalog.aspx
 */

include $_SERVER['DOCUMENT_ROOT'] . '/config.php';
include $_SERVER['DOCUMENT_ROOT'] . '/UserInfo.php';

// Optional mobile redirect (same pattern as other pages)
if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/FuncTypes.php')) {
    include_once $_SERVER['DOCUMENT_ROOT'] . '/FuncTypes.php';
    if (function_exists('appCheckRedirect')) {
        appCheckRedirect('Catalog');
    }
}

$category = isset($_GET['Category']) ? trim($_GET['Category']) : (isset($_GET['cat']) ? trim($_GET['cat']) : 'All');
$search   = isset($_GET['Keyword']) ? trim($_GET['Keyword']) : (isset($_GET['q']) ? trim($_GET['q']) : '');
$page     = max(1, (int)($_GET['Page'] ?? $_GET['page'] ?? 1));
$perPage  = 30;
$offset   = ($page - 1) * $perPage;

// Categories that match your asset.itemtype values
$categories = [
    'All'      => null,
    'Hats'     => ['Hat', 'Hats', 'Accessory'],
    'Faces'    => ['Face', 'Faces'],
    'Gears'    => ['Gear', 'Gears'],
    'Shirts'   => ['Shirt', 'Shirts'],
    'T-Shirts' => ['T-Shirt', 'TShirt', 'T-Shirts'],
    'Pants'    => ['Pants'],
    'Packages' => ['Package', 'Packages'],
    'Heads'    => ['Head', 'Heads'],
    'Models'   => ['Model', 'Models'],
    'Decals'   => ['Decal', 'Decals'],
    'Audio'    => ['Audio', 'Sound'],
];

$allowedTypes = "itemtype NOT IN ('place','advertisement') AND approved = '1' AND public = '1'";
$params = [];

$sql = "SELECT id, name, itemtype, creatorid, creatorname, rsprice, tkprice, free, favorited
        FROM asset
        WHERE $allowedTypes";

if ($category !== 'All' && isset($categories[$category]) && $categories[$category] !== null) {
    $types = $categories[$category];
    $placeholders = [];
    foreach ($types as $i => $t) {
        $key = ":t$i";
        $placeholders[] = $key;
        $params[$key] = $t;
    }
    $sql .= ' AND itemtype IN (' . implode(',', $placeholders) . ')';
}

if ($search !== '') {
    $sql .= ' AND (name LIKE :q OR creatorname LIKE :q2)';
    $params[':q']  = '%' . $search . '%';
    $params[':q2'] = '%' . $search . '%';
}

// Count for pagination
$countSql = 'SELECT COUNT(*) FROM (' . $sql . ') AS cnt';
$countStmt = $MainDB->prepare($countSql);
$countStmt->execute($params);
$totalItems = (int)$countStmt->fetchColumn();
$totalPages = max(1, (int)ceil($totalItems / $perPage));

$sql .= ' ORDER BY id DESC LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset;
$stmt = $MainDB->prepare($sql);
$stmt->execute($params);
$items = $stmt->fetchAll(PDO::FETCH_ASSOC);

function catalogThumbUrl($baseUrl, $id) {
    return htmlspecialchars($baseUrl . '/Tools/Asset.ashx?id=' . (int)$id);
}

function priceLabel($row) {
    if (isset($row['free']) && (string)$row['free'] === '1') {
        return 'Free';
    }
    $parts = [];
    if (!empty($row['rsprice']) && (int)$row['rsprice'] > 0) {
        $parts[] = (int)$row['rsprice'] . ' R$';
    }
    if (!empty($row['tkprice']) && (int)$row['tkprice'] > 0) {
        $parts[] = (int)$row['tkprice'] . ' Tix';
    }
    return $parts ? implode(' / ', $parts) : 'Free';
}
?>
<?php if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/js/IncludeJS.php')) include $_SERVER['DOCUMENT_ROOT'] . '/js/IncludeJS.php'; ?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Catalog - MULTRBX</title>
  <link rel="stylesheet" href="<?php echo htmlspecialchars($baseUrl); ?>/CSS/Base/CSS/Roblox.css" />
  <link rel="stylesheet" href="<?php echo htmlspecialchars($baseUrl); ?>/CSS/Base/CSS/StyleGuide.css" />
  <style>
    body { background: #f2f2f2; font-family: Arial, Helvetica, sans-serif; }
    #CatalogContainer { max-width: 970px; margin: 0 auto; padding: 16px; }
    .catalog-header { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; }
    .catalog-header h1 { margin: 0; font-size: 28px; color: #343434; }
    .catalog-search input[type=text] { width: 220px; height: 28px; padding: 4px 8px; border: 1px solid #aaa; border-radius: 3px; }
    .catalog-search button, .cat-link {
      background: #00a2ff; color: #fff; border: none; border-radius: 3px; padding: 6px 12px;
      cursor: pointer; text-decoration: none; font-size: 13px; display: inline-block;
    }
    .catalog-search button:hover, .cat-link:hover { background: #32b5ff; color: #fff; }
    .cat-nav { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 16px; }
    .cat-nav a {
      background: #fff; border: 1px solid #ccc; color: #333; padding: 5px 10px; border-radius: 3px;
      text-decoration: none; font-size: 12px;
    }
    .cat-nav a.active, .cat-nav a:hover { background: #00a2ff; color: #fff; border-color: #00a2ff; }
    .item-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
      gap: 14px;
    }
    .item-card {
      background: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 10px;
      text-align: center; transition: box-shadow .15s;
    }
    .item-card:hover { box-shadow: 0 2px 10px rgba(0,0,0,.12); }
    .item-card img {
      width: 110px; height: 110px; object-fit: contain; background: #e8e8e8;
      border-radius: 3px; display: block; margin: 0 auto 8px;
    }
    .item-card .name {
      font-size: 13px; color: #0055b3; text-decoration: none; display: block;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-bottom: 4px;
    }
    .item-card .name:hover { text-decoration: underline; }
    .item-card .creator { font-size: 11px; color: #666; margin-bottom: 4px; }
    .item-card .price { font-size: 12px; font-weight: bold; color: #02b757; }
    .item-card .type-badge {
      font-size: 10px; color: #888; text-transform: uppercase; letter-spacing: .03em; margin-bottom: 4px;
    }
    .empty { background: #fff; border: 1px solid #ddd; padding: 40px; text-align: center; color: #666; border-radius: 4px; }
    .pager { margin-top: 20px; text-align: center; }
    .pager a, .pager span {
      display: inline-block; margin: 0 3px; padding: 5px 10px; border: 1px solid #ccc;
      border-radius: 3px; text-decoration: none; color: #333; background: #fff; font-size: 13px;
    }
    .pager a:hover { background: #00a2ff; color: #fff; border-color: #00a2ff; }
    .pager .current { background: #00a2ff; color: #fff; border-color: #00a2ff; }
    .meta { color: #888; font-size: 12px; margin-bottom: 10px; }
  </style>
</head>
<body>
  <div id="Container">
    <?php
    if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/Assembly/ContextHeader.php')) {
        include $_SERVER['DOCUMENT_ROOT'] . '/Assembly/ContextHeader.php';
    }
    ?>
    <div id="CatalogContainer">
      <div class="catalog-header">
        <h1>Catalog</h1>
        <form class="catalog-search" method="get" action="<?php echo htmlspecialchars($baseUrl); ?>/Catalog">
          <?php if ($category !== 'All'): ?>
            <input type="hidden" name="Category" value="<?php echo htmlspecialchars($category); ?>">
          <?php endif; ?>
          <input type="text" name="Keyword" placeholder="Search catalog..." value="<?php echo htmlspecialchars($search); ?>">
          <button type="submit">Search</button>
        </form>
      </div>

      <div class="cat-nav">
        <?php foreach (array_keys($categories) as $cat): ?>
          <a class="<?php echo $cat === $category ? 'active' : ''; ?>"
             href="<?php echo htmlspecialchars($baseUrl . '/Catalog?Category=' . urlencode($cat) . ($search !== '' ? '&Keyword=' . urlencode($search) : '')); ?>">
            <?php echo htmlspecialchars($cat); ?>
          </a>
        <?php endforeach; ?>
      </div>

      <div class="meta">
        <?php echo (int)$totalItems; ?> item<?php echo $totalItems === 1 ? '' : 's'; ?>
        <?php if ($category !== 'All'): ?> in <?php echo htmlspecialchars($category); ?><?php endif; ?>
        <?php if ($search !== ''): ?> matching “<?php echo htmlspecialchars($search); ?>”<?php endif; ?>
      </div>

      <?php if (!$items): ?>
        <div class="empty">
          <p>No items found in the catalog<?php echo $search !== '' ? ' for this search' : ''; ?>.</p>
          <p>If you expected items, check that assets have <code>approved = 1</code> and <code>public = 1</code> in the database.</p>
        </div>
      <?php else: ?>
        <div class="item-grid">
          <?php foreach ($items as $item): ?>
            <div class="item-card">
              <a href="<?php echo htmlspecialchars($baseUrl . '/CatalogItem?id=' . (int)$item['id']); ?>">
                <img src="<?php echo catalogThumbUrl($baseUrl, $item['id']); ?>"
                     alt="<?php echo htmlspecialchars($item['name']); ?>"
                     onerror="this.src='<?php echo htmlspecialchars($baseUrl); ?>/Images/IDE/pending.png'">
              </a>
              <div class="type-badge"><?php echo htmlspecialchars($item['itemtype']); ?></div>
              <a class="name" href="<?php echo htmlspecialchars($baseUrl . '/CatalogItem?id=' . (int)$item['id']); ?>">
                <?php echo htmlspecialchars($item['name']); ?>
              </a>
              <div class="creator">
                by
                <a href="<?php echo htmlspecialchars($baseUrl . '/User.php?id=' . (int)$item['creatorid']); ?>">
                  <?php echo htmlspecialchars($item['creatorname'] ?? 'Unknown'); ?>
                </a>
              </div>
              <div class="price"><?php echo htmlspecialchars(priceLabel($item)); ?></div>
            </div>
          <?php endforeach; ?>
        </div>

        <?php if ($totalPages > 1): ?>
          <div class="pager">
            <?php
            $basePageUrl = $baseUrl . '/Catalog?Category=' . urlencode($category)
                         . ($search !== '' ? '&Keyword=' . urlencode($search) : '');
            if ($page > 1): ?>
              <a href="<?php echo htmlspecialchars($basePageUrl . '&Page=' . ($page - 1)); ?>">&laquo; Prev</a>
            <?php endif;
            $start = max(1, $page - 3);
            $end = min($totalPages, $page + 3);
            for ($p = $start; $p <= $end; $p++):
              if ($p === $page): ?>
                <span class="current"><?php echo $p; ?></span>
              <?php else: ?>
                <a href="<?php echo htmlspecialchars($basePageUrl . '&Page=' . $p); ?>"><?php echo $p; ?></a>
              <?php endif;
            endfor;
            if ($page < $totalPages): ?>
              <a href="<?php echo htmlspecialchars($basePageUrl . '&Page=' . ($page + 1)); ?>">Next &raquo;</a>
            <?php endif; ?>
          </div>
        <?php endif; ?>
      <?php endif; ?>
    </div>
    <?php
    if (file_exists($_SERVER['DOCUMENT_ROOT'] . '/Assembly/Footer.php')) {
        include $_SERVER['DOCUMENT_ROOT'] . '/Assembly/Footer.php';
    }
    ?>
  </div>
</body>
</html>
