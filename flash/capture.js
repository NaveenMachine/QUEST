(async () => {
  const puppeteer = (await import('/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js')).default;
  const path = await import('node:path');
  const fs = await import('node:fs');

  const FPS = 18;
  const W = 1200, H = 675;
  const OUT = '/tmp/gif_build/frames';
  const chromePath = fs.existsSync('/usr/bin/google-chrome')
    ? '/usr/bin/google-chrome'
    : '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  fs.mkdirSync(OUT, { recursive: true });
  for (const f of fs.readdirSync(OUT)) fs.unlinkSync(path.join(OUT, f));

  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: 'new',
    args: ['--no-sandbox', '--disable-gpu', `--window-size=${W},${H}`,
           '--force-device-scale-factor=2'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 2 });
  await page.goto('file:///tmp/gif_build/scene.html?capture=1', { waitUntil: 'networkidle0' });

  await page.evaluate(() => document.fonts ? document.fonts.ready : Promise.resolve());

  const TOTAL = await page.evaluate(() => window.__TOTAL);
  const N = Math.ceil(TOTAL / 1000 * FPS);
  console.log('capturing', N, 'frames @', FPS, 'fps, total', TOTAL, 'ms');
  for (let i = 0; i < N; i++){
    const t = Math.round(i / FPS * 1000);
    await page.evaluate((t) => window.__renderAt(t), t);
    await new Promise(r => setTimeout(r, 16));
    const p = path.join(OUT, `f${String(i).padStart(4,'0')}.png`);
    await page.screenshot({ path: p, type: 'png', clip:{x:0,y:0,width:W,height:H}, omitBackground:false });
    if (i % 30 === 0) console.log(' frame', i, '/', N, 't=', t);
  }

  await browser.close();
  console.log('done', N, 'frames');
})().catch(e => { console.error(e); process.exit(1); });
