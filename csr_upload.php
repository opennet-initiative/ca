<?php
// config variables
$debug = false;
//$debug = true;
$allowedExts = array("csr");
$allowedType = array("application/octet-stream", "application/pkcs10");
$uploadFolder = "/var/www/csr_upload";
$cnFilter = array(
  "aps.on" => "vpnuser",
  "mobile.on" => "vpnuser",
  "ugw.on" => "vpnugw");
?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">
<html>
  <head>
    <title>Opennet CA - Opennet Initiative e.V.</title>
  </head>
  <body>
    <h2>Opennet Certification Authority</h2>
    Welcome. You can upload your Certificate Signing Request (CSR) here.</br>
    Willkommen. Hier kannst du deinen Zertifikatsanfrage (CSR) hochladen.
    <h3>CSR Upload</h3>
    <div style="background-color:#eeeeee;padding:5px;width:450px">
    Your file has been arrived. Deine Datei ist angekommen. 
    <p></p>

<?php
// debug only (do not show to the user in normal operation)
if ($debug) echo "Debugging: enabled<br/>";
// get file data
$name = $_FILES["file"]["name"];
$type = $_FILES["file"]["type"];
$size = $_FILES["file"]["size"];
$store = $_FILES["file"]["tmp_name"];
$error = $_FILES["file"]["error"];
// prepare variables
$extension = end(explode(".", $name));
// inform user
echo "File / Datei: " . $name . "<br/>";
// debug only (do not show to the user in normal operation)
if ($debug) {
  echo "Type: " . $type . "<br/>";
  echo "Extension: " . $extension . "<br/>";
  echo "Size: " . $size . " Byte<br/>";
  echo "Temp stored: " . $store . "</br>";
}
// process file
if (in_array($extension, $allowedExts) 
  && in_array($type, $allowedType)
  && $size < 4096)
{
  // check for errors
  if ($error > 0)
  {
    echo "<b>Error</b>: " . $error. "<br/>";
  }
  else
  {
    // check file via openssl
    $digest = shell_exec("openssl dgst -sha256 -c " . $store . " | cut -d ' ' -f2");
    $digest_short = hash("crc32", $digest);
    $subject = explode("/", shell_exec("openssl req -subject -noout -in " . $store));
    $subject_o = "<i>Error</i>";
    $subject_cn = "<i>Error</i>";
    $subject_mail = "<i>Error</i>";
    $err = -3;
    foreach($subject as $subject_part)
    {
      list($key, $value) = explode("=", $subject_part);
      switch($key) 
      {
        case "O": $subject_o = $value; $err++; break;
        case "CN": $subject_cn = $value; $err++; break;
        case "emailAddress": $subject_mail = $value; $err++; break;
      }
    }
    // debug only (do not show to the user in normal operation)
    if ($debug) {
      echo "Digest: " . $digest . " (SHA-256)<br/>";
      echo "Digest: " . $digest_short . " (CRC-32)<br/>";
    }
    // inform user about content
    echo "Name: " . $subject_o . "<br/>";
    echo "Node / Teilnehmer: " . $subject_cn . "<br/>";
    echo "E-Mail: " . $subject_mail . "<br/>";
    // process content status
    if ($err == 0) 
    {
      // check cn of csr against cn filter
      $cn = explode(".", $subject_cn);
      $cn_len = count($cn);
      if ($cn_len > 2) $cn_tail = $cn[$cn_len-2] . "." . $cn[$cn_len-1];
      // debug only (do not show to the user in normal operation)
      if ($debug) echo "CN Tail: " . $cn_tail . "<br/>";
      $cnFilterValue = "<i>Error</i>";
      $err2 = -1;
      if (isset($cnFilter[$cn_tail])) 
      {
        $cnFilterValue = $cnFilter[$cn_tail];
        $err2++;
      }
      // debug only (do not show to the user in normal operation)
      if ($debug) echo "CN Filter: " . $cnFilterValue . "<br/>";
      if ($err2 == 0)
      {
        // prepare filename
        $hash = $cnFilterValue . "_" . filter_var($subject_cn, FILTER_SANITIZE_STRING) . "_" . $digest_short . ".csr";
        $upload = $uploadFolder . "/" . $hash;
        // debug only (do not show to the user in normal operation)
        if ($debug) 
        {
          echo "Hashed Filename: " . $hash . "<br/>";
          echo "Final stored: " . $upload . "<br/>";
        }
        // move file to csr upload folder
        if (file_exists($upload))
        {
          echo "<p><b>Error</b>: Request '" . $hash . "' already exists<br/><b>Fehler</b>: Anfrage '" . $hash . "' existiert bereits</p>";
        }
        else
        {
          move_uploaded_file($store, $upload);
          echo "<p><b>Success</b>: Stored as " . $hash . "<br/><b>Erfolgreich</b>: Gespeichert als " . $hash . "</p>";
        }
      }
      else
      {
        echo "<p><b>Error</b>: Unable to filter node id / common name.<br/><b>Fehler</b>: Kann Knoten Nummer / Common Name nicht interpretieren.</p>";
      }
    }
    else
    {
      echo "<p><b>Error</b>: Unable to parse CSR file.<br/><b>Fehler</b>: Kann CSR Datei nicht interpretieren.</p>";
    }
  }
}
else
{
  echo "<p><b>Error</b>: Invalid file. Please only upload CSR files.<br/><b>Fehler</b>: Ung&uuml;ltige Datei. Bitte nur CSR Dateien hochladen.</p>";
}
?>
    
    </div>
    <p>
    Back to / Zur&uuml;ck zu: <a href="../">Opennet CA</a>.
    </p>
    <p>
    <img src="../Opennet_logo_quer.gif">
    </p>
  </body>
</html>
