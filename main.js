const { app, BrowserWindow, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 4242;

// Try to find Rscript; allow override via env R_SCRIPT_PATH
function guessRscriptPath() {
  if (process.env.R_SCRIPT_PATH) return process.env.R_SCRIPT_PATH;

  const platform = os.platform();
  const candidates = [];

  if (platform === 'win32') {
    // 1) bundled portable R (optional) if user adds it
    candidates.push(path.join(process.resourcesPath || __dirname, 'r-portable', 'R-Portable', 'App', 'R-Portable', 'bin', 'Rscript.exe'));
    // 2) common installs
    candidates.push('Rscript.exe');
  } else if (platform === 'darwin') {
    candidates.push('/opt/homebrew/bin/Rscript');
    candidates.push('/usr/local/bin/Rscript');
    candidates.push('/usr/bin/Rscript');
    candidates.push('Rscript');
  } else {
    candidates.push('/usr/bin/Rscript');
    candidates.push('/usr/local/bin/Rscript');
    candidates.push('Rscript');
  }
  return candidates[0]; // spawn will still fail if it's wrong; we show a nice error then.
}

let rProc = null;
let mainWindow = null;

function waitForShinyReady(url, timeoutMs = 20000, intervalMs = 500) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const check = () => {
      http.get(url, (res) => {
        if (res.statusCode === 200) resolve(true);
        else (Date.now() - start > timeoutMs) ? reject(new Error('Timeout waiting for Shiny')) : setTimeout(check, intervalMs);
      }).on('error', () => {
        (Date.now() - start > timeoutMs) ? reject(new Error('Timeout waiting for Shiny')) : setTimeout(check, intervalMs);
      });
    };
    check();
  });
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 800,
    backgroundColor: '#111827',
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const url = `http://127.0.0.1:${PORT}`;
  try {
    await waitForShinyReady(url);
    await mainWindow.loadURL(url);
    mainWindow.once('ready-to-show', () => mainWindow.show());
  } catch (e) {
    dialog.showErrorBox('Shiny startup issue', `${e.message}\n\nEnsure R and the 'shiny' package are installed, and that run_app.R runs without errors.`);
    app.quit();
  }
}

function launchR() {
  const rscript = guessRscriptPath();
  const runScriptPath = path.join(process.resourcesPath || __dirname, 'run_app.R');

  rProc = spawn(rscript, [runScriptPath], {
    cwd: process.resourcesPath || __dirname,
    env: { ...process.env, PORT: String(PORT) },
    shell: false,
    detached: false
  });

  rProc.stdout?.on('data', d => console.log('[R]', d.toString()));
  rProc.stderr?.on('data', d => console.error('[R]', d.toString()));
  rProc.on('exit', (code) => {
    console.log(`R exited with code ${code}`);
    if (mainWindow && !mainWindow.isDestroyed()) {
      dialog.showErrorBox('R exited', `R process exited with code ${code ?? 'unknown'}.`);
      app.quit();
    }
  });
}

function killR() {
  if (!rProc) return;
  try {
    if (process.platform === 'win32') {
      const { spawn } = require('child_process');
      spawn('taskkill', ['/PID', String(rProc.pid), '/T', '/F']);
    } else {
      process.kill(-rProc.pid, 'SIGTERM'); // try group
      rProc.kill('SIGTERM');
    }
  } catch(e) {
    console.error('Failed to kill R:', e);
  } finally {
    rProc = null;
  }
}

app.whenReady().then(() => {
  launchR();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('before-quit', () => {
  killR();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

process.on('SIGINT', () => { killR(); app.quit(); });
process.on('SIGTERM', () => { killR(); app.quit(); });
