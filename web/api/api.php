<?php

class OpennetCaApiServer 
{
	// variables
	private $version = 'Opennet CA API Server 0.1';
	private $resources = array('version', 'debug', 'csr');
	// main function
	public function serve() 
	{
		// get request data
		$uri = $_SERVER['REQUEST_URI'];
		$method = $_SERVER['REQUEST_METHOD'];
		$paths = explode('/', $this->paths($uri));
		array_shift($paths); // Hack; get rid of initials empty string
		array_shift($paths); // get rid of the initial api call
		$resource = array_shift($paths);
		// process request data
		switch($resource)
		{
			case 'version': 
				$this->res_version(); 
				break;
			case 'debug':
				$this->res_debug($uri, $method, $paths, $resource);
				break;
			case 'csr':
				$this->res_csr($method, $paths);
				break;
			default:
				$this->res_default();
				break;
		}
	}
	// path helper function
	private function paths($url) {
		$uri = parse_url($url);
		return $uri['path'];
	}
	// generate json output
	private function result($output) 
	{
        	header('Content-type: application/json');
        	echo json_encode($output);
	}
	// version resource function
	private function res_version()
	{
		$this->result(array($this->version));
	}
	// debug resource function
	private function res_debug($uri, $method, $paths, $resource)
	{
		$array = array('api-version' => $this->version, 'request-uri' => $uri, 
			'request-method' => $method, 'request-path' => $paths, 
			'request-resource' => $resource);
		$this->result($array);
	}
	// csr resource function
	private function res_csr($method, $paths)
	{
		switch($method) 
		{
			case 'PUT':
				break;
			case 'GET':
				$name = array_shift($paths);
				if (empty($name)) 
				{
					header('HTTP/1.1 404 Not Found');
				} else {
					header('Content-Type: application/pkcs10');
					echo file_get_contents('/var/www/opennetca_upload/vpnuser_27.aps.on_b5087400.csr');
				}
				break;
			default:
				header('HTTP/1.1 405 Method Not Allowed');
				header('Allow: GET, PUT');
				break;
		}
	}
	// default resource function
	private function res_default()
	{
		header('HTTP/1.1 404 Not Found');
		$this->result(array('api-version' => $this->version,
			'api-resources' => $this->resources));
	}
}

$server = new OpennetCaApiServer;
$server->serve();

?>
