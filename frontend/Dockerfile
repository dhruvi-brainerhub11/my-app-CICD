# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code and public files
COPY src ./src
COPY public ./public

# Build React app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app from builder
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port (nginx now listens on 3000)
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
