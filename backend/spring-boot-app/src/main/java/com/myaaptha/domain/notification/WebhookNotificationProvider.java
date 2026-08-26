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
    this.client=builder.build(); this.channel=channel.trim().toUpperCase(); this.endpoint=endpoint.trim(); this.token=token.trim();
  }
  public String channel(){return channel;}
  public boolean configured(){return !channel.isBlank()&&!endpoint.isBlank();}
  public String send(NotificationEntity n,NotificationDeliveryEntity d){
    var request=client.post().uri(endpoint).header(HttpHeaders.CONTENT_TYPE,"application/json");
    if(!token.isBlank()) request=request.header(HttpHeaders.AUTHORIZATION,"Bearer "+token);
    var response=request.body(Map.of("channel",d.getChannel(),"destination",d.getDestination(),"title",n.getTitle(),"body",n.getBody(),"actionUrl",n.getActionUrl()==null?"":n.getActionUrl())).retrieve().toBodilessEntity();
    return response.getHeaders().getFirst("X-Provider-Message-Id");
  }
}
