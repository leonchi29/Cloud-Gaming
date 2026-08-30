# ---------- Build ----------
FROM node:20-alpine AS build
WORKDIR /app
ARG VITE_BACKEND_URL=http://localhost:4000
ENV VITE_BACKEND_URL=$VITE_BACKEND_URL
COPY package*.json ./
RUN npm ci
COPY tsconfig.json vite.config.ts index.html ./
COPY src ./src
RUN npm run build

# ---------- Runtime ----------
FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
