# Use official Eclipse Temurin JDK runtime (Java 17)
FROM eclipse-temurin:17-jre-jammy

# Set working directory inside the container
WORKDIR /app

# Copy built jar from Maven target directory
COPY target/demo-0.0.1-SNAPSHOT.jar app.jar

# Expose the port Spring Boot uses
EXPOSE 8080

# Run the jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
