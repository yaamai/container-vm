FROM alpine
RUN apk add --update qemu qemu-system-x86_64 qemu-img cdrkit samba-server picocom
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
