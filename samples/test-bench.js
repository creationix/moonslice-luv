require('http').createServer(function (req, res) {
  res.writeHead(200, {
    "Content-Type": "text/plain",
    "Content-Length": 12
  });
  res.end("Hello World\n");
}).listen(8080, function () {
  console.log("http server listening at http://localhost:8080/");
});
