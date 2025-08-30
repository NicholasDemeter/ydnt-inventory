# YDNT — Handover Packet (Current State & Next Steps)
_Last updated: 2025-08-25 19:42 UTC_

## Sources of Truth
- **App (site) repo:** `NicholasDemeter/youdontneedthis-site` (branch: `main`)
  - Live (GitHub Pages): https://nicholasdemeter.github.io/youdontneedthis-site/
- **Assets (LOTS) repo:** `NicholasDemeter/youdontneedthis-inventory` (public)
  - Folder shape per lot: `LOT_XXX_<Name>/Photos/thumb.jpg`
  - Many lot folder names use **underscores**, while the Google Sheet has **spaces**
- **Supabase project:** `https://dycjwrgieaontfzkfqvw.supabase.co`
  - **Edge Function:** `/functions/v1/fetch-products`
  - **Anon key:** available in Supabase **Settings → API** (validated via curl by user)
- **Google Sheet ID** (sole data store): `1Pp6bvp4DoDJqVKIrNuN9N6zS_MhVex9UDRSC-nIGI6k`  
  **No Supabase database** — Sheet → Supabase Edge Function → React.

---

## What’s Working
- **Edge Function** responds with product JSON (curl test: HTTP 200).
- **Build & deploy** to GitHub Pages works; Vite `base` set to `/youdontneedthis-site/`.
- **Client fetch** uses explicit `fetch` to Supabase with headers:
  - `Authorization: Bearer <anon>` and `apikey: <anon>`
- **App loads** on Pages; when Vite envs are injected at build time, browser hits Supabase (not github.io).

## Outstanding Issues / To Finish
1. **Thumbnails**: Many 404s because the Sheet `folderName` contains **spaces** while repo folders use **underscores**.  
   → Add **image-path normalization** in the Edge Function and a **single client-side fallback**.
2. **CORS**: Only needed if browser **OPTIONS** preflight returns 405 on the Supabase endpoint. (Earlier 405 was from github.io due to missing envs.)
3. **Details routing**: If “View Details” loops, confirm after image fix.

---

## Required GitHub Actions Secrets (for `youdontneedthis-site` build)
Add in **Settings → Secrets and variables → Actions → New repository secret**:
- `VITE_SUPABASE_URL` = `https://dycjwrgieaontfzkfqvw.supabase.co`
- `VITE_SUPABASE_ANON_KEY` = (anon key from Supabase Settings → API)

---

## Critical Files & Current State
- `src/components/ProductGrid.tsx`
  - Uses **explicit** `fetch` with `Authorization` and `apikey` headers.
  - Includes probes: `[SUPABASE_ENV]`, `[SUPABASE_PROBE]` (handy for verification).
- `src/components/ProductCard.tsx`
  - Shows real images; **no placeholder stock photos**. Will receive one-time fallback in this patch.
- `supabase/functions/fetch-products/index.ts`
  - No DB; reads Google Sheets with **header-based** mapping; builds products.
  - Currently assembles `image` from assets repo path; must add normalized **alt** path.
- `vite.config.ts`
  - `base: '/youdontneedthis-site/'` plus `@` alias to `src`.
- `.github/workflows/deploy-pages.yml`
  - Builds with `--base=/youdontneedthis-site/`, injects envs from secrets, deploys to Pages.

---

## One Patch to Apply (Images): Server + Client

### A) Edge Function — add normalized alternate path
**File:** `supabase/functions/fetch-products/index.ts`  
Insert inside the product-construction logic, after you read `folderName` and before returning the product:
```ts
const repo = 'youdontneedthis-inventory';
const folderRaw = (folderName || '').trim();

// Primary: encode exactly as given (covers rare true-spaces folders)
const folderEnc = encodeURIComponent(folderRaw);

// Alt: normalize spaces/dashes to underscores to match repo folder names
const folderUnderscore = folderRaw
  .replace(/\s+/g, '_')
  .replace(/-+/g, '_');

const primaryImg = `https://raw.githubusercontent.com/NicholasDemeter/${repo}/main/${folderEnc}/Photos/thumb.jpg`;
const altImg     = `https://raw.githubusercontent.com/NicholasDemeter/${repo}/main/${encodeURIComponent(folderUnderscore)}/Photos/thumb.jpg`;

// Include both
image: primaryImg,
image_alt: altImg,
folderName: folderRaw,

// Debug (keep during verification)
console.log('IMAGE_DEBUG', { id, folderRaw, primaryImg, altImg });
```

### B) Frontend — one-time fallback from `image` → `image_alt`
**File:** `src/components/ProductCard.tsx`
```tsx
import { useEffect, useState } from 'react'; // ensure available

const [imgSrc, setImgSrc] = useState(product.image || '');
useEffect(() => { setImgSrc(product.image || ''); }, [product.image]);

const handleImageError = () => {
  if (product.image_alt && imgSrc !== product.image_alt) {
    setImgSrc(product.image_alt); // try underscore-normalized path once
  } else {
    console.warn('Image failed:', product.id, imgSrc);
    // leave broken icon (no placeholder)
  }
};

// In JSX:
<img
  src={imgSrc}
  alt={product.name}
  loading="lazy"
  onError={handleImageError}
  className="w-full h-56 object-cover rounded-xl"
/>
```

---

## (Only if needed) CORS for OPTIONS preflight on the Edge Function
Add at top-level and use in all responses:
```ts
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

if (req.method === 'OPTIONS') {
  return new Response('ok', { headers: corsHeaders });
}

// For every Response(...), add headers: { ...corsHeaders, 'Content-Type': 'application/json' }
```

---

## Verification Checklist
1. **Deploy** (`Deploy to GitHub Pages` workflow green).
2. Open: `https://nicholasdemeter.github.io/youdontneedthis-site/?cb=1`
3. **Console**: `[SUPABASE_ENV] { url: 'https://dycjwrgieaontfzkfqvw.supabase.co', anonDefined: true }`
4. **Network**:
   - `OPTIONS` (if present) → 200/204
   - `POST .../functions/v1/fetch-products` → **200**, Response begins with `{"products":[ ... ]}`
5. **Images**:
   - For lots whose `folderName` contains spaces, first `<img>` may 404 once, then **switch to underscore URL** and load.
   - Manually verify a raw image URL (replace with an actual lot folder name):
     - `https://raw.githubusercontent.com/NicholasDemeter/youdontneedthis-inventory/main/LOT_XXX_Name_With_Underscores/Photos/thumb.jpg`

---

## Known Breaking Points (don’t change without updating code)
- **Assets repo name** must remain `youdontneedthis-inventory` unless you update the Edge Function.
- **Vite envs at build**: if `VITE_SUPABASE_URL` or `VITE_SUPABASE_ANON_KEY` are missing, client hits `github.io/functions/...` (405).
- **Vite base** must be `/youdontneedthis-site/` for Pages subpath; otherwise app JS/CSS 404 and page appears blank.
- **CORS** needed only if OPTIONS preflight fails against Supabase.

---

## Quick Diagnostics

**Curl (server sanity):**
```bash
curl -sS -X POST   -H 'Content-Type: application/json'   -H 'Authorization: Bearer <ANON>'   -H 'apikey: <ANON>'   https://dycjwrgieaontfzkfqvw.supabase.co/functions/v1/fetch-products   -d '{}' | head -c 400; echo
```

**Expected console probes (client):**
- `[SUPABASE_ENV] { url: ..., anonDefined: true }`
- `[SUPABASE_PROBE] { status: 200, preview: ... }`

---

## Definition of Done
- Site loads products from Google Sheet via Edge Function (**done**).
- Thumbnails load from `youdontneedthis-inventory` after normalization (**this patch**).
- No placeholder stock images on failures.
- (If needed) detail-page routing shows individual lots instead of looping.