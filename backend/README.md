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


services:
  # MySQL Database Service (simulating AWS RDS)
  #mysql:
    #image: mysql:8.0
    #container_name: user-app-mysql
    #environment:
      #MYSQL_ROOT_PASSWORD: root_password
      #MYSQL_DATABASE: myappdb
      #MYSQL_USER: admin
      #MYSQL_PASSWORD: Admin123
   # ports:
   #   - "3306:3306"
   # volumes:
     # - mysql-data:/var/lib/mysql
   # networks:
     # - user-app-network
   # healthcheck:
     # test: ["CMD-SHELL", "curl -f http://127.0.0.1:5000/health || exit 1"]
     # interval: 30s
     # timeout: 5s
      #retries: 5

  # Node.js Backend Service
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: user-app-backend
    ports:
      - "5000:5000"
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_USER: admin
      DB_PASSWORD: Admin123
      DB_NAME: myappdb
      PORT: 5000
      NODE_ENV: development
      CORS_ORIGIN: http://localhost:3000
    #depends_on:
      #mysql:
        #condition: service_healthy
    volumes:
      - ./backend/src:/app/src
    networks:
      - user-app-network
    restart: unless-stopped

  # React Frontend Service
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: user-app-frontend
    ports:
      - "3000:3000"
    environment:
      REACT_APP_API_URL: http://localhost:5000
    depends_on:
      - backend
    networks:
      - user-app-network
    restart: unless-stopped

volumes:
  mysql-data:
    driver: local

networks:
  user-app-network:
    driver: bridge
