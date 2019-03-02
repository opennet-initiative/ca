<?php
// config variables
$debug = false;
//$debug = true;
$allowedExts = array("csr");
$allowedStatus = array("CSR", "Error");
$uploadFolder = "/var/www/csr_upload";
?>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">
<html>
  <head>
    <title>Opennet CA - Opennet Initiative e.V.</title>
    <script type="text/javascript">
    function toggle(control) {
      var elem = document.getElementById(control);
      if(elem.style.display == "none") {
        elem.style.display = "block";
      } else {
        elem.style.display = "none";
      }
    }
    </script>
  </head>
  <body>
    <h2>Opennet Certification Authority</h2>
    Check and approve a Certificate Signing Request (CSR) here.<br/>
    Pr&uuml;fe und best&auml;tige den Certificate Signing Request (CSR) hier.
    <h3>CSR Approval</h3>

<?php
$name = basename(filter_var($_SERVER["QUERY_STRING"], FILTER_SANITIZE_STRING));
$approver_dn = $_SERVER["SSL_CLIENT_S_DN"];
$approver_sn = $_SERVER["SSL_CLIENT_M_SERIAL"];
$approve = $_POST["approve"];
// prepare variables
$csrfile = $uploadFolder . "/" . $name . ".csr";
$jsonfile = $csrfile . ".json";
$extension = end(explode(".", $name . ".csr"));
// debug only (do not show to the user in normal operation)
if ($debug) echo "Name: " . $name . "<br/>Extension: " . $extension . "<br/>";
if ($debug) echo "CSR " . $csrfile . "<br/>JSON " . $jsonfile . "<br/>";
if (in_array($extension, $allowedExts))
{
  // check for errors
  if ($error > 0)
  {
    echo "<p><b>Error / Fehler</b>: ID" . $error. "</p>";
  }
  else
  {
    if (!file_exists($csrfile))
    {
      echo "<p><b>Error</b>: Invalid request. CSR not found.<br/><b>Fehler</b>: Ung&uuml;ltige Anfrage. CSR nicht gefunden.</p>";
    }
    else
    {
      if (!file_exists($jsonfile))
      {
        echo "<p><b>Error</b>: Invalid request. CSR-JSON not found.<br/><b>Fehler</b>: Ung&uuml;ltige Anfrage. CSR-JSON nicht gefunden.</p>";
      }
      else
      {
	// debug only (do not show to the user in normal operation)
        if ($debug) echo "CSR and JSON file found.<br/>";
        // inspect csr file
        $subject = shell_exec("openssl req -subject -noout -in " . $csrfile);
        $digest = shell_exec("openssl dgst -sha256 -c " . $csrfile . " | cut -d ' ' -f 2");
        $digest_short = hash("crc32", $digest);
        // inspect json file
        $jsontext = shell_exec("jq . " . $jsonfile);
        $json = json_decode($jsontext, true);
        $cn_filter = $json["cn_filter"];
        $mailto = $json["subject_mail"];
        $mailcc = $json["upload_ccmail"];
	// generate user report
        echo "<table>";
        echo "<tr><td>Subject:&nbsp;</td><td>" . $subject . "</td></tr>";
        echo "<tr><td>Digest:</td><td>" . $digest . " (SHA-256)<br/>" . $digest_short . " (CRC-32)</td></tr>";
        echo "<tr><td>CA:</td><td>" . $cn_filter . "</td></tr>";
        echo "<tr><td>Approver:&nbsp;</td><td>subject=" . $approver_dn . ", serial=" . $approver_sn . "</td></tr>";
	echo "<tr><td>Mail:</td><td>to:" . $mailto . " cc:" . $mailcc . "</td></tr>";
        echo "<tr><td>Metadata:</td><td><a href=\"javascript:toggle('json')\"><small>(Show or hide JSON / Zeige oder verstecke JSON)</small></a><div id=\"json\" style=\"display:none\"><pre>" . $jsontext . "</pre></div></td></tr>";
        echo "</table>";
        // approval form
        echo "<p>";
        echo "<div style=\"background-color:#eeeeee;padding:5px;width:450px\">";
        if ($approve == "true") 
        {
          if (in_array($json["status"], $allowedStatus))
          {
            $json["status"] = "Approved";
	    $json["approve_message"] = "subject=" . $approver_dn . ", serial=" . $approver_sn;
            $json["approve_timestamp"] = time();
            file_put_contents($jsonfile, json_encode($json));
            echo "<b>Success</b>: OK - Approved / Best&auml;tigt!";
          }
          else
          {
            echo "<b>Error</b>: Status of request is '" . $json["status"] . "'. Already approved?<br/><b>Fehler</b>: Status der Anfrage ist '" . $json["status"] . "'. Bereits best&auml;tigt?";
          }
        }
        else
        {
          echo "<form action=\"csr_approve.php?". $name . "\" method=\"post\" enctype=\"multipart/form-data\">";
          echo "<input type=\"checkbox\" name=\"approve\" value=\"true\">&nbsp;<small>Approve / Best&auml;tigen!</small><br/>";
          echo "<input type=\"submit\" name=\"submit\" value=\"Submit / &Uuml;bertragen\">";
          echo "</form>";
        }
        echo "</div>";
      }
    }
  }
}
else
{
  echo "<p><b>Error</b>: Invalid file. Please check your request.<br/><b>Fehler</b>: Ung&uuml;ltige Datei. Bitte pr&uuml;fe deine Anfrage.</p>";
}

?>

    <p>
    Back to / Zur&uuml;ck zu: <a href="/">Opennet CA</a>.
    </p>
    <p>
    <img src="/Opennet_logo_quer.gif">
    </p>
  </body>
</html>
