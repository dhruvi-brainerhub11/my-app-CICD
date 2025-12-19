# Build stage
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY src ./src

# Expose port
EXPOSE 5000

# Health check
#HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  #CMD wget -qO- http://localhost:5000/health || exit 1

# Start application
CMD ["npm", "start"]
