// Renders the onboarding intro carousel to JPEGs, for looking at the opening
// screens without a Mac in the room.
//
//   npm i playwright && node docs/onboarding-preview/render.js
//
// Writes page-1…4.jpg (the four carousel pages) and scan.jpg (the capture
// screen on its own, full size) next to this file.
//
// Read the README before trusting the output: this is a PORT of the SwiftUI,
// not the SwiftUI.

const { chromium } = require("playwright");
const path = require("path");

const HERE = __dirname;
// Where Playwright's bundled Chromium lives on the CI image; falls back to
// whatever the local install resolves to.
const EXECUTABLE = process.env.CHROMIUM_PATH || undefined;

(async () => {
  const browser = await chromium.launch({ executablePath: EXECUTABLE });

  // 2x is the sweet spot: sharp on a Retina display, and the files stay small
  // enough to live in the repo without bloating a clone.
  const page = await browser.newPage({
    deviceScaleFactor: 2,
    viewport: { width: 1800, height: 1000 },
  });

  await page.goto("file://" + path.join(HERE, "preview.html"));
  await page.waitForFunction(() => window.__ready === true);
  await page.waitForTimeout(400);

  const pages = await page.$$(".page");
  for (let i = 0; i < pages.length; i++) {
    await pages[i].screenshot({
      path: path.join(HERE, `page-${i + 1}.jpg`),
      type: "jpeg",
      quality: 92,
    });
  }

  // The scan screen again, on its own, so the mesh can be checked against the
  // face at full size — that is how the face box was measured in the first
  // place, and how it should be re-measured if the portrait is ever swapped.
  await page.evaluate(() => {
    document.body.innerHTML = '<div id="solo"></div>';
    document.body.style.background = "#000";
    document.getElementById("solo").innerHTML = window.__scanSolo();
    window.__drawSolo();
  });
  await page.waitForTimeout(300);
  await (await page.$(".scanScr")).screenshot({
    path: path.join(HERE, "scan.jpg"),
    type: "jpeg",
    quality: 92,
  });

  await browser.close();
  console.log(`Wrote ${pages.length} pages + scan.jpg to ${HERE}`);
})();
