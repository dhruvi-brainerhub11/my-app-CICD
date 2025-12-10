# Backend README

Node.js Express API server for the User App

## Setup

```bash
npm install
```

## Environment Variables

Create `.env` file with:
```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=admin
DB_PASSWORD=password
DB_NAME=user_app_db
PORT=5000
NODE_ENV=development
CORS_ORIGIN=http://localhost:3000
```

## Development

```bash
npm run dev
```

Server will run on http://localhost:5000

## Production

```bash
npm start
```

## API Endpoints

- `GET /api/health` - Health check
- `GET /api/users` - List all users
- `GET /api/users/:id` - Get user by ID
- `POST /api/users` - Create new user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

## Docker

Build:
```bash
docker build -t user-app-backend .
```

Run:
```bash
docker run -p 5000:5000 \
  -e DB_HOST=mysql \
  -e DB_USER=admin \
  -e DB_PASSWORD=password \
  -e DB_NAME=user_app_db \
  user-app-backend
```
