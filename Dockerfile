FROM kubevirt/libvirt:5.0.0
RUN dnf install -y virt-install
COPY libvirtd.sh prepare.sh /
ENTRYPOINT ["/libvirtd.sh"]
