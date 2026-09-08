const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, process.argv[2] || "src");
const index = process.argv[3] || "/index.html";
const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

http
  .createServer((req, res) => {
    const url = req.url.split("?")[0];
    if (url === "/") {
      res.writeHead(302, { location: index });
      return res.end();
    }
    const file = path.join(root, url);
    if (!file.startsWith(root)) {
      res.writeHead(403);
      return res.end("forbidden");
    }
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
        return res.end("not found");
      }
      res.writeHead(200, {
        "content-type": types[path.extname(file)] || "application/octet-stream",
      });
      res.end(data);
    });
  })
  .listen(process.env.PORT || 3000, () => {
    console.log(`serving ${root} on http://localhost:${process.env.PORT || 3000}`);
  });
