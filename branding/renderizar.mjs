// Convierte SVG -> PNG (con transparencia) usando Chrome headless vía DevTools Protocol.
// Uso: node renderizar.mjs <chrome.exe> <perfilTemporal> <svg>:<tamaño>:<salida.png> ...
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const [, , chrome, perfil, ...trabajos] = process.argv;
const proc = spawn(chrome, ['--headless=new', '--disable-gpu', '--remote-debugging-port=9334',
  `--user-data-dir=${perfil}`, 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let ws;
for (let i = 0; i < 40 && !ws; i++) {
  try {
    const page = (await (await fetch('http://127.0.0.1:9334/json')).json()).find((t) => t.type === 'page');
    if (page) ws = new WebSocket(page.webSocketDebuggerUrl);
  } catch {}
  if (!ws) await sleep(300);
}
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const pend = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); }
});
const cmd = (method, params = {}) => new Promise((r) => { const i = ++id; pend.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

await cmd('Page.enable');
await cmd('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });

for (const t of trabajos) {
  const [svg, tam, salida] = t.split('|');
  const n = Number(tam);
  const contenido = readFileSync(svg, 'utf8').replace('<svg ', `<svg width="${n}" height="${n}" `);
  const html = `<html><body style="margin:0;background:transparent">${contenido}</body></html>`;
  await cmd('Emulation.setDeviceMetricsOverride', { width: n, height: n, deviceScaleFactor: 1, mobile: false });
  await cmd('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
  await sleep(250);
  const r = await cmd('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: n, height: n, scale: 1 } });
  mkdirSync(dirname(salida), { recursive: true });
  writeFileSync(salida, Buffer.from(r.result.data, 'base64'));
  console.log(`${salida} (${n}px)`);
}
ws.close();
proc.kill();
process.exit(0);
