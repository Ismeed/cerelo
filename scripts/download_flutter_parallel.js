const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const url = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip';
const zipPath = path.join(os.homedir(), 'flutter_windows.zip');
const destDir = path.join(os.homedir());
const CONCURRENCY = 16;

function getHeaders(targetUrl) {
  return new Promise((resolve, reject) => {
    https.request(targetUrl, { method: 'HEAD' }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return resolve(getHeaders(res.headers.location));
      }
      resolve({
        url: targetUrl,
        size: parseInt(res.headers['content-length'] || '0', 10),
        acceptRanges: res.headers['accept-ranges'] === 'bytes'
      });
    }).on('error', reject).end();
  });
}

function downloadChunk(targetUrl, start, end, fd, onProgress) {
  return new Promise((resolve, reject) => {
    const req = https.get(targetUrl, {
      headers: { Range: `bytes=${start}-${end}` }
    }, (res) => {
      if (res.statusCode !== 206 && res.statusCode !== 200) {
        return reject(new Error(`Chunk failed with status ${res.statusCode}`));
      }
      let offset = start;
      res.on('data', (chunk) => {
        fs.writeSync(fd, chunk, 0, chunk.length, offset);
        offset += chunk.length;
        onProgress(chunk.length);
      });
      res.on('end', () => resolve());
      res.on('error', reject);
    });
    req.on('error', reject);
  });
}

async function main() {
  console.log(`[CERELO] Getting file info for ${url}...`);
  const info = await getHeaders(url);
  console.log(`Total Size: ${(info.size / (1024 * 1024)).toFixed(1)} MB, Accept-Ranges: ${info.acceptRanges}`);

  if (!info.size) {
    throw new Error("Could not determine file size");
  }

  // Pre-allocate file
  const fd = fs.openSync(zipPath, 'w');
  fs.ftruncateSync(fd, info.size);

  const chunkSize = Math.ceil(info.size / CONCURRENCY);
  console.log(`Downloading with ${CONCURRENCY} parallel connections (${(chunkSize / (1024 * 1024)).toFixed(1)} MB/chunk)...`);

  let totalDownloaded = 0;
  let lastReport = Date.now();

  function onProgress(bytes) {
    totalDownloaded += bytes;
    if (Date.now() - lastReport >= 3000) {
      const mb = (totalDownloaded / (1024 * 1024)).toFixed(1);
      const totalMb = (info.size / (1024 * 1024)).toFixed(1);
      const pct = ((totalDownloaded / info.size) * 100).toFixed(1);
      console.log(`Progress: ${mb} / ${totalMb} MB (${pct}%)`);
      lastReport = Date.now();
    }
  }

  const tasks = [];
  for (let i = 0; i < CONCURRENCY; i++) {
    const start = i * chunkSize;
    const end = Math.min(start + chunkSize - 1, info.size - 1);
    tasks.push(downloadChunk(info.url, start, end, fd, onProgress));
  }

  const startTime = Date.now();
  await Promise.all(tasks);
  fs.closeSync(fd);

  const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
  const avgSpeed = ((info.size / (1024 * 1024)) / elapsedSec).toFixed(2);
  console.log(`Download complete in ${elapsedSec}s! Average speed: ${avgSpeed} MB/s`);

  console.log(`Extracting ${zipPath} to ${destDir}...`);
  execSync(`tar -xf "${zipPath}" -C "${destDir}"`, { stdio: 'inherit' });
  console.log('Extraction complete! Removing zip file...');
  fs.unlinkSync(zipPath);

  const flutterBin = path.join(destDir, 'flutter', 'bin');
  console.log(`Flutter successfully installed at: ${flutterBin}`);
}

main().catch(err => {
  console.error("Parallel download error:", err);
  process.exit(1);
});
