// Quick node script to resolve which Rscript Electron would use.
const path = require('path');
const os = require('os');
const fs = require('fs');

const candidates = [
  path.join(__dirname, 'r-portable','R-Portable','App','R-Portable','bin','Rscript.exe'),
  '/opt/homebrew/bin/Rscript', '/usr/local/bin/Rscript', '/usr/bin/Rscript', 'Rscript'
];

for (const c of candidates) {
  try {
    if (fs.existsSync(c)) {
      console.log("Found candidate:", c);
    }
  } catch {}
}
console.log("Set R_SCRIPT_PATH to override, e.g.:");
console.log("  set R_SCRIPT_PATH=C:\\\\path\\\\to\\\\Rscript.exe   (Windows)");
console.log("  export R_SCRIPT_PATH=/usr/local/bin/Rscript       (macOS/Linux)");
