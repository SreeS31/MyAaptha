FROM node:22-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=dependencies /app/node_modules node_modules
COPY . .
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
RUN npm run build

FROM node:22-alpine
RUN addgroup -S myaaptha && adduser -S myaaptha -G myaaptha
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0
COPY --from=build --chown=myaaptha:myaaptha /app/.next/standalone ./
COPY --from=build --chown=myaaptha:myaaptha /app/.next/static ./.next/static
COPY --from=build --chown=myaaptha:myaaptha /app/public ./public
USER myaaptha
EXPOSE 3000
CMD ["node","server.js"]
