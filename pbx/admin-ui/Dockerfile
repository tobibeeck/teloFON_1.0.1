FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install 2>/dev/null || true
COPY . .
RUN if npm run | grep -q "build"; then npm run build; fi
CMD ["sh", "-c", "if [ -f node_modules/.bin/vite ]; then npm run dev -- --host; else echo 'Frontend not yet implemented, sleeping...'; sleep infinity; fi"]
