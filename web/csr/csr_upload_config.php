<?php
// config variables
$debug = false;
//$debug = true;
$allowedExts = array("csr");
$allowedType = array(
  "application/x-x509-ca-cert",
  "application/octet-stream",
  "application/pkcs10",
  "text/opennet_csr");
$uploadFolder = "/var/www/opennetca_upload";
$cnFilter = array(
  "aps.on" => "vpn-user",
  "mobile.on" => "vpn-user",
  "ugw.on" => "vpn-ugw",
  "client.on" => "client",
  "opennet-initiative.de" => "server");
$mailto = "Opennet CSR Team <csr@opennet-initiative.de>";
$mailfrom = "Opennet CA <opennetca@opennet-initiative.de>";
$mailsubject = "Opennet CA (upload): Signing Request / Zertifikatsanfrage";
$mailfooter = "-- \r\nOpennet Initiative e.V.\r\nhttp://www.opennet-initiative.de\r\nCA Status: http://ca.opennet-initiative.de";
$approveurl = "https://ca.opennet-initiative.de/internal/csr_approve.php?";
?>
