# Render deployment

Use the repository root as the Render Blueprint source. Render reads `render.yaml`
and deploys the backend from `backend/`.

Required secret to set in Render:

- `MONGODB_URI`: MongoDB Atlas connection string.

Render will generate:

- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `JWT_QR_SECRET`

Backend health URL after deploy:

- `https://sante-backend.onrender.com/health`

Flutter uses this backend by default. To override it during a build:

```bash
flutter build web --dart-define=SANTE_API_HOST=https://your-render-url.onrender.com
```
