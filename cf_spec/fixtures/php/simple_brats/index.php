<html>
 <head>
  <title>PHP Test</title>
 </head>
 <body>
 <?php
echo '<p>Hello World!</p>';
if (htmlspecialchars($_GET["redis"])) {
  try {
    if (!class_exists('Redis')) {
      throw new Exception('Class not found.');
    }
    $redis = new Redis();
  } catch(Exception $e){
    echo 'Redis failed to load: ', $e->getMessage();
    return;
  }
  echo 'Redis loads';
}
?>
 </body>
</html>
