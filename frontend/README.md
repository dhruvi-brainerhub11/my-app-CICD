# Frontend README

React frontend application for the User App

## Setup

```bash
npm install
```

## Environment Variables

Create `.env` file with:
```env
REACT_APP_API_URL=http://localhost:5000
REACT_APP_API_TIMEOUT=30000
```

## Development

```bash
npm start
```

Application will open at http://localhost:3000

## Build

```bash
npm run build
```

Creates production build in `build/` directory

## Docker

Build:
```bash
docker build -t user-app-frontend .
```

Run:
```bash
docker run -p 80:80 user-app-frontend
```

Access at http://localhost

## Features

- User input form (name, email, phone, message)
- User list display
- Delete user functionality
- Real-time updates
- Responsive design
- Error handling
- Loading states

## Project Structure

```
src/
├── App.js              # Main component
├── App.css            # Main styles
├── index.js           # React entry point
├── index.css          # Global styles
└── components/
    ├── UserForm.js    # Form component
    ├── UserForm.css
    ├── UserList.js    # List component
    └── UserList.css
public/
└── index.html         # HTML template
```
