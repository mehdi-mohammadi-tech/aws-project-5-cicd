const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: "Hallo aus Mehdi's Docker-Container!",
    projekt: "Projekt 5 - Container",
    hostname: require('os').hostname()
  }));
});

server.listen(3000, () => {
  console.log('Server läuft auf Port 3000');
});