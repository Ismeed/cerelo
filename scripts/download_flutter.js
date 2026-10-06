const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const url = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip';
const zipPath = path.join(os.homedir(), 'flutter_windows.zip');
const destDir = path.join(os.homedir());

console.log(`[CERELO] Downloading Flutter 3.24.5 to ${zipPath}...`);

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    let file = fs.createWriteStream(destPath);
    let downloadedBytes = 0;
    let totalBytes = 0;
    let lastLog = Date.now();

    function get(currentUrl) {
      https.get(currentUrl, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          console.log(`Following redirect to ${res.headers.location}`);
          return get(res.headers.location);
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`Failed to download, status: ${res.statusCode}`));
        }

        totalBytes = parseInt(res.headers['content-length'] || '0', 10);
        console.log(`Content-Length: ${(totalBytes / (1024 * 1024)).toFixed(1)} MB`);

        res.on('data', (chunk) => {
          downloadedBytes += chunk.length;
          file.write(chunk);
          if (Date.now() - lastLog >= 5000) {
            const pct = totalBytes > 0 ? ((downloadedBytes / totalBytes) * 100).toFixed(1) : '?';
            const mb = (downloadedBytes / (1024 * 1024)).toFixed(1);
            console.log(`Progress: ${mb} MB (${pct}%)`);
            lastLog = Date.now();
          }
        });

        res.on('end', () => {
          file.end();
          console.log(`Download finished! Total size: ${(downloadedBytes / (1024 * 1024)).toFixed(1)} MB`);
          resolve();
        });

        res.on('error', (err) => {
          file.end();
          reject(err);
        });
      }).on('error', reject);
    }

    get(url);
  });
}

async function run() {
  try {
    if (fs.existsSync(zipPath)) {
      fs.unlinkSync(zipPath);
    }
    await downloadFile(url, zipPath);

    console.log(`Extracting zip to ${destDir}...`);
    // Use tar or powershell Expand-Archive
    execSync(`tar -xf "${zipPath}" -C "${destDir}"`, { stdio: 'inherit' });
    console.log('Extraction complete! Cleaning up zip...');
    fs.unlinkSync(zipPath);

    const flutterBin = path.join(destDir, 'flutter', 'bin');
    console.log(`Flutter installed at: ${flutterBin}`);
    const files = fs.readdirSync(flutterBin);
    console.log(`Bin files:`, files.slice(0, 5));
  } catch (err) {
    console.error('Error during Flutter install:', err);
    process.exit(1);
  }
}

run();
