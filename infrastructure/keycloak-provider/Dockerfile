FROM maven:3.9.11-eclipse-temurin-21-alpine@sha256:922927df2c662cdd47ddb116443d6bec4696cfae3de1a0ddac8fcc7b87ce61ae AS provider-builder

WORKDIR /build
COPY pom.xml ./
COPY src ./src
RUN mvn --batch-mode --no-transfer-progress package -DskipTests

FROM quay.io/keycloak/keycloak:26.7.0@sha256:0f198be292568439d700cdbfb893e69a6009bb43a94a06a945b1d3d506c76b13

COPY --from=provider-builder /build/target/lockdin-keycloak-events-0.1.0.jar /opt/keycloak/providers/lockdin-keycloak-events.jar
RUN /opt/keycloak/bin/kc.sh build
