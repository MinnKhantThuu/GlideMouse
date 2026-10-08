# Search discovery

Canonical app website: https://minnkhantthuu.github.io/GlideMouse/

The landing page identifies GlideMouse as a Mac mouse utility in its HTML title, description and visible product label. Open Graph and Twitter metadata use a real app screenshot. The default English JavaScript title matches the source HTML title; language switching retains the product and Mac context.

The landing page's JSON-LD describes the software, supported macOS version, languages, current download, MIT license and developer. It contains no invented ratings or reviews. SoftwareApplication markup by itself does not qualify for Google's software-app rich result: Google also requires a genuine rating or review. Do not manufacture one to silence a validator warning.

`sitemap.xml` contains the canonical landing, tutorial and privacy URLs. Do not list language query variants, fragment links, app binaries or app-bundled demonstration HTML as separate pages. The English/Myanmar tutorial keeps one canonical URL; the language buttons do not constitute separately indexed translations.

Crawler rules must be served at the **host root**, `https://minnkhantthuu.github.io/robots.txt`. A robots file inside `/GlideMouse/` would not control this site. Root robots and the portfolio sitemap are maintained in the public `MinnKhantThuu/minnkhantthuu.github.io` checkout. The portfolio static exporter preserves these root files. Root robots references both its own sitemap and `/GlideMouse/sitemap.xml`.

## Release updates

- Update softwareVersion, downloadUrl and screenshot metadata when the public installer or featured screenshot changes.
- Keep each canonical URL absolute and consistent with its sitemap entry.
- Update asset query hashes when landing CSS or JavaScript changes.
- Preserve any published Search Console verification tag or file; removing it can revoke verification.
- Check live pages return HTTP 200, render the content without a login, load screenshots and have no `noindex` header/meta directive.

## Search Console

Use a URL-prefix property for `https://minnkhantthuu.github.io/GlideMouse/`; GitHub Pages DNS is not under the developer's control. Verify using Google's HTML tag/file, submit `sitemap.xml`, and inspect the landing and tutorial URLs. Ownership, sitemap receipt, URL crawlability, index inclusion and search ranking are separate states. Save the actual dashboard result for each; a successful deployment does not prove indexing or ranking.

Search engines decide whether and where a page appears. An indexing request does not guarantee inclusion or first place. Crawling can take days or weeks. No paid service or advertising is required for this setup.

References: [Google Search Essentials](https://developers.google.com/search/docs/essentials), [Sitemaps](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap), [Request recrawling](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl), [Software application markup](https://developers.google.com/search/docs/appearance/structured-data/software-app).
