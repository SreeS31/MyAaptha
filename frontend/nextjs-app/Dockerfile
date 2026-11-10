FROM node:22-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit

FROM node:22-alpine AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=dependencies /app/node_modules node_modules
COPY . .
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ARG MYAAPTHA_API_ORIGIN=http://backend:8080
ENV MYAAPTHA_API_ORIGIN=$MYAAPTHA_API_ORIGIN
RUN npm run build

FROM node:22-alpine
RUN apk upgrade --no-cache && addgroup -S -g 10001 myaaptha && adduser -S -u 10001 myaaptha -G myaaptha
# The standalone server needs Node only. Keep build-time package managers and
# their dependency trees out of the deployed image.
RUN rm -rf /usr/local/lib/node_modules/npm /opt/yarn-* \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/yarn /usr/local/bin/yarnpkg
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0 NEXT_TELEMETRY_DISABLED=1
COPY --from=build --chown=myaaptha:myaaptha /app/.next/standalone ./
COPY --from=build --chown=myaaptha:myaaptha /app/.next/static ./.next/static
COPY --from=build --chown=myaaptha:myaaptha /app/public ./public
USER 10001:10001
EXPOSE 3000
CMD ["node","server.js"]
