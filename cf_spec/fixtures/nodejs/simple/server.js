// Simple HTTP server example from nodejs.org website

var port = Number(process.env.PORT || 1337);
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World!');
}).listen(port, function() {
  console.log("Listening on " + port);
});
