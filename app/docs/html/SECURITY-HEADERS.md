# Web security & SEO notes (docs/html)

The marketing site is static, self-contained HTML (no external scripts/fonts, no
trackers). Each page already ships:

- **Content-Security-Policy** (meta): `default-src 'self'`, images `'self' data:`,
  inline style/script allowed (needed for the theme/lang toggle), `frame-ancestors 'none'`,
  `upgrade-insecure-requests`.
- `referrer` = `strict-origin-when-cross-origin`, `robots` = `index,follow`,
  canonical URLs, Open Graph + Twitter cards, JSON-LD (`MobileApplication`).
- `robots.txt` + `sitemap.xml`, favicon + apple-touch-icon.

## Set these as real HTTP response headers on the server

`frame-ancestors`/HSTS etc. only fully apply as **headers**, not `<meta>`. Add:

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests
```

### nginx
```
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```

### Apache (.htaccess)
```
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"
```

## Deployment notes
- Serve over **HTTPS only** (redirect 80 → 443).
- Replace the base domain in canonical/OG/`sitemap.xml`/`robots.txt` if the site
  is not hosted at `https://www.gcng.de/sprechly/`.
- The App Store Connect **Privacy Policy URL** must point at the hosted
  `privacy.html` (e.g. `https://www.gcng.de/sprechly/privacy.html`).
