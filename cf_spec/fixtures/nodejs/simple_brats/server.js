// Simple HTTP server example from nodejs.org website

var port = Number(process.env.PORT || 1337);
var http = require('http');
http.createServer(function (req, res) {
  switch(req.url){
    case '/bcrypt':
      var bcrypt = require('bcrypt');
      var salt = bcrypt.genSaltSync(10);
      var hash = bcrypt.hashSync('B4c0/\/', salt);

      res.writeHead(200, {'Content-Type': 'text/plain'});
      res.end('Hello Bcrypt!');
      break;
    case '/':
      res.writeHead(200, {'Content-Type': 'text/plain'});
      res.end('Hello World!');
      break;
    default:
      res.writeHead(404, {'Content-Type': 'text/plain'});
      res.end('no input url');
}

}).listen(port, function() {
  console.log("Listening on " + port);
});
