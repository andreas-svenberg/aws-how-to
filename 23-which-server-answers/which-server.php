<?php
// which-server.php
// Shows which server answered: instance id and availability zone.
// Copy to a folder that all servers behind the load balancer share
// (for example EFS), so that every server has the same file.
// Each server runs the PHP itself and reads its OWN metadata (IMDSv2).
// Remove the file when you are done, it reveals the instance id.

header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');

$base = 'http://169.254.169.254/latest/';

// 1. IMDSv2 token (PUT request, token valid for 60 seconds)
$tokenContext = stream_context_create(['http' => [
    'method'  => 'PUT',
    'header'  => "X-aws-ec2-metadata-token-ttl-seconds: 60\r\n",
    'timeout' => 2,
]]);
$token = @file_get_contents($base . 'api/token', false, $tokenContext);
if ($token === false) {
    echo 'Could not get an IMDSv2 token from 169.254.169.254';
    exit;
}

// 2. Instance id and availability zone (GET with the token)
$getContext = stream_context_create(['http' => [
    'method'  => 'GET',
    'header'  => "X-aws-ec2-metadata-token: $token\r\n",
    'timeout' => 2,
]]);
$id = @file_get_contents($base . 'meta-data/instance-id', false, $getContext);
$az = @file_get_contents($base . 'meta-data/placement/availability-zone', false, $getContext);

// No trailing newline: the curl loop adds one with echo.
echo "Server $id in zone $az";
