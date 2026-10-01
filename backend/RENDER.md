# Render deployment

Use the repository root as the Render Blueprint source. Render reads `render.yaml`
and deploys the backend from `backend/`.

Required secret to set in Render:

- `MONGODB_URI`: MongoDB Atlas connection string.
- `CORS_ORIGIN`: the exact browser origin(s) allowed to call the API, comma-separated. Leave native Flutter clients without an origin; do not use `*`.

Render will generate:

- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `JWT_QR_SECRET`

Backend health URL currently:

- `https://sante-vq36.onrender.com/health`

Flutter receives the API host only at build time. Do not put this value in Dart source:

```bash
flutter build web --dart-define=SANTE_API_HOST=https://your-render-url.onrender.com
flutter build apk --dart-define=SANTE_API_HOST=https://your-render-url.onrender.com
```
