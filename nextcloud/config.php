<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' =>
  array (
    0 =>
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 =>
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'instanceid' => 'ocng8hxds97y',
  'passwordsalt' => 'XNIxJOsEEs2bnAff/dUeleb9XXRBF+',
  'secret' => 'g4+4JEL1w57WlepwW7srp9/HrgbCu+VubK3/zB1vp2SS2SXz',
  'trusted_domains' =>
  array (
    0 => '192.168.32.146:1080',
    # 解决提示通过不被信任的域名访问：
    1 => preg_match('/cli/i',php_sapi_name())?'127.0.0.1':$_SERVER['SERVER_NAME'],
  ),
  'datadirectory' => '/var/www/html/data',
  "force_language" => "zh_CN",
  "default_locale" => "zh_CN",
  'dbtype' => 'mysql',
  'version' => '23.0.0.10',
  'overwrite.cli.url' => 'http://192.168.32.146:1080',
  'dbname' => 'nextcloud',
  'dbhost' => 'nextcloud_db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => '123456Aa',
  'installed' => true,
  'default_language' => 'zh_CN',
  'default_locale' => 'zh',
);
