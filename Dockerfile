# Build two versioned demo artifacts; no runtime code comes from a ConfigMap.
FROM nginxinc/nginx-unprivileged:1.30-alpine
ARG APP_VARIANT
COPY app/shared/ /usr/share/nginx/html/
COPY app/${APP_VARIANT}/ /usr/share/nginx/html/
EXPOSE 8080
