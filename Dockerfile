FROM alpine
RUN apk add --update qemu qemu-system-x86_64 qemu-img cdrkit minicom samba-server
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
