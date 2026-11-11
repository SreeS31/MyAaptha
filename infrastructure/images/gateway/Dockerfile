FROM alpine:3.23@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2
RUN apk upgrade --no-cache \
    && apk add --no-cache nginx nginx-mod-http-headers-more \
    && mkdir -p /run/nginx /etc/nginx/conf.d
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80 443
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
