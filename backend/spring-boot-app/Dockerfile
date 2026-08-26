FROM maven:3.9.11-eclipse-temurin-21-alpine AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn --batch-mode dependency:go-offline
COPY src src
RUN mvn --batch-mode -DskipTests package

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S myaaptha && adduser -S myaaptha -G myaaptha
WORKDIR /app
COPY --from=build /workspace/target/*.jar app.jar
RUN mkdir -p /var/lib/myaaptha/uploads && chown -R myaaptha:myaaptha /app /var/lib/myaaptha
USER myaaptha
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD wget -q -O - http://127.0.0.1:8080/actuator/health || exit 1
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-Djava.security.egd=file:/dev/urandom","-jar","app.jar","--spring.profiles.active=prod"]
