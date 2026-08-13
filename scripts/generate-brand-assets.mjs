import path from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = (name) => path.join(root, 'assets', 'brand', name);
const output = (name) => path.join(root, 'assets', 'images', name);

await sharp(source('app-icon.svg')).resize(1024, 1024).png().toFile(output('icon.png'));
await sharp(source('app-icon.svg')).resize(48, 48).png().toFile(output('favicon.png'));
await sharp(source('glyph.svg')).resize(228, 228).png().toFile(output('splash-icon.png'));

await sharp({
  create: { width: 512, height: 512, channels: 4, background: '#FFFFFF' },
})
  .png()
  .toFile(output('android-icon-background.png'));

const glyph = await sharp(source('glyph.svg')).resize(300, 300).png().toBuffer();
for (const name of ['android-icon-foreground.png', 'android-icon-monochrome.png']) {
  await sharp({
    create: { width: 512, height: 512, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .composite([{ input: glyph, gravity: 'center' }])
    .png()
    .toFile(output(name));
}

console.log('Plan Your Day P-mark assets generated.');
