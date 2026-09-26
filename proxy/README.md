# Assistant Proxy

Cloudflare Worker yang memegang Gemini API key dan meneruskan permintaan dari
aplikasi kasir. Tujuannya: user install aplikasi → buka "Asisten Kasir" → langsung
jalan, tanpa harus daftar API key sendiri.

## Kenapa perlu proxy

Kalau API key ditanam di aplikasi, key-nya bisa diekstrak dari APK/IPA dan dipakai
orang lain untuk menghabiskan kuota kamu. Worker menyimpan key sebagai *secret*
(terenkripsi), jadi tidak pernah ada di dalam biner aplikasi.

## Deploy

```bash
cd proxy
npm install
npx wrangler login

# Gemini API key (dari https://aistudio.google.com/apikey)
npx wrangler secret put GEMINI_API_KEY

# Token opsional. Kalau diisi, app wajib mengirim header X-Assistant-Token.
# Wrap dengan string acak, misalnya: openssl rand -hex 24
npx wrangler secret put APP_TOKEN

npm run deploy
```

`npm run deploy` akan mencetak URL Worker, contoh:

```
https://aksy-assistant-proxy.<subdomain>.workers.dev
```

## Pakai dari aplikasi

```bash
flutter run --dart-define=ASSISTANT_PROXY_URL=https://aksy-assistant-proxy.<subdomain>.workers.dev
```

Kalau `APP_TOKEN` dipakai, tambahkan:

```bash
--dart-define=ASSISTANT_APP_TOKEN=<token-yang-sama>
```

Tanpa `--dart-define`, pemain bisa mengetiknya lewat ikon **Pengaturan** di halaman
Asisten Kasir (berguna untuk testing atau white-label ke banyak toko).

## Test

Tidak perlu API key sungguhan — `fetch` ke Gemini di-stub, jadi test jalan offline
dan tidak menghabiskan kuota.

```bash
npm test
```

Yang di-cover: health check, preflight CORS, penolakan method, kondisi secret belum
terpasang, penolakan app token, validasi payload (model, role, ukuran, JSON rusak),
SSE passthrough, pemeriksaan bahwa key tidak pernah bocor ke response, translasi error
upstream, dan rate limit per IP.

Lalu smoke test ke Worker yang sudah dideploy:

```bash
# pastikan secret terpasang
curl https://aksy-assistant-proxy.<subdomain>.workers.dev/health

# tanya sesuatu
curl -N -X POST https://aksy-assistant-proxy.<subdomain>.workers.dev/chat \
  -H 'Content-Type: application/json' \
  -H 'X-Assistant-Token: <token>' \
  -d '{
        "model": "gemini-3.5-flash",
        "systemInstruction": "Kamu asisten kasir Bahasa Indonesia.",
        "messages": [{ "role": "user", "text": "Sapa singkat" }]
      }'
```

## Batas yang diterapkan Worker

| Batas | Nilai | Alasan |
| --- | --- | --- |
| Request per IP | 20 / menit | Mencegah satu device menghabiskan seluruh kuota |
| Jumlah pesan per request | 20 | Menjaga ukuran request |
| Panjang system instruction | 24.000 karakter | Snapshot data toko muat di sini |
| Panjang satu pesan | 8.000 karakter | Mencegah request raksasa |
| Ukuran body | 512 KB | Batas keras sebelum parsing |
| Model | `gemini-*` | Mencegah model mahal disembunyikan di balik proxy |

Rate limit dihitung in-memory per isolate Cloudflare, jadi sifatnya *best-effort* —
bukan jaminan keras. Untuk aplikasi yang benar-benar publik, aktifkan **Cloudflare Rate
Limiting** (Rules → Rate Limiting) di dashboard, karena itu ditegakkan di edge.

## Kalau kuota sering habis

Free tier Gemini dibatasi per-project dan dibagikan ke semua user aplikasi. Kalau
`_30/menit` di Worker tidak cukup, naikkan `RATE_LIMIT_MAX_REQUESTS` **atau** aktifkan
billing di Google AI Studio. Pantau lewat `npm run tail`.
