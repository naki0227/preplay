# Preplay Backend (Vercel + Hono)

This is the secure backend proxy for the Preplay Flutter app.
It handles Gemini API calls, keeping the API Key server-side.

## Setup

1.  **Install Vercel CLI (if not installed)**
    ```bash
    npm install -g vercel
    ```

2.  **Login to Vercel**
    ```bash
    vercel login
    ```

3.  **Set Environment Variables on Vercel**
    Go to your Vercel project dashboard -> Settings -> Environment Variables.
    Add:
    *   `GEMINI_API_KEY`: Your Google AI Studio API Key.
    *   `GEMINI_MODEL` (optional): Gemini model ID. Default is `gemini-3.1-flash-lite`.
    *   `SUPABASE_URL` / `SUPABASE_ANON_KEY` (optional): the same public values as `config/app_config.json`. The backend then counts generation outcomes per day in Supabase (`public.bump_stat`); nothing about the person is stored. Without them, counting is skipped.
    Rate limiting is in-memory per instance (10 requests / 60 s per IP); set a monthly spend cap on the Gemini project in AI Studio as the hard cost limit.

4.  **Deploy**
    ```bash
    cd backend
    vercel --prod
    ```

## API Endpoint

`POST /api/generate`

**Request Body (JSON):**
```json
{
  "tags": ["noisy", "walking"],
  "groupSize": 3
}
```

**Headers:**
```
Content-Type: application/json
```

**Response (JSON):**
```json
{
  "game": "ゲーム名: ...\n---\n遊び方: ..."
}
```

`GET /api/health` returns `{ status, hasApiKey, model }` (no part of the key).

## Local Development

1.  Create a `.env` file (copy from `.env.example`).
2.  Run:
    ```bash
    npm run dev
    ```

## Checks

```bash
npm run typecheck
npm test
```
