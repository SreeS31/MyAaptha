FROM maven:3.9.11-eclipse-temurin-21-alpine AS build
WORKDIR /workspace
COPY pom.xml .
COPY src src
RUN --mount=type=cache,target=/root/.m2/repository --mount=type=secret,id=maven_settings,target=/root/.m2/settings.xml mvn --batch-mode -DskipTests package

FROM eclipse-temurin:21-jre-alpine
RUN apk upgrade --no-cache && addgroup -S -g 10001 myaaptha && adduser -S -u 10001 myaaptha -G myaaptha
WORKDIR /app
COPY --from=build /workspace/target/*.jar app.jar
RUN mkdir -p /var/lib/myaaptha/uploads && chown -R myaaptha:myaaptha /app /var/lib/myaaptha
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD wget -q -O - http://127.0.0.1:8080/actuator/health || exit 1
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-Djava.security.egd=file:/dev/urandom","-jar","app.jar","--spring.profiles.active=prod"]
