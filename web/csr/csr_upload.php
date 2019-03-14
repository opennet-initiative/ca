<?php
// config variables
$debug = false;
//$debug = true;
$allowedExts = array("csr");
$allowedType = array(
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

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">
<html>
  <head>
    <title>Opennet CA - Opennet Initiative e.V.</title>
  </head>
  <body>
    <h2>Opennet Certification Authority</h2>
    Welcome. You can upload your Certificate Signing Request (CSR) here.<br/>
    Willkommen. Hier kannst du deinen Zertifikatsanfrage (CSR) hochladen.
    <h3>CSR Upload</h3>
    <div style="background-color:#eeeeee;padding:5px;width:450px">
    Your file has been arrived. Deine Datei ist angekommen. 
    <p></p>
    <table>

<?php
// debug only (do not show to the user in normal operation)
if ($debug) echo "<tr><td>Debugging:</td><td>Enabled</td></tr>";
// get file data
$name = $_FILES["file"]["name"];
$type = $_FILES["file"]["type"];
$size = $_FILES["file"]["size"];
$store = $_FILES["file"]["tmp_name"];
$error = $_FILES["file"]["error"];
// prepare variables
$extension = end(explode(".", $name));
// inform user
echo "<tr><td>File / Datei:</td><td>" . $name . "</td></tr>";
// debug only (do not show to the user in normal operation)
if ($debug) {
  echo "<tr><td>Type:</td><td>" . $type . "</td></tr>";
  echo "<tr><td>Extension:</td><td>" . $extension . "</td></tr>";
  echo "<tr><td>Size:</td><td>" . $size . " Byte</td></tr>";
  echo "<tr><td>Temp stored:</td><td>" . $store . "</td></tr>";
}
// get optional data
$opt_name = $_POST["opt_name"];
$opt_mail = $_POST["opt_mail"];
// inform user
echo "<tr><td>Advisor / Betreuer:</td><td>" . $opt_name . "</td></tr>";
echo "<tr><td>CC E-Mail :</td><td>" . $opt_mail . "</td></tr>";
// process file
if (in_array($extension, $allowedExts) 
  && in_array($type, $allowedType)
  && $size < 4096)
{
  // check for errors
  if ($error > 0)
  {
    echo "<p><b>Error / Fehler</b>: ID" . $error. "</p>";
  }
  else
  {
    // check file via openssl
    $digest = shell_exec("openssl dgst -sha256 -c " . $store . " | cut -d ' ' -f2");
    $digest_short = hash("crc32", $digest);
    $subject = explode(",", shell_exec("openssl req -subject -noout -in " . $store));
    $subject_o = "<i>Error</i>";
    $subject_cn = "<i>Error</i>";
    $subject_mail = "<i>Error</i>";
    $err = -3;
    foreach($subject as $subject_part)
    {
      list($key, $value) = explode("=", $subject_part);
      $key=trim($key);
      $value=trim($value);
      switch($key) 
      {
        case "O": $subject_o = $value; $err++; break;
        case "CN": $subject_cn = $value; $err++; break;
        case "emailAddress": $subject_mail = $value; $err++; break;
      }
    }
    // debug only (do not show to the user in normal operation)
    if ($debug) {
      //echo "<tr><td>Digest:</td><td>" . $digest . " (SHA-256)</td></tr>";
      echo "<tr><td>Digest:</td><td>" . $digest_short . " (CRC-32)</td></tr>";
    }
    // inform user about content
    echo "<tr><td>Name:</td><td>" . $subject_o . "</td></tr>";
    echo "<tr><td>Node / Teilnehmer:&nbsp;&nbsp; </td><td>" . $subject_cn . "</td></tr>";
    echo "<tr><td>E-Mail:</td><td>" . $subject_mail . "</td></tr>";
    // process content status
    if ($err == 0) 
    {
      // check cn of csr against cn filter
      $cn = explode(".", $subject_cn);
      $cn_len = count($cn);
      if ($cn_len > 2) $cn_tail = $cn[$cn_len-2] . "." . $cn[$cn_len-1];
      // debug only (do not show to the user in normal operation)
      if ($debug) echo "<tr><td>CN Tail:</td><td>" . $cn_tail . "</td></tr>";
      $cnFilterValue = "<i>Error</i>";
      $err2 = -1;
      if (isset($cnFilter[$cn_tail])) 
      {
        $cnFilterValue = $cnFilter[$cn_tail];
	// check for old aps.on naming scheme
	if ((($cn_tail == "aps.on")||($cn_tail == "ugw.on")) && ($cn_len < 4))
	{
          if ($debug) echo "<tr><td>CN Check:</td><td>Naming scheme 'aps/ugw.on' check failed.</td></tr>";
	}
	else
	{
          $err2++;
	}
      }
      // debug only (do not show to the user in normal operation)
      if ($debug) echo "<tr><td>CN Filter:</td><td>" . $cnFilterValue . "</td></tr>";
      if ($err2 == 0)
      {
        // prepare filename
        $hash = $cnFilterValue . "_" . filter_var($subject_cn, FILTER_SANITIZE_STRING) . "_" . $digest_short . ".csr";
        $upload = $uploadFolder . "/" . $hash;
        // debug only (do not show to the user in normal operation)
        if ($debug) 
        {
          echo "<tr><td>Hashed Filename:</td><td>" . $hash . "</td></tr>";
          echo "<tr><td>Final stored:</td><td>" . $upload . "</td></tr>";
        }
        // move file to csr upload folder
        if (file_exists($upload))
        {
          echo "<p><b>Error</b>: Request '" . $hash . "' already exists<br/><b>Fehler</b>: Anfrage '" . $hash . "' existiert bereits</p>";
        }
        else
        {
          // store csr file
          move_uploaded_file($store, $upload);
          // prepare metadata
          $csrname = basename($hash, ".csr");
	  $timestamp = time();
          $json = array(
            "meta_type"=>"Opennet_CSR_JSON_v1", "meta_created"=>$timestamp, 
            "name"=>$csrname, "subject_o"=>$subject_o, "subject_cn"=>$subject_cn,
            "subject_mail"=>$subject_mail, "digest"=>$digest, "cn_filter"=>$cnFilterValue,
            "upload_timestamp"=>$timestamp, 
            "upload_advisor"=>$opt_name, "upload_ccmail"=>$opt_mail,
            "status"=>"CSR", "approve_message"=>"", "approve_timestamp"=>"",
            "sign_message"=>"", "sign_timestamp"=>"", 
            "revokeapprove_message"=>"", "revokeapprove_timestamp"=>"",
            "revoke_message"=>"", "revoke_timestamp"=>"",
            "error_message"=>"", "error_timestamp"=>""
          );
          // store metadata
          umask(0002);
          file_put_contents($upload . ".json", str_replace('\n', '', json_encode($json)));
          echo "<p><b>Success</b>: Stored as " . $hash . "<br/><b>Erfolgreich</b>: Gespeichert als " . $hash . "</p>";
          // send mail to csr team
          $mailheader = "From: " . $mailfrom . "\r\n";
	  $mailtext = "A new certificate signing request arrived.\r\nEine neue Zertifikatsanfrage ist eingetroffen.\r\n\r\ncommonName: " . $subject_cn . "\r\ndigest: " . $digest_short . "\r\n\r\napprove: <" . $approveurl . $csrname . ">\r\n\r\n" . $mailfooter;
          mail($mailto, $mailsubject, $mailtext, $mailheader);
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

    </table>
    </div>
    <p>
    Back to / Zur&uuml;ck zu: <a href="/">Opennet CA</a>.
    </p>
    <p>
    <img src="/Opennet_logo_quer.gif">
    </p>
  </body>
</html>
