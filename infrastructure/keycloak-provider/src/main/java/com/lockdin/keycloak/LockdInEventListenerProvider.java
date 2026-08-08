package com.lockdin.keycloak;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.keycloak.events.Event;
import org.keycloak.events.EventListenerProvider;
import org.keycloak.events.EventType;
import org.keycloak.events.admin.AdminEvent;
import org.keycloak.events.admin.OperationType;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.util.JsonSerialization;

public final class LockdInEventListenerProvider implements EventListenerProvider {
    private static final Pattern USER_RESOURCE = Pattern.compile("^users/([^/]+)$");
    private static final Pattern USER_LOGOUT_RESOURCE = Pattern.compile("^users/([^/]+)/logout$");
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(2);
    private static final int MAX_ATTEMPTS = 2;

    private final KeycloakSession session;
    private final HttpClient client;
    private final URI webhookUri;
    private final String issuer;
    private final byte[] secret;

    LockdInEventListenerProvider(KeycloakSession session) {
        this.session = session;
        this.client = HttpClient.newBuilder().connectTimeout(REQUEST_TIMEOUT).build();
        this.webhookUri = URI.create(requiredEnvironment("LOCKDIN_EVENT_WEBHOOK_URL"));
        this.issuer = requiredEnvironment("LOCKDIN_KEYCLOAK_ISSUER");
        this.secret = requiredEnvironment("LOCKDIN_EVENT_WEBHOOK_SECRET")
                .getBytes(StandardCharsets.UTF_8);
    }

    @Override
    public void onEvent(Event event) {
        if (event.getType() == EventType.UPDATE_PASSWORD && event.getUserId() != null) {
            deliver(event.getId(), event.getTime(), event.getUserId(), "password_changed");
        }
    }

    @Override
    public void onEvent(AdminEvent event, boolean includeRepresentation) {
        String path = event.getResourcePath();
        if (path == null || event.getId() == null) {
            return;
        }
        Matcher logout = USER_LOGOUT_RESOURCE.matcher(path);
        if (logout.matches() && event.getOperationType() == OperationType.ACTION) {
            deliver(event.getId(), event.getTime(), logout.group(1), "logout_all");
            return;
        }
        Matcher userUpdate = USER_RESOURCE.matcher(path);
        if (!userUpdate.matches() || event.getOperationType() != OperationType.UPDATE) {
            return;
        }
        RealmModel realm = session.realms().getRealm(event.getRealmId());
        UserModel user = realm == null ? null : session.users().getUserById(realm, userUpdate.group(1));
        if (user != null && !user.isEnabled()) {
            deliver(event.getId(), event.getTime(), user.getId(), "account_disabled");
        }
    }

    private void deliver(String eventId, long occurredAtMillis, String subject, String action) {
        if (eventId == null || eventId.isBlank() || subject.isBlank()) {
            return;
        }
        long occurredAt = occurredAtMillis > 0
                ? Instant.ofEpochMilli(occurredAtMillis).getEpochSecond()
                : Instant.now().getEpochSecond();
        String signature = "v1=" + sign(eventId, occurredAt, subject, action);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("eventId", eventId);
        body.put("occurredAt", occurredAt);
        body.put("issuer", issuer);
        body.put("subject", subject);
        body.put("action", action);
        final String json;
        try {
            json = JsonSerialization.writeValueAsString(body);
        } catch (Exception ignored) {
            return;
        }
        HttpRequest request = HttpRequest.newBuilder(webhookUri)
                .timeout(REQUEST_TIMEOUT)
                .header("Content-Type", "application/json")
                .header("X-LockdIn-Event-Signature", signature)
                .POST(HttpRequest.BodyPublishers.ofString(json, StandardCharsets.UTF_8))
                .build();
        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            try {
                HttpResponse<Void> response = client.send(
                        request, HttpResponse.BodyHandlers.discarding());
                if (response.statusCode() == 204) {
                    return;
                }
                if (response.statusCode() < 500) {
                    return;
                }
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            } catch (Exception ignored) {
                // Bounded retry; never log payloads, identifiers, response bodies, or credentials.
            }
        }
    }

    private String sign(String eventId, long occurredAt, String subject, String action) {
        String payload = eventId + "\n" + occurredAt + "\n" + issuer + "\n" + subject + "\n" + action;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return java.util.HexFormat.of().formatHex(
                    mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to sign provider event", exception);
        }
    }

    private static String requiredEnvironment(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException(name + " is required");
        }
        return value;
    }

    @Override
    public void close() {
    }
}
