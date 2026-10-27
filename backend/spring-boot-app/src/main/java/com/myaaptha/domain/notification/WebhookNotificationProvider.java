package com.myaaptha.domain.notification;

import com.myaaptha.domain.notification.model.NotificationDeliveryEntity;
import com.myaaptha.domain.notification.model.NotificationEntity;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class WebhookNotificationProvider implements NotificationChannelProvider {
  private final RestClient client;
  private final String channel;
  private final String endpoint;
  private final String token;

  public WebhookNotificationProvider(RestClient.Builder builder,
      @Value("${myaaptha.notifications.webhook.channel:}") String channel,
      @Value("${myaaptha.notifications.webhook.url:}") String endpoint,
      @Value("${myaaptha.notifications.webhook.token:}") String token) {
    var factory=new org.springframework.http.client.JdkClientHttpRequestFactory(java.net.http.HttpClient.newBuilder().connectTimeout(java.time.Duration.ofSeconds(3)).build());
    factory.setReadTimeout(java.time.Duration.ofSeconds(10));
    this.client=builder.requestFactory(factory).build(); this.channel=channel.trim().toUpperCase(); this.endpoint=endpoint.trim(); this.token=token.trim();
  }
  public String channel(){return channel;}
  public boolean configured(){return !channel.isBlank()&&!endpoint.isBlank();}
  public String send(NotificationEntity n,NotificationDeliveryEntity d){
    return send(n,d,"myaaptha-delivery-"+d.getId());
  }
  public String send(NotificationEntity n,NotificationDeliveryEntity d,String idempotencyKey){
    var request=client.post().uri(endpoint).header(HttpHeaders.CONTENT_TYPE,"application/json").header("Idempotency-Key",idempotencyKey);
    if(!token.isBlank()) request=request.header(HttpHeaders.AUTHORIZATION,"Bearer "+token);
    var response=request.body(Map.of("channel",d.getChannel(),"destination",d.getDestination(),"title",n.getTitle(),"body",n.getBody(),"actionUrl",n.getActionUrl()==null?"":n.getActionUrl())).retrieve().toBodilessEntity();
    // Redirects are not provider acceptance. Keep the outbox retryable rather than
    // incorrectly marking a delivery SENT when no delivery endpoint accepted it.
    if(!response.getStatusCode().is2xxSuccessful())throw new IllegalStateException("Notification provider did not accept delivery");
    return response.getHeaders().getFirst("X-Provider-Message-Id");
  }
}
