FROM alpine
RUN apk add --update qemu qemu-system-x86_64 qemu-img cdrkit samba-server picocom python2
RUN sed 's/^#allow br0/allow br0/g' -i /etc/qemu/bridge.conf && wget https://raw.githubusercontent.com/lovelysystems/cloud-init/master/tools/write-mime-multipart && chmod +x write-mime-multipart && mv write-mime-multipart /usr/local/bin
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
