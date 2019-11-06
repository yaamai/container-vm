FROM alpine
RUN apk add --update qemu qemu-system-x86_64 qemu-img cdrkit minicom samba-server
RUN apk add --update curl python &&\
    curl -Lo /bin/write-mime-multipart https://raw.githubusercontent.com/lovelysystems/cloud-init/master/tools/write-mime-multipart &&\
    chmod +x /bin/write-mime-multipart && \
    sed -E 's:python2.6:python:g' -i /bin/write-mime-multipart
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
