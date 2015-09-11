<html>
 <head>
  <title>PHP Test</title>
 </head>
 <body>
<?php
echo '<p>Hello World!</p>';

$name = $_SERVER['QUERY_STRING'];
if (extension_loaded($name)) {
  echo 'SUCCESS: ' . $name . ' loads.';
}
else {
  echo 'ERROR: ' . $name . ' failed to load.';
}
?>
 </body>
</html>
