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
# Plantilla procesada por envsubst en el arranque: nginx escuchará en $PORT
# (Railway inyecta PORT; el proxy público apunta a ese puerto)
ENV PORT=80
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
