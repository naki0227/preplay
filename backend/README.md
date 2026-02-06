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
    *   `API_SECRET`: A random string for basic auth (e.g., `openssl rand -hex 32`).

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
Authorization: Bearer <your_API_SECRET>
Content-Type: application/json
```

**Response (JSON):**
```json
{
  "game": "ゲーム名: ...\n---\n遊び方: ..."
}
```

## Local Development

1.  Create a `.env` file (copy from `.env.example`).
2.  Run:
    ```bash
    npm run dev
    ```
