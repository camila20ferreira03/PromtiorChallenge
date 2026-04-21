# Promtior Chat Frontend

Premium dark-mode chat UI for the Promtior assistant, built with **Vite + React 18 + TypeScript + Tailwind CSS v3**. One active conversation at a time, persistent `session_id`, markdown responses, and a polished "thinking" state — ready to wire up to the [`chat-api`](../chat-api) backend.

## Quick start

```bash
cd frontend
npm install
npm run dev
```

The dev server runs on [http://localhost:5173](http://localhost:5173).

### Connect to the real chat-api

By default the UI talks to the real FastAPI + LangServe backend at
`http://localhost:8000` via `POST /chat/invoke` (see
`src/lib/chatApi.ts`). Override the base URL by copying `.env.example`
to `.env.local`:

```bash
cp .env.example .env.local
# edit VITE_CHAT_API_URL if you run the API somewhere else
```

Run the backend in a second terminal:

```bash
cd chat-api
# (activate venv / load AWS + OPENAI_API_KEY as documented in chat-api/README.md)
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

CORS is pre-enabled for `http://localhost:5173` and `http://127.0.0.1:5173`
in `chat-api/app/main.py`. Add more origins via the `CORS_ALLOW_ORIGINS`
env var on the backend (comma-separated).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start the Vite dev server with HMR |
| `npm run build` | Type-check and produce a production build in `dist/` |
| `npm run preview` | Preview the production build locally |

## Project structure

```
frontend/
├── public/
│   └── promtior-logo.png        # Official Promtior mark (favicon + in-app icon)
├── src/
│   ├── components/
│   │   ├── chat/
│   │   │   ├── AssistantMessage.tsx
│   │   │   ├── ChatInput.tsx
│   │   │   ├── ChatWindow.tsx
│   │   │   ├── EmptyState.tsx
│   │   │   ├── MessageBubble.tsx
│   │   │   ├── ThinkingIndicator.tsx
│   │   │   └── UserMessage.tsx
│   │   └── layout/
│   │       ├── ChatHeader.tsx
│   │       ├── Logo.tsx
│   │       └── Sidebar.tsx
│   ├── hooks/
│   │   └── useChatSession.ts
│   ├── lib/
│   │   ├── chatApi.ts
│   │   └── persistedSessionId.ts
│   ├── App.tsx
│   ├── index.css
│   ├── main.tsx
│   └── types.ts
├── index.html
├── tailwind.config.js
├── postcss.config.js
└── vite.config.ts
```

## Single chat + persistent session

There is only **one active chat** at a time — no multi-thread history in the sidebar.

- A stable `session_id` is stored in `localStorage` under the key `promtior_chat_session_id` (see `src/lib/persistedSessionId.ts`).
- On first visit a fresh `crypto.randomUUID()` is generated and persisted.
- The **New chat** button in the sidebar clears the current messages, rotates to a **new** `session_id`, and persists it — so the backend (`chat-api` / DynamoDB) will see a brand-new conversation on the next request.
- Opening or refreshing the app always reuses the stored id, so pending conversations survive page reloads.

## Design tokens

CSS custom properties are declared in `src/index.css` and mirrored in `tailwind.config.js` (`bg.base`, `bg.elevated`, `accent.cyan`, `accent.violet`, etc.). The background uses a subtle radial gradient behind the main column; animations respect `prefers-reduced-motion`.

## API client

All requests go through `src/lib/chatApi.ts`. Request / response shape
matches `ChatInput` in [`chat-api/app/chain.py`](../chat-api/app/chain.py):

```json
POST /chat/invoke
{ "input": { "session_id": "<uuid>", "message": "Hi" } }

200 OK
{ "output": "Hello! ...", "metadata": { ... } }
```

## Notes

- The Promtior mark lives in `public/promtior-logo.png` and is rendered by the `Logo` component in `src/components/layout/Logo.tsx`.
- Markdown rendering uses `react-markdown` + `remark-gfm` without raw HTML for safety.
